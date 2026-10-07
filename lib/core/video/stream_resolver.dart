import 'dart:async';
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

/// Resolves a play page to playable stream(s). Fast paths (cache, direct media
/// URL, MacCMS) run before the headless browser; the browser is borrowed from a
/// [HeadlessBrowserPool] so it is not cold-started per resolve. Every observed
/// candidate is kept so the player can fall back.
class StreamResolver {
  StreamResolver({
    MacCmsResolver? maccms,
    Dio? dio,
    HeadlessBrowser Function()? browserFactory,
    HeadlessBrowserPool? browserPool,
    ResolvedStreamCache? cache,
    Duration grace = const Duration(seconds: 2),
    Duration overallTimeout = const Duration(seconds: 8),
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

  static bool _retryable(ResolveFailure failure) =>
      failure != ResolveFailure.notFound;

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
    final cached = _cache.get(playPageUrl);
    if (cached != null) {
      debugPrint('[StreamResolver] cache hit $playPageUrl');
      return cached;
    }

    final direct = _directCandidate(playPageUrl);
    if (direct != null) {
      debugPrint('[StreamResolver] direct $playPageUrl');
      final result = ResolveResult.success([direct]);
      _cache.put(playPageUrl, result);
      return result;
    }

    final total = Stopwatch()..start();
    var lastFailure = ResolveFailure.unknown;
    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      if (cancel?.isCancelled ?? false) {
        return const ResolveResult.failed(ResolveFailure.unknown);
      }
      if (attempt > 0 && total.elapsed >= _overallBudget) {
        debugPrint('[StreamResolver] retry budget exhausted after '
            '${total.elapsedMilliseconds}ms');
        break;
      }
      final result = await _resolveOnce(
        playPageUrl,
        timeout: timeout,
        userAgent: userAgent,
        referer: referer,
        legacy: legacy,
        cancel: cancel,
        priority: priority,
      );
      if (result.ok) {
        debugPrint('[StreamResolver] resolved in ${total.elapsedMilliseconds}ms '
            '(attempt ${attempt + 1})');
        if (result.verified) {
          _cache.put(playPageUrl, result);
        }
        return result;
      }
      lastFailure = result.failure ?? ResolveFailure.unknown;
      if (!_retryable(lastFailure)) {
        debugPrint('[StreamResolver] not retrying ${lastFailure.name} for '
            '$playPageUrl (${total.elapsedMilliseconds}ms)');
        break;
      }
      if (attempt + 1 < _maxAttempts) {
        debugPrint('[StreamResolver] retrying $playPageUrl '
            '(${total.elapsedMilliseconds}ms, ${lastFailure.name})');
        await Future<void>.delayed(_retryDelay);
      }
    }
    debugPrint('[StreamResolver] gave up after ${total.elapsedMilliseconds}ms '
        '($lastFailure.name)');
    final failed = ResolveResult.failed(lastFailure);
    if (lastFailure == ResolveFailure.notFound &&
        !(cancel?.isCancelled ?? false)) {
      // Only a deterministic miss is worth remembering; transient failures
      // (timeout/loadFailed/network) and cancelled resolves must stay retryable.
      _cache.put(playPageUrl, failed);
    }
    return failed;
  }

  MediaCandidate? _directCandidate(String url) {
    if (looksLikeMediaUrl(url)) return MediaCandidate(url);
    final inner = mediaUrlFromQuery(url);
    if (inner != null && looksLikeMediaUrl(inner)) return MediaCandidate(inner);
    return null;
  }

  Future<ResolveResult> _resolveOnce(
    String playPageUrl, {
    required Duration timeout,
    String? userAgent,
    String? referer,
    required bool legacy,
    CancellationToken? cancel,
    required BrowserPriority priority,
  }) async {
    final maccmsSw = Stopwatch()..start();
    final maccmsWin = Completer<MediaCandidate>();
    MediaCandidate? maccmsResult;
    unawaited(_maccms
        .resolve(
          playPageUrl,
          userAgent: userAgent,
          referer: referer,
          timeout: const Duration(seconds: 4),
        )
        .then((candidate) {
      if (candidate != null) {
        maccmsResult = candidate;
        if (!maccmsWin.isCompleted) maccmsWin.complete(candidate);
      }
    }, onError: (_) {}));

    if (cancel?.isCancelled ?? false) {
      return const ResolveResult.failed(ResolveFailure.unknown);
    }

    PooledBrowser? pooled;
    HeadlessBrowser? direct;
    try {
      final Stream<MediaCandidate> candidates;
      final Future<void> Function() loadPage;
      final browserFactory = _browserFactory;
      if (browserFactory != null) {
        final browser = browserFactory();
        direct = browser;
        await browser.start(
          userAgent: userAgent ?? kBrowserUserAgent,
          extraScript: legacy ? kLegacyIframeScript : null,
        );
        candidates = browser.mediaUrls;
        loadPage = () => browser.load(playPageUrl, timeout: timeout);
      } else {
        final browser = await _pool.acquire(
          userAgent: userAgent ?? kBrowserUserAgent,
          priority: priority,
        );
        pooled = browser;
        candidates = browser.mediaUrls;
        loadPage = () => browser.load(playPageUrl, timeout: timeout);
      }

      final seen = <String, MediaCandidate>{};
      final first = Completer<MediaCandidate>();
      final sub = candidates.listen((candidate) {
        if (candidate.url.isEmpty) return;
        seen.putIfAbsent(candidate.url, () => candidate);
        if (!first.isCompleted) first.complete(candidate);
      });

      final cancelled = Completer<void>();
      void onCancel() {
        if (!cancelled.isCompleted) cancelled.complete();
      }
      cancel?.addListener(onCancel);

      ResolveFailure? loadFailure;
      final grace = Completer<void>();
      unawaited(() async {
        try {
          await loadPage();
        } catch (e) {
          debugPrint('[StreamResolver] load failed for $playPageUrl: $e');
          loadFailure = _failureOf(e, fallback: ResolveFailure.loadFailed);
          if (!grace.isCompleted) grace.complete();
          return;
        }
        await Future<void>.delayed(_grace);
        if (!grace.isCompleted) grace.complete();
      }());

      var timedOut = false;
      final winner = await Future.any<Object?>([
        maccmsWin.future,
        first.future,
        grace.future.then((_) => null),
        cancelled.future.then((_) => null),
      ]).timeout(_overallTimeout, onTimeout: () {
        debugPrint('[StreamResolver] TIMEOUT for $playPageUrl');
        timedOut = true;
        return null;
      });

      if (winner == null && seen.isEmpty) {
        try {
          cancel?.removeListener(onCancel);
          await sub.cancel();
        } catch (_) {}
        return ResolveResult.failed(loadFailure ??
            (timedOut ? ResolveFailure.timeout : ResolveFailure.notFound));
      }

      // Give sibling candidates from the same page a brief window to arrive
      // before unsubscribing.
      await Future<void>.delayed(_collectWindow);

      try {
        cancel?.removeListener(onCancel);
        await sub.cancel();
      } catch (_) {}

      final all = <MediaCandidate>[
        if (winner is MediaCandidate) winner,
        if (maccmsResult != null) maccmsResult!,
        ...seen.values,
      ];
      final (ordered, verified) = await _verifyAll(all);
      debugPrint('[StreamResolver] maccms=${maccmsSw.elapsedMilliseconds}ms '
          'candidates=${ordered.length} hit=${ordered.isNotEmpty}');
      if (ordered.isEmpty) {
        return ResolveResult.failed(loadFailure ??
            (timedOut ? ResolveFailure.timeout : ResolveFailure.notFound));
      }
      return ResolveResult.success(ordered, verified: verified);
    } catch (e) {
      debugPrint('[StreamResolver] failed for $playPageUrl: $e');
      return ResolveResult.failed(_failureOf(e));
    } finally {
      if (pooled != null) {
        try {
          await pooled.release();
        } catch (_) {}
      } else {
        try {
          await direct?.dispose();
        } catch (_) {}
      }
    }
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

  /// Verifies distinct candidates concurrently and returns them reachable-first.
  /// Returns as soon as one candidate verifies reachable (so a slow sibling
  /// cannot delay playback), or once all settle / [_verifyBudget] elapses.
  /// Candidates not yet verified are kept as fallbacks.
  Future<(List<MediaCandidate>, bool)> _verifyAll(
      List<MediaCandidate> input) async {
    final unique = <MediaCandidate>[];
    final seenUrls = <String>{};
    for (final candidate in input) {
      if (candidate.url.isEmpty) continue;
      if (seenUrls.add(candidate.url)) unique.add(candidate);
      if (unique.length >= _maxCandidates) break;
    }
    if (unique.isEmpty) return (const <MediaCandidate>[], false);

    final results = List<(MediaCandidate, bool)?>.filled(unique.length, null);
    final firstReachable = Completer<void>();
    final allDone = Completer<void>();
    var remaining = unique.length;
    for (var i = 0; i < unique.length; i++) {
      final index = i;
      unawaited(_verifyOne(unique[index]).then((r) {
        results[index] = r;
        remaining--;
        if (r.$2 && !firstReachable.isCompleted) firstReachable.complete();
        if (remaining == 0 && !allDone.isCompleted) allDone.complete();
      }));
    }
    await Future.any<void>([
      firstReachable.future,
      allDone.future,
      Future<void>.delayed(_verifyBudget),
    ]);

    final reachable = <MediaCandidate>[];
    final rest = <MediaCandidate>[];
    for (var i = 0; i < unique.length; i++) {
      final r = results[i];
      if (r == null) {
        rest.add(unique[i]); // not verified yet: keep as a fallback
      } else if (r.$2) {
        reachable.add(r.$1);
      } else {
        rest.add(r.$1);
      }
    }
    return ([...reachable, ...rest], reachable.isNotEmpty);
  }

  /// Picks the header variant the player can actually use, falling back to the
  /// candidate's own headers when none probes as reachable.
  Future<(MediaCandidate, bool)> _verifyOne(MediaCandidate candidate) async {
    final variants = _headerVariants(candidate.headers);
    final probes = [
      for (final headers in variants) _reachable(candidate.url, headers),
    ];
    for (var i = 0; i < variants.length; i++) {
      if (await probes[i]) {
        debugPrint('[StreamResolver] verify ok ${candidate.url} '
            'headers=${variants[i].keys.toList()}');
        return (
          MediaCandidate(candidate.url,
              headers: variants[i], loadId: candidate.loadId),
          true,
        );
      }
    }
    debugPrint('[StreamResolver] verify FAILED ${candidate.url}');
    return (candidate, false);
  }

  List<Map<String, String>> _headerVariants(Map<String, String> headers) {
    final variants = <Map<String, String>>[headers];
    void add(Map<String, String> candidate) {
      if (candidate.isEmpty) return;
      if (variants.any((existing) => mapEquals(existing, candidate))) return;
      variants.add(candidate);
    }

    add(Map<String, String>.from(headers)..remove('Origin'));
    final userAgent = headers['User-Agent'];
    if (userAgent != null && userAgent.isNotEmpty) {
      add({'User-Agent': userAgent});
    }
    return variants;
  }

  Future<bool> _reachable(String url, Map<String, String> headers) async {
    try {
      final response = await _dio
          .get<List<int>>(
            url,
            options: Options(
              responseType: ResponseType.bytes,
              headers: {...headers, 'Range': 'bytes=0-0'},
              validateStatus: (_) => true,
              receiveTimeout: const Duration(seconds: 5),
              sendTimeout: const Duration(seconds: 5),
            ),
          )
          .timeout(const Duration(seconds: 6));
      final code = response.statusCode ?? 0;
      return code >= 200 && code < 400;
    } catch (_) {
      return false;
    }
  }
}
