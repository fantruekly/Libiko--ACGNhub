import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../services/app_http.dart';
import 'cancellation.dart';
import 'headless_browser.dart';
import 'maccms.dart';
import 'webview_scraper.dart';

enum ResolveFailure { notFound, timeout, loadFailed, network, unknown }

class ResolveResult {
  final MediaCandidate? candidate;
  final ResolveFailure? failure;

  const ResolveResult.success(MediaCandidate this.candidate) : failure = null;
  const ResolveResult.failed(ResolveFailure this.failure) : candidate = null;

  bool get ok => candidate != null;
}

/// Resolves a video source's play page to a playable stream: the page is loaded
/// in a hidden browser and the app waits for it to request the media stream. The
/// candidate carries the request headers the site used, so the player can replay
/// them (some CDNs return 403 without the right Referer/User-Agent).
class StreamResolver {
  final MacCmsResolver _maccms;
  final Dio _dio;

  StreamResolver({
    MacCmsResolver? maccms,
    Dio? dio,
    HeadlessBrowser Function()? browserFactory,
    Duration grace = const Duration(seconds: 4),
    Duration overallTimeout = const Duration(seconds: 10),
    Duration overallBudget = const Duration(seconds: 12),
  })  : _maccms = maccms ?? MacCmsResolver(),
        _dio = dio ?? AppHttp.client,
        _browserFactory = browserFactory ?? createHeadlessBrowser,
        _grace = grace,
        _overallTimeout = overallTimeout,
        _overallBudget = overallBudget;

  final HeadlessBrowser Function() _browserFactory;
  final Duration _grace;
  final Duration _overallTimeout;

  /// Wall-clock ceiling for all retry attempts combined, so a string of slow
  /// failures cannot stack into a long wait.
  final Duration _overallBudget;

  static const int _maxAttempts = 3;
  static const Duration _retryDelay = Duration(milliseconds: 500);

  /// `notFound` means the page loaded but never requested a stream, which is
  /// deterministic: retrying only burns another ~8s attempt. Transient
  /// failures (timeouts, load/network errors) are still retried.
  static bool _retryable(ResolveFailure failure) =>
      failure != ResolveFailure.notFound;

  Future<ResolveResult> resolve(
    String playPageUrl, {
    Duration timeout = const Duration(seconds: 15),
    String? userAgent,
    String? referer,
    bool legacy = false,
    CancellationToken? cancel,
  }) async {
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
      );
      if (result.ok) {
        debugPrint('[StreamResolver] resolved in ${total.elapsedMilliseconds}ms '
            '(attempt ${attempt + 1})');
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
        '(${lastFailure.name})');
    return ResolveResult.failed(lastFailure);
  }

  Future<ResolveResult> _resolveOnce(
    String playPageUrl, {
    required Duration timeout,
    String? userAgent,
    String? referer,
    required bool legacy,
    CancellationToken? cancel,
  }) async {
    final maccmsSw = Stopwatch()..start();
    final maccmsWin = Completer<MediaCandidate>();
    unawaited(_maccms
        .resolve(
          playPageUrl,
          userAgent: userAgent,
          referer: referer,
          timeout: const Duration(seconds: 4),
        )
        .then((candidate) {
      if (candidate != null && !maccmsWin.isCompleted) {
        maccmsWin.complete(candidate);
      }
    }, onError: (_) {}));

    if (cancel?.isCancelled ?? false) {
      return const ResolveResult.failed(ResolveFailure.unknown);
    }

    final cancelled = Completer<MediaCandidate?>();
    void onCancel() {
      if (!cancelled.isCompleted) cancelled.complete(null);
    }
    cancel?.addListener(onCancel);

    final browser = _browserFactory();
    StreamSubscription<MediaCandidate>? sub;
    ResolveFailure? loadFailure;
    var timedOut = false;
    final startSw = Stopwatch()..start();
    try {
      await browser.start(
        userAgent: userAgent ?? kBrowserUserAgent,
        extraScript: legacy ? kLegacyIframeScript : null,
      );
      final startMs = startSw.elapsedMilliseconds;
      final waitSw = Stopwatch()..start();
      final completer = Completer<MediaCandidate?>();
      sub = browser.mediaUrls.listen((candidate) {
        if (candidate.url.isNotEmpty && !completer.isCompleted) {
          completer.complete(candidate);
        }
      });
      final grace = Completer<void>();
      unawaited(() async {
        try {
          await browser.load(playPageUrl, timeout: timeout);
        } catch (e) {
          debugPrint('[StreamResolver] load failed for $playPageUrl: $e');
          loadFailure = _failureOf(e, fallback: ResolveFailure.loadFailed);
          if (!grace.isCompleted) grace.complete();
          return;
        }
        await Future<void>.delayed(_grace);
        if (!grace.isCompleted) grace.complete();
      }());
      final candidate = await Future.any<MediaCandidate?>([
        maccmsWin.future,
        completer.future,
        grace.future.then((_) => null),
        cancelled.future,
      ]).timeout(_overallTimeout, onTimeout: () {
        debugPrint('[StreamResolver] TIMEOUT for $playPageUrl');
        timedOut = true;
        return null;
      });
      final waitMs = waitSw.elapsedMilliseconds;
      debugPrint('[StreamResolver] resolved=${candidate?.url}');
      debugPrint('[StreamResolver] browser: maccms=${maccmsSw.elapsedMilliseconds}ms '
          'start=${startMs}ms wait=${waitMs}ms hit=${candidate != null}');
      if (candidate == null) {
        return ResolveResult.failed(loadFailure ??
            (timedOut ? ResolveFailure.timeout : ResolveFailure.notFound));
      }
      final verifySw = Stopwatch()..start();
      final verified = await _verify(candidate);
      debugPrint('[StreamResolver] verify=${verifySw.elapsedMilliseconds}ms');
      return ResolveResult.success(verified);
    } catch (e) {
      debugPrint('[StreamResolver] failed for $playPageUrl: $e');
      return ResolveResult.failed(_failureOf(e));
    } finally {
      cancel?.removeListener(onCancel);
      try {
        await sub?.cancel();
      } catch (_) {}
      try {
        await browser.dispose();
      } catch (_) {}
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

  /// Picks the header variant the player can actually use, falling back to the
  /// candidate's own headers when none probes as reachable (the probe is a
  /// transient reachability check, not a guarantee the player can play it, so a
  /// failed probe must not discard the candidate).
  ///
  /// Every variant is probed concurrently and the results are consumed in
  /// priority order, so a slow failing variant no longer blocks a later one and
  /// the wait is bounded by the slowest probe instead of their sum.
  Future<MediaCandidate> _verify(MediaCandidate candidate) async {
    final variants = _headerVariants(candidate.headers);
    final probes = [
      for (final headers in variants) _reachable(candidate.url, headers),
    ];
    for (var i = 0; i < variants.length; i++) {
      if (await probes[i]) {
        debugPrint(
            '[StreamResolver] verify ok ${candidate.url} headers=${variants[i].keys.toList()}');
        return MediaCandidate(candidate.url, headers: variants[i]);
      }
    }
    debugPrint(
        '[StreamResolver] verify FAILED ${candidate.url} headers=${candidate.headers.keys.toList()}');
    return candidate;
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
