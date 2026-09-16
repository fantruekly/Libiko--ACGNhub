import 'dart:async';

import 'package:flutter/foundation.dart';

import 'headless_browser.dart';

/// Resolves a video source's play page to a playable stream URL: the page is
/// loaded in a hidden browser and the app waits for it to request the media
/// stream. The user never sees the source site — playback happens in the app's
/// own media_kit player.
class StreamResolver {
  Future<String?> resolve(
    String playPageUrl, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final browser = createHeadlessBrowser();
    StreamSubscription<String>? sub;
    try {
      await browser.start();
      final completer = Completer<String?>();
      sub = browser.mediaUrls.listen((url) {
        if (url.isNotEmpty && !completer.isCompleted) completer.complete(url);
      });
      // Navigation runs concurrently with the media wait so that [timeout]
      // bounds the whole operation, as it did before the HeadlessBrowser
      // refactor. Media requested during the page load is still captured
      // because the subscription above is already active.
      unawaited(() async {
        try {
          await browser.load(playPageUrl, timeout: timeout);
        } catch (e) {
          debugPrint('[StreamResolver] load failed for $playPageUrl: $e');
          if (!completer.isCompleted) completer.complete(null);
        }
      }());
      final url = await completer.future.timeout(timeout, onTimeout: () {
        debugPrint('[StreamResolver] TIMEOUT for $playPageUrl');
        return null;
      });
      debugPrint('[StreamResolver] resolved=$url');
      return url;
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
