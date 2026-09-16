import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'headless_browser.dart';

/// [HeadlessBrowser] backed by `flutter_inappwebview`'s headless WebView.
///
/// Media detection happens in [shouldInterceptRequest]: every subresource the
/// page requests is checked against [looksLikeMediaUrl]. Returning null leaves
/// the request untouched.
class AndroidHeadlessBrowser implements HeadlessBrowser {
  final _media = StreamController<String>.broadcast();
  HeadlessInAppWebView? _headless;
  Completer<void>? _loaded;

  @override
  Stream<String> get mediaUrls => _media.stream;

  @override
  Future<void> start({String? userAgent}) async {
    final headless = HeadlessInAppWebView(
      initialSettings: InAppWebViewSettings(
        userAgent: userAgent,
        useShouldInterceptRequest: true,
        javaScriptEnabled: true,
        mediaPlaybackRequiresUserGesture: false,
        supportMultipleWindows: false,
        javaScriptCanOpenWindowsAutomatically: false,
      ),
      onLoadStop: (controller, url) {
        if (url == null || url.toString() == 'about:blank') return;
        final completer = _loaded;
        if (completer != null && !completer.isCompleted) completer.complete();
      },
      shouldInterceptRequest: (controller, request) async {
        final url = request.url.toString();
        if (looksLikeMediaUrl(url) && !_media.isClosed) _media.add(url);
        return null;
      },
    );
    _headless = headless;
    await headless.run();
  }

  @override
  Future<void> load(String url,
      {Duration timeout = const Duration(seconds: 15)}) async {
    final controller = _headless?.webViewController;
    if (controller == null) return;
    final completer = Completer<void>();
    _loaded = completer;
    try {
      await controller.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
      await completer.future.timeout(timeout, onTimeout: () {});
    } finally {
      _loaded = null;
    }
  }

  @override
  Future<dynamic> eval(String script) async =>
      _headless?.webViewController?.evaluateJavascript(source: script);

  @override
  Future<void> dispose() async {
    _loaded = null;
    if (!_media.isClosed) await _media.close();
    try {
      await _headless?.dispose();
    } catch (_) {}
    _headless = null;
  }
}
