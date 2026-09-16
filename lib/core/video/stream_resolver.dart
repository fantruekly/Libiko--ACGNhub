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
      await browser.load(playPageUrl);
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
