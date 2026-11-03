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
    Duration grace = const Duration(seconds: 8),
    Duration overallTimeout = const Duration(seconds: 30),
    Duration overallBudget = const Duration(seconds: 30),
    Duration collectWindow = const Duration(milliseconds: 120),
    Duration verifyBudget = const Duration(milliseconds: 1500),
    Duration unverifiedWait = const Duration(seconds: 4),
  })  : _maccms = maccms ?? MacCmsResolver(),
        _dio = dio ?? AppHttp.client,
        _browserFactory = browserFactory,
        _pool = browserPool ?? sharedBrowserPool,
        _cache = cache ?? sharedStreamCache,
        _grace = grace,
        _overallTimeout = overallTimeout,
        _overallBudget = overallBudget,
        _collectWindow = collectWindow,
        _verifyBudget = verifyBudget,
        _unverifiedWait = unverifiedWait;

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
  final Duration _unverifiedWait;

  static const int _maxAttempts = 3;
  static const int _maxCandidates = 5;
  static const Duration _retryDelay = Duration(milliseconds: 500);

  bool isCached(String playPageUrl) => _cache.get(playPageUrl) != null;
  void invalidate(String playPageUrl) => _cache.invalidate(playPageUrl);

  Future<ResolveResult> resolve(
    String playPageUrl, {
    Duration timeout = const Duration(seconds: 20),
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
        // A shortened timer can fire just before the deadline and start a
        // useless retry with less than a millisecond left in the budget.
        if (rest <= _retryDelay) break;
        await _waitOrCancel(_retryDelay, cancel);
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
    final tested = <String, MediaCandidate>{};
    final fallback = <String, MediaCandidate>{};
    Timer? fallbackTimer;
    var fallbackReady = false;
    var changed = Completer<void>();
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
      final headers = {
        ...baseHeaders,
        if (previous != null) ...previous.headers,
        ...candidate.headers,
        // Actual browser requests outrank the HTTP parser's guessed
        // Referer, including when that parser finishes later.
        ...?browserHeaders[candidate.url],
      };
      // Duplicate notifications must not cause repeated probes. Changed
      // browser headers do require a fresh probe of the same URL.
      if (previous != null && mapEquals(previous.headers, headers)) return;
      seen[candidate.url] = MediaCandidate(candidate.url,
          headers: headers, loadId: candidate.loadId, headersResolved: true);
      if (!changed.isCompleted) changed.complete();
    }

    // Neither branch waits for the other's startup or failure.
    unawaited(() async {
      try {
        final candidate = await _maccms.resolve(playPageUrl,
            userAgent: userAgent,
            referer: referer,
            cancelToken: httpCancel,
            timeout: attemptBudget < const Duration(seconds: 8)
                ? attemptBudget
                : const Duration(seconds: 8));
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
      var loaded = false;
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
            loaded = true;
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
            await pooled.release(discard: !loaded);
          } else {
            await direct?.dispose();
          }
        } catch (_) {}
        branchDone();
      }
    }());

    try {
      while (true) {
        if (operation.isCancelled) {
          // Discovery near the deadline must not lose a media URL merely
          // because its optional probe had no time left. Never cache this.
          if (timedOut && seen.isNotEmpty && !(cancel?.isCancelled ?? false)) {
            return ResolveResult.success(seen.values.toList(), verified: false);
          }
          return ResolveResult.failed(
              timedOut ? ResolveFailure.timeout : ResolveFailure.unknown);
        }
        final pending = seen.values
            .where((candidate) => !identical(tested[candidate.url], candidate))
            .take(_maxCandidates)
            .toList();
        if (pending.isEmpty) {
          if (fallback.isNotEmpty && (finished.isCompleted || fallbackReady)) {
            return ResolveResult.success(fallback.values.toList(),
                verified: false);
          }
          if (finished.isCompleted) {
            return ResolveResult.failed(loadFailure ?? ResolveFailure.notFound);
          }
          changed = Completer<void>();
          await Future.any<void>(
              [changed.future, finished.future, stopped.future]);
          continue;
        }
        // Keep the browser alive during probing. An HTML decoy discovered
        // first must not suppress the actual video requested later.
        await _waitOrCancel(_collectWindow, operation);
        if (operation.isCancelled) continue;
        final snapshot = seen.values
            .where((candidate) => !identical(tested[candidate.url], candidate))
            .take(_maxCandidates)
            .toList();
        final (ordered, verified) = await _verifyAll(snapshot, operation);
        if (cancel?.isCancelled ?? false) {
          return const ResolveResult.failed(ResolveFailure.unknown);
        }
        if (verified && ordered.isNotEmpty) {
          return ResolveResult.success(ordered, verified: verified);
        }
        for (final candidate in snapshot) {
          tested[candidate.url] = candidate;
          fallback.remove(candidate.url);
          if (!ordered.any((result) => result.url == candidate.url) &&
              identical(seen[candidate.url], candidate)) {
            seen.remove(candidate.url);
          }
        }
        for (final candidate in ordered) {
          fallback[candidate.url] = candidate;
        }
        if (fallback.isNotEmpty && fallbackTimer == null) {
          fallbackTimer = Timer(_unverifiedWait, () {
            fallbackReady = true;
            if (!changed.isCompleted) changed.complete();
          });
        }
      }
    } finally {
      timer.cancel();
      fallbackTimer?.cancel();
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
      // Retry header variants before dropping explicit refused/expired URLs.
      // Network failures and 5xx remain unverified playback fallbacks.
      if (code == 403 || code == 404 || code == 410) {
        return _ProbeOutcome.invalidMedia;
      }
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
