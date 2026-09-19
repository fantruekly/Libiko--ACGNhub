import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'cancellation.dart';
import 'headless_browser.dart';
import 'maccms.dart';
import 'webview_scraper.dart';

/// Resolves a video source's play page to a playable stream: the page is loaded
/// in a hidden browser and the app waits for it to request the media stream. The
/// candidate carries the request headers the site used, so the player can replay
/// them (some CDNs return 403 without the right Referer/User-Agent).
class StreamResolver {
  final MacCmsResolver _maccms;
  final Dio _dio;

  StreamResolver({MacCmsResolver? maccms, Dio? dio})
      : _maccms = maccms ?? MacCmsResolver(),
        _dio = dio ?? Dio();

  static const int _maxAttempts = 2;

  Future<MediaCandidate?> resolve(
    String playPageUrl, {
    Duration timeout = const Duration(seconds: 15),
    String? userAgent,
    String? referer,
    bool legacy = false,
    CancellationToken? cancel,
  }) async {
    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      if (cancel?.isCancelled ?? false) return null;
      final candidate = await _resolveOnce(
        playPageUrl,
        timeout: timeout,
        userAgent: userAgent,
        referer: referer,
        legacy: legacy,
        cancel: cancel,
      );
      if (candidate != null) return candidate;
      if (attempt + 1 < _maxAttempts) {
        debugPrint('[StreamResolver] retrying $playPageUrl');
      }
    }
    return null;
  }

  Future<MediaCandidate?> _resolveOnce(
    String playPageUrl, {
    required Duration timeout,
    String? userAgent,
    String? referer,
    required bool legacy,
    CancellationToken? cancel,
  }) async {
    final direct = await _maccms.resolve(
      playPageUrl,
      userAgent: userAgent,
      referer: referer,
      timeout: const Duration(seconds: 4),
    );
    if (direct != null) return _verify(direct);

    if (cancel?.isCancelled ?? false) return null;

    final cancelled = Completer<MediaCandidate?>();
    void onCancel() {
      if (!cancelled.isCompleted) cancelled.complete(null);
    }
    cancel?.addListener(onCancel);

    final browser = createHeadlessBrowser();
    StreamSubscription<MediaCandidate>? sub;
    try {
      await browser.start(
        userAgent: userAgent ?? kBrowserUserAgent,
        extraScript: legacy ? kLegacyIframeScript : null,
      );
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
          if (!grace.isCompleted) grace.complete();
          return;
        }
        await Future<void>.delayed(const Duration(seconds: 4));
        if (!grace.isCompleted) grace.complete();
      }());
      final candidate = await Future.any<MediaCandidate?>([
        completer.future,
        grace.future.then((_) => null),
        cancelled.future,
      ]).timeout(const Duration(seconds: 10), onTimeout: () {
        debugPrint('[StreamResolver] TIMEOUT for $playPageUrl');
        return null;
      });
      debugPrint('[StreamResolver] resolved=${candidate?.url}');
      return candidate == null ? null : _verify(candidate);
    } catch (e) {
      debugPrint('[StreamResolver] failed for $playPageUrl: $e');
      return null;
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

  Future<MediaCandidate?> _verify(MediaCandidate candidate) async {
    for (final headers in _headerVariants(candidate.headers)) {
      if (await _reachable(candidate.url, headers)) {
        return MediaCandidate(candidate.url, headers: headers);
      }
    }
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
