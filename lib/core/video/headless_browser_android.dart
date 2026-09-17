import 'dart:async';
import 'dart:collection';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'headless_browser.dart';

/// Injected before any page script runs: wraps `fetch`, `XMLHttpRequest` and
/// the `HTMLMediaElement.src` setter and reports candidate media requests back
/// through the `mediaSniffer` JavaScript handler. Needed because some HLS
/// playlists are served from extension-less URLs, which a URL check alone
/// cannot see.
const String _mediaSnifferJs = r'''
(function () {
  if (window.__libikoSniffer) return;
  window.__libikoSniffer = true;
  function report(url, mime) {
    try {
      if (!url) return;
      window.flutter_inappwebview.callHandler('mediaSniffer', String(url), String(mime || ''));
    } catch (e) {}
  }
  function media(u, m) {
    m = String(m || '').toLowerCase();
    if (m.indexOf('mpegurl') >= 0 || m.indexOf('mp2t') >= 0) return true;
    u = String(u || '').toLowerCase();
    return u.indexOf('.m3u8') >= 0 || u.indexOf('.mp4') >= 0;
  }
  var of = window.fetch;
  if (of) {
    window.fetch = function (input) {
      var u = '';
      try { u = (input && input.url) ? input.url : input; } catch (e) {}
      var p = of.apply(this, arguments);
      try {
        if (media(u, '')) report(u, '');
        if (p && typeof p.then === 'function') {
          return p.then(function (r) {
            try {
              var mime = (r && r.headers && r.headers.get) ? (r.headers.get('content-type') || '') : '';
              var ru = (r && r.url) ? r.url : u;
              if (media(ru, mime)) report(ru, mime);
            } catch (e) {}
            return r;
          });
        }
      } catch (e) {}
      return p;
    };
  }
  var oo = XMLHttpRequest.prototype.open;
  var osend = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function (method, url) {
    try { this.__libikoUrl = url; } catch (e) {}
    return oo.apply(this, arguments);
  };
  XMLHttpRequest.prototype.send = function () {
    var xhr = this;
    try {
      xhr.addEventListener('load', function () {
        try {
          var mime = xhr.getResponseHeader('content-type') || '';
          if (media(xhr.__libikoUrl, mime)) report(xhr.__libikoUrl, mime);
        } catch (e) {}
      });
    } catch (e) {}
    return osend.apply(this, arguments);
  };
  try {
    var d = Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype, 'src');
    if (d && d.set) {
      Object.defineProperty(HTMLMediaElement.prototype, 'src', {
        configurable: true,
        enumerable: d.enumerable,
        get: d.get,
        set: function (v) {
          try { if (media(v, '')) report(v, ''); } catch (e) {}
          return d.set.call(this, v);
        }
      });
    }
  } catch (e) {}
})();
''';

/// [HeadlessBrowser] backed by `flutter_inappwebview`'s headless WebView.
///
/// Media detection has two layers: the injected [_mediaSnifferJs] reports
/// candidate media requests (including extension-less HLS URLs identified by
/// MIME type), and [shouldInterceptRequest] checks every subresource URL
/// against [looksLikeMediaUrl]. Returning null leaves the request untouched.
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
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
      ),
      initialUserScripts: UnmodifiableListView<UserScript>([
        UserScript(
          source: _mediaSnifferJs,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          forMainFrameOnly: false,
        ),
      ]),
      onWebViewCreated: (controller) {
        controller.addJavaScriptHandler(
          handlerName: 'mediaSniffer',
          callback: (args) {
            final url =
                args.isNotEmpty ? (args[0] ?? '').toString() : '';
            final mime =
                args.length > 1 ? (args[1] ?? '').toString() : '';
            if (url.isNotEmpty &&
                looksLikeMediaResponse(url, mime) &&
                !_media.isClosed) {
              _media.add(url);
            }
            return null;
          },
        );
      },
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
