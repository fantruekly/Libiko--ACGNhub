import 'dart:async';

import 'package:webview_windows/webview_windows.dart';

import 'headless_browser.dart';

/// [HeadlessBrowser] backed by the forked `webview_windows` headless WebView2.
class WindowsHeadlessBrowser implements HeadlessBrowser {
  final _media = StreamController<MediaCandidate>.broadcast();
  final _subs = <StreamSubscription<dynamic>>[];
  HeadlessWebview? _webview;

  @override
  Stream<MediaCandidate> get mediaUrls => _media.stream;

  @override
  Future<void> start({String? userAgent}) async {
    final webview = HeadlessWebview();
    _webview = webview;
    await webview.run();
    try {
      await webview.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
    } catch (_) {}
    if (userAgent != null) await webview.setUserAgent(userAgent);

    // Native detection is authoritative for these two: some HLS URLs carry no
    // extension, so the path check must not be applied here.
    _subs.add(webview.onM3USourceLoaded
        .listen((data) => _emit(data['url'] ?? '', always: true)));
    _subs.add(webview.onVideoSourceLoaded
        .listen((data) => _emit(data['url'] ?? '', always: true)));
    // Generic fallback for streams the native detector misses: some sites serve
    // the m3u8 as `text/html`, so neither content-type nor body detection fires.
    _subs.add(webview.onSourceLoaded
        .listen((data) => _emit(data['url'] ?? '')));
  }

  void _emit(String url, {bool always = false}) {
    if (url.isEmpty || _media.isClosed) return;
    if (!always && !looksLikeMediaUrl(url)) return;
    _media.add(MediaCandidate(url));
  }

  @override
  Future<void> load(String url,
      {Duration timeout = const Duration(seconds: 15)}) async {
    final webview = _webview;
    if (webview == null) return;
    final loaded = Completer<void>();
    final subs = <StreamSubscription<dynamic>>[];
    var currentUrl = '';
    subs.add(webview.url.listen((value) => currentUrl = value));
    subs.add(webview.loadingState.listen((state) {
      if (state == LoadingState.navigationCompleted &&
          currentUrl.isNotEmpty &&
          currentUrl != 'about:blank' &&
          !loaded.isCompleted) {
        loaded.complete();
      }
    }));
    try {
      await webview.loadUrl(url);
      await loaded.future.timeout(timeout, onTimeout: () {});
    } finally {
      for (final s in subs) {
        try {
          await s.cancel();
        } catch (_) {}
      }
    }
  }

  @override
  Future<dynamic> eval(String script) async => _webview?.executeScript(script);

  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      try {
        await s.cancel();
      } catch (_) {}
    }
    _subs.clear();
    if (!_media.isClosed) await _media.close();
    try {
      await _webview?.dispose();
    } catch (_) {}
    _webview = null;
  }
}
