import 'dart:async';

import 'package:flutter/foundation.dart';

import 'headless_browser.dart';

/// Resolves a video source's play page to a playable stream: the page is loaded
/// in a hidden browser and the app waits for it to request the media stream. The
/// candidate carries the request headers the site used, so the player can replay
/// them (some CDNs return 403 without the right Referer/User-Agent).
class StreamResolver {
  Future<MediaCandidate?> resolve(
    String playPageUrl, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final browser = createHeadlessBrowser();
    StreamSubscription<MediaCandidate>? sub;
    try {
      await browser.start();
      final completer = Completer<MediaCandidate?>();
      sub = browser.mediaUrls.listen((candidate) {
        if (candidate.url.isNotEmpty && !completer.isCompleted) {
          completer.complete(candidate);
        }
      });
      unawaited(() async {
        try {
          await browser.load(playPageUrl, timeout: timeout);
        } catch (e) {
          debugPrint('[StreamResolver] load failed for $playPageUrl: $e');
          if (!completer.isCompleted) completer.complete(null);
        }
      }());
      final candidate = await completer.future.timeout(timeout, onTimeout: () {
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
