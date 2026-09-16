import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:webview_windows/webview_windows.dart';
import 'headless_browser.dart';

/// Resolves a video source's play page to a playable stream URL, mirroring
/// Kazumi's approach: load the page in a headless WebView2 and rely on the
/// (forked) `webview_windows` native m3u8/video detection. The user never sees
/// the source site — playback happens in the app's own media_kit player.
class StreamResolver {
  Future<String?> resolve(
    String playPageUrl, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final completer = Completer<String?>();
    final webview = HeadlessWebview();
    final subs = <StreamSubscription>[];

    void finish(String url) {
      if (url.isNotEmpty && !completer.isCompleted) completer.complete(url);
    }

    try {
      await webview.run();
      try {
        await webview.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      } catch (_) {}

      subs.add(webview.onM3USourceLoaded
          .listen((data) => finish(data['url'] ?? '')));
      subs.add(webview.onVideoSourceLoaded
          .listen((data) => finish(data['url'] ?? '')));
      // Fallback for streams the native detector misses: some sites serve the
      // m3u8 as `text/html`, so neither content-type nor body detection fires.
      subs.add(webview.onSourceLoaded.listen((data) {
        final url = data['url'] ?? '';
        if (looksLikeMediaUrl(url)) finish(url);
      }));

      await webview.loadUrl(playPageUrl);
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
      for (final s in subs) {
        try {
          await s.cancel();
        } catch (_) {}
      }
      try {
        await webview.dispose();
      } catch (_) {}
    }
  }
}
