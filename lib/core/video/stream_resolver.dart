import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../services/app_http.dart';
import 'browser_pool.dart';
import 'cancellation.dart';
import 'headless_browser.dart';
import 'maccms.dart';
import 'resolved_stream_cache.dart';
import 'resolve_result.dart';

export 'resolve_result.dart';

enum _ProbeOutcome { reachable, unreachable, invalidMedia }

/// Resolves pages through independent HTTP and browser branches. One deadline
/// covers queueing, browser creation, discovery, verification and retries.
class StreamResolver {
  StreamResolver({
    MacCmsResolver? maccms,
    Dio? dio,
    HeadlessBrowser Function()? browserFactory,
    HeadlessBrowserPool? browserPool,
    ResolvedStreamCache? cache,
    Duration grace = const Duration(seconds: 6),
    Duration overallTimeout = const Duration(seconds: 12),
    Duration overallBudget = const Duration(seconds: 10),
    Duration collectWindow = const Duration(milliseconds: 120),
    Duration verifyBudget = const Duration(milliseconds: 1500),
  })  : _maccms = maccms ?? MacCmsResolver(),
        _dio = dio ?? AppHttp.client,
        _browserFactory = browserFactory,
        _pool = browserPool ?? sharedBrowserPool,
        _cache = cache ?? sharedStreamCache,
        _grace = grace,
        _overallTimeout = overallTimeout,
        _overallBudget = overallBudget,
        _collectWindow = collectWindow,
        _verifyBudget = verifyBudget;

  final MacCmsResolver _maccms;
  final Dio _dio;
  final HeadlessBrowser Function()? _browserFactory;
  final HeadlessBrowserPool _pool;
  final ResolvedStreamCache _cache;
  final Duration _grace;
  final Duration _overallTimeout;
  final Duration _overallBudget;
  final Duration _collectWindow;
  final Duration _verifyBudget;

  static const int _maxAttempts = 3;
  static const int _maxCandidates = 5;
  static const Duration _retryDelay = Duration(milliseconds: 500);

  bool isCached(String playPageUrl) => _cache.get(playPageUrl) != null;
  void invalidate(String playPageUrl) => _cache.invalidate(playPageUrl);

  Future<ResolveResult> resolve(
    String playPageUrl, {
    Duration timeout = const Duration(seconds: 8),
    String? userAgent,
    String? referer,
    bool legacy = false,
    CancellationToken? cancel,
    BrowserPriority priority = BrowserPriority.foreground,
  }) async {
    if (cancel?.isCancelled ?? false) {
      return const ResolveResult.failed(ResolveFailure.unknown);
    }
    final cached = _cache.get(playPageUrl);
    if (cached != null) return cached;
    final baseHeaders = <String, String>{
      'User-Agent': userAgent ?? kBrowserUserAgent,
      if (referer != null && referer.isNotEmpty) 'Referer': referer,
    };
    final directUrl = looksLikeMediaUrl(playPageUrl)
        ? playPageUrl
        : mediaUrlFromQuery(playPageUrl);
    if (directUrl != null) {
      final result = ResolveResult.success([
        MediaCandidate(directUrl, headers: baseHeaders, headersResolved: true),
      ]);
      _cache.put(playPageUrl, result);
      return result;
    }

    final total = Stopwatch()..start();
    var lastFailure = ResolveFailure.unknown;
    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      if (cancel?.isCancelled ?? false) {
        return const ResolveResult.failed(ResolveFailure.unknown);
      }
      final remaining = _overallBudget - total.elapsed;
      if (remaining <= Duration.zero) {
        lastFailure = ResolveFailure.timeout;
        break;
      }
      final result = await _resolveOnce(
        playPageUrl,
        timeout: timeout,
        attemptBudget:
            remaining < _overallTimeout ? remaining : _overallTimeout,
        baseHeaders: baseHeaders,
        userAgent: userAgent,
        referer: referer,
        legacy: legacy,
        cancel: cancel,
        priority: priority,
      );
      if (cancel?.isCancelled ?? false) {
        return const ResolveResult.failed(ResolveFailure.unknown);
      }
      if (result.ok) {
        if (result.verified) _cache.put(playPageUrl, result);
        return result;
      }
      lastFailure = result.failure ?? ResolveFailure.unknown;
      if (lastFailure == ResolveFailure.notFound) break;
      if (attempt + 1 < _maxAttempts) {
        final rest = _overallBudget - total.elapsed;
        if (rest <= Duration.zero) break;
        final delay = rest < _retryDelay ? rest : _retryDelay;
        await _waitOrCancel(delay, cancel);
      }
    }
    final failed = ResolveResult.failed(lastFailure);
    if (lastFailure == ResolveFailure.notFound &&
        !(cancel?.isCancelled ?? false)) {
      _cache.put(playPageUrl, failed);
    }
    return failed;
  }

  static Future<void> _waitOrCancel(
      Duration duration, CancellationToken? cancel) async {
    final done = Completer<void>();
    void stop() {
      if (!done.isCompleted) done.complete();
    }

    final timer = Timer(duration, stop);
    cancel?.addListener(stop);
    try {
      await done.future;
    } finally {
      timer.cancel();
      cancel?.removeListener(stop);
    }
  }

  Future<ResolveResult> _resolveOnce(
    String playPageUrl, {
    required Duration timeout,
    required Duration attemptBudget,
    required Map<String, String> baseHeaders,
    String? userAgent,
    String? referer,
    required bool legacy,
    CancellationToken? cancel,
    required BrowserPriority priority,
  }) async {
    final operation = CancellationToken();
    final discovery = CancellationToken();
    final httpCancel = CancelToken();
    final stopped = Completer<void>();
    var timedOut = false;
    void stop() {
      operation.cancel();
      discovery.cancel();
      if (!stopped.isCompleted) stopped.complete();
    }

    void stopDiscovery() => httpCancel.cancel('discovery finished');
    discovery.addListener(stopDiscovery);
    cancel?.addListener(stop);
    final timer = Timer(attemptBudget, () {
      timedOut = true;
      stop();
    });
    final seen = <String, MediaCandidate>{};
    final browserHeaders = <String, Map<String, String>>{};
    final first = Completer<void>();
    final finished = Completer<void>();
    var branches = 2;
    ResolveFailure? loadFailure;
    void branchDone() {
      if (--branches == 0 && !finished.isCompleted) finished.complete();
    }

    void observe(MediaCandidate candidate, {bool fromBrowser = false}) {
      if (discovery.isCancelled || candidate.url.isEmpty) return;
      final previous = seen[candidate.url];
      if (fromBrowser) {
        browserHeaders[candidate.url] = {
          ...?browserHeaders[candidate.url],
          ...candidate.headers,
        };
      }
      seen[candidate.url] = MediaCandidate(candidate.url,
          headers: {
            ...baseHeaders,
            if (previous != null) ...previous.headers,
            ...candidate.headers,
            // Actual browser requests outrank the HTTP parser's guessed
            // Referer, including when that parser finishes later.
            ...?browserHeaders[candidate.url],
          },
          loadId: candidate.loadId,
          headersResolved: true);
      if (!first.isCompleted) first.complete();
    }

    // Neither branch waits for the other's startup or failure.
    unawaited(() async {
      try {
        final candidate = await _maccms.resolve(playPageUrl,
            userAgent: userAgent,
            referer: referer,
            cancelToken: httpCancel,
            timeout: attemptBudget < const Duration(seconds: 4)
                ? attemptBudget
                : const Duration(seconds: 4));
        if (candidate != null) observe(candidate);
      } catch (_) {
        // Browser discovery may still succeed.
      } finally {
        branchDone();
      }
    }());
    unawaited(() async {
      PooledBrowser? pooled;
      HeadlessBrowser? direct;
      StreamSubscription<MediaCandidate>? sub;
      try {
        final factory = _browserFactory;
        final Future<void> Function() load;
        final Stream<MediaCandidate> candidates;
        if (factory != null) {
          direct = factory();
          await direct.start(
              userAgent: userAgent ?? kBrowserUserAgent,
              extraScript: legacy ? kLegacyIframeScript : null);
          if (discovery.isCancelled) return;
          candidates = direct.mediaUrls;
          load = () => direct!.load(playPageUrl, timeout: timeout);
        } else {
          pooled = await _pool.acquire(
              userAgent: userAgent ?? kBrowserUserAgent,
              priority: priority,
              cancel: discovery,
              extraScript: legacy ? kLegacyIframeScript : null);
          if (discovery.isCancelled) return;
          candidates = pooled.mediaUrls;
          load = () => pooled!.load(playPageUrl, timeout: timeout);
        }
        sub = candidates
            .listen((candidate) => observe(candidate, fromBrowser: true),
                onError: (Object error) {
          if (!discovery.isCancelled) loadFailure = _failureOf(error);
        });
        await Future.any<void>([
          () async {
            await load();
            await _waitOrCancel(_grace, discovery);
          }(),
          _untilCancelled(discovery),
        ]);
      } catch (e) {
        if (!discovery.isCancelled) {
          loadFailure = _failureOf(e, fallback: ResolveFailure.loadFailed);
        }
      } finally {
        try {
          await sub?.cancel();
        } catch (_) {}
        try {
          if (pooled != null) {
            await pooled.release();
          } else {
            await direct?.dispose();
          }
        } catch (_) {}
        branchDone();
      }
    }());

    try {
      await Future.any<void>([first.future, finished.future, stopped.future]);
      if (operation.isCancelled) {
        return ResolveResult.failed(
            timedOut ? ResolveFailure.timeout : ResolveFailure.unknown);
      }
      if (seen.isEmpty) {
        return ResolveResult.failed(loadFailure ?? ResolveFailure.notFound);
      }
      // Keep observing duplicates throughout the collection window so actual
      // network headers can enrich an earlier JavaScript-only observation.
      await _waitOrCancel(_collectWindow, operation);
      discovery.cancel();
      if (operation.isCancelled) {
        return ResolveResult.failed(
            timedOut ? ResolveFailure.timeout : ResolveFailure.unknown);
      }
      final (ordered, verified) =
          await _verifyAll(seen.values.toList(), operation);
      if (operation.isCancelled) {
        return ResolveResult.failed(
            timedOut ? ResolveFailure.timeout : ResolveFailure.unknown);
      }
      if (ordered.isEmpty) {
        return ResolveResult.failed(loadFailure ?? ResolveFailure.notFound);
      }
      return ResolveResult.success(ordered, verified: verified);
    } finally {
      timer.cancel();
      cancel?.removeListener(stop);
      stop();
    }
  }

  static Future<void> _untilCancelled(CancellationToken cancel) {
    final done = Completer<void>();
    cancel.addListener(() {
      if (!done.isCompleted) done.complete();
    });
    return done.future;
  }

  ResolveFailure _failureOf(Object e,
      {ResolveFailure fallback = ResolveFailure.unknown}) {
    if (e is SocketException || e is TimeoutException || e is DioException) {
      return ResolveFailure.network;
    }
    final s = e.toString().toLowerCase();
    if (s.contains('err_internet') ||
        s.contains('err_connection') ||
        s.contains('err_name_not_resolved') ||
        s.contains('err_timed_out') ||
        s.contains('err_address_unreachable')) {
      return ResolveFailure.network;
    }
    return fallback;
  }

  Future<(List<MediaCandidate>, bool)> _verifyAll(
      List<MediaCandidate> input, CancellationToken cancel) async {
    final unique = input.take(_maxCandidates).toList();
    if (unique.isEmpty) return (const <MediaCandidate>[], false);
    final probes = CancellationToken();
    cancel.addListener(probes.cancel);
    final results = List<(MediaCandidate?, bool)?>.filled(unique.length, null);
    final firstReachable = Completer<void>();
    final allDone = Completer<void>();
    var remaining = unique.length;
    for (var i = 0; i < unique.length; i++) {
      final index = i;
      unawaited(_verifyOne(unique[index], probes).then((r) {
        results[index] = r;
        if (r.$2 && !firstReachable.isCompleted) firstReachable.complete();
        if (--remaining == 0 && !allDone.isCompleted) allDone.complete();
      }));
    }
    try {
      await Future.any<void>([
        firstReachable.future,
        allDone.future,
        _waitOrCancel(_verifyBudget, probes),
      ]);
      final reachable = <MediaCandidate>[];
      final rest = <MediaCandidate>[];
      for (var i = 0; i < unique.length; i++) {
        final r = results[i];
        if (r == null) {
          rest.add(unique[i]);
        } else if (r.$1 != null) {
          (r.$2 ? reachable : rest).add(r.$1!);
        }
      }
      return ([...reachable, ...rest], reachable.isNotEmpty);
    } finally {
      cancel.removeListener(probes.cancel);
      probes.cancel();
    }
  }

  /// Adopt whichever header variant succeeds first, even when a sibling hangs.
  Future<(MediaCandidate?, bool)> _verifyOne(
      MediaCandidate candidate, CancellationToken cancel) async {
    final variants = _headerVariants(candidate.headers);
    final result = Completer<(MediaCandidate?, bool)>();
    var remaining = variants.length;
    var invalid = 0;
    for (final headers in variants) {
      unawaited(_reachable(candidate.url, headers, cancel).then((outcome) {
        if (outcome == _ProbeOutcome.invalidMedia) invalid++;
        if (outcome == _ProbeOutcome.reachable && !result.isCompleted) {
          result.complete((
            MediaCandidate(candidate.url,
                headers: headers,
                loadId: candidate.loadId,
                headersResolved: true),
            true,
          ));
        }
        if (--remaining == 0 && !result.isCompleted) {
          result
              .complete((invalid == variants.length ? null : candidate, false));
        }
      }));
    }
    return result.future;
  }

  List<Map<String, String>> _headerVariants(Map<String, String> headers) {
    final variants = <Map<String, String>>[headers];
    void add(Map<String, String> candidate) {
      if (!variants.any((existing) => mapEquals(existing, candidate))) {
        variants.add(candidate);
      }
    }

    add(Map<String, String>.from(headers)..remove('Origin'));
    final userAgent = headers['User-Agent'];
    add({
      if (userAgent != null && userAgent.isNotEmpty) 'User-Agent': userAgent
    });
    return variants;
  }

  /// Read at most a small prefix; Range is only a hint and may be ignored.
  Future<_ProbeOutcome> _reachable(
      String url, Map<String, String> headers, CancellationToken cancel) async {
    final requestCancel = CancelToken();
    void stop() => requestCancel.cancel('probe finished');
    cancel.addListener(stop);
    final timer = Timer(const Duration(seconds: 6), stop);
    StreamIterator<List<int>>? iterator;
    try {
      final response = await _dio.get<ResponseBody>(url,
          cancelToken: requestCancel,
          options: Options(
            responseType: ResponseType.stream,
            headers: {...headers, 'Range': 'bytes=0-4095'},
            validateStatus: (_) => true,
            receiveTimeout: const Duration(seconds: 5),
            sendTimeout: const Duration(seconds: 5),
          ));
      final code = response.statusCode ?? 0;
      if (code < 200 || code >= 300) return _ProbeOutcome.unreachable;
      final type = (response.headers.value(Headers.contentTypeHeader) ?? '')
          .toLowerCase();
      if (type.contains('html') || type.contains('mp2t')) {
        return _ProbeOutcome.invalidMedia;
      }
      final body = response.data;
      if (body == null) return _ProbeOutcome.unreachable;
      iterator = StreamIterator(body.stream);
      final prefix = <int>[];
      while (prefix.length < 4096 && await iterator.moveNext()) {
        prefix.addAll(iterator.current.take(4096 - prefix.length));
        // Enough bytes to classify a playlist or common HTML error document;
        // do not wait for a server streaming a large file to finish.
        if (prefix.length >= 256) break;
      }
      if (prefix.isEmpty) return _ProbeOutcome.unreachable;
      final text = utf8
          .decode(prefix, allowMalformed: true)
          .replaceFirst('\uFEFF', '')
          .trimLeft();
      final lower = text.toLowerCase();
      if (lower.startsWith('<!doctype html') ||
          lower.startsWith('<html') ||
          lower.startsWith('<head') ||
          lower.startsWith('<body')) {
        return _ProbeOutcome.invalidMedia;
      }
      final playlist = type.contains('mpegurl') ||
          (Uri.tryParse(url)?.path.toLowerCase().endsWith('.m3u8') ?? false);
      if (playlist && !text.startsWith('#EXTM3U')) {
        return _ProbeOutcome.invalidMedia;
      }
      return _ProbeOutcome.reachable;
    } catch (_) {
      return _ProbeOutcome.unreachable;
    } finally {
      timer.cancel();
      cancel.removeListener(stop);
      stop();
      try {
        await iterator?.cancel();
      } catch (_) {}
    }
  }
}
