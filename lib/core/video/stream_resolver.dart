import 'dart:async';

import 'package:flutter/foundation.dart';

import 'headless_browser.dart';
import 'maccms.dart';
import 'webview_scraper.dart';

/// Resolves a video source's play page to a playable stream: the page is loaded
/// in a hidden browser and the app waits for it to request the media stream. The
/// candidate carries the request headers the site used, so the player can replay
/// them (some CDNs return 403 without the right Referer/User-Agent).
class StreamResolver {
  final MacCmsResolver _maccms;

  StreamResolver({MacCmsResolver? maccms}) : _maccms = maccms ?? MacCmsResolver();

  Future<MediaCandidate?> resolve(
    String playPageUrl, {
    Duration timeout = const Duration(seconds: 15),
    String? userAgent,
    String? referer,
    bool legacy = false,
  }) async {
    final direct = await _maccms.resolve(
      playPageUrl,
      userAgent: userAgent,
      referer: referer,
      timeout: const Duration(seconds: 4),
    );
    if (direct != null) return direct;

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
        } finally {
          await Future<void>.delayed(const Duration(seconds: 6));
          if (!grace.isCompleted) grace.complete();
        }
      }());
      final candidate = await Future.any<MediaCandidate?>([
        completer.future,
        grace.future.then((_) => null),
      ]).timeout(timeout + const Duration(seconds: 6), onTimeout: () {
        debugPrint('[StreamResolver] TIMEOUT for $playPageUrl');
        return null;
      });
      debugPrint('[StreamResolver] resolved=${candidate?.url}');
      return candidate;
    } catch (e) {
      debugPrint('[StreamResolver] failed for $playPageUrl: $e');
      return null;
    } finally {
      try {
        await sub?.cancel();
      } catch (_) {}
      try {
        await browser.dispose();
      } catch (_) {}
    }
  }
}
