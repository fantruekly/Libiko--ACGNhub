import 'dart:async';

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
      var absolute = new URL(String(url), document.baseURI).href;
      window.flutter_inappwebview.callHandler('mediaSniffer', absolute, String(mime || ''));
    } catch (e) {}
  }
  function media(u, m) {
    m = String(m || '').toLowerCase();
    if (m.indexOf('mp2t') >= 0) return false;
    if (m.indexOf('mpegurl') >= 0) return true;
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
class InAppWebViewHeadlessBrowser implements HeadlessBrowser {
  final _media = StreamController<MediaCandidate>.broadcast();
  HeadlessInAppWebView? _headless;
  Completer<void>? _loaded;
  int _loadId = 0;
  String? _extraScript;
  String? _handlerName;
  bool _acceptCandidates = false;

  @override
  Stream<MediaCandidate> get mediaUrls => _media.stream;

  @override
  int get loadId => _loadId;

  @override
  Future<void> start({String? userAgent, String? extraScript}) async {
    _extraScript = extraScript;
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
      onLoadStop: (controller, url) {
        final completer = _loaded;
        if (completer != null && !completer.isCompleted) completer.complete();
      },
      onReceivedError: (controller, request, error) {
        if (request.isForMainFrame != true) return;
        final description = error.description;
        // Redirects/navigation cancellations are not load failures.
        if (description.contains('ERR_ABORTED')) return;
        final completer = _loaded;
        if (completer != null && !completer.isCompleted) {
          completer.completeError(HeadlessLoadException(description));
        }
      },
      shouldInterceptRequest: (controller, request) async {
        final url = request.url.toString();
        final media = looksLikeMediaUrl(url) ? url : mediaUrlFromQuery(url);
        if (media != null && _acceptCandidates && !_media.isClosed) {
          _media.add(MediaCandidate(media,
              headers: playerHeadersFrom(request.headers ?? const {}),
              loadId: _loadId));
        }
        return null;
      },
    );
    _headless = headless;
    await headless.run();
  }

  @override
  Future<void> load(String url,
      {Duration timeout = const Duration(seconds: 15)}) async {
    final session = ++_loadId;
    _acceptCandidates = false;
    final controller = _headless?.webViewController;
    if (controller == null) {
      throw const HeadlessLoadException('headless browser not started');
    }
    await controller.stopLoading();
    if (_handlerName != null) {
      controller.removeJavaScriptHandler(handlerName: _handlerName!);
    }
    await controller.removeAllUserScripts();
    final handler = 'mediaSniffer$session';
    _handlerName = handler;
    controller.addJavaScriptHandler(
        handlerName: handler,
        callback: (args) {
          if (session != _loadId || !_acceptCandidates || _media.isClosed) {
            return null;
          }
          final url = args.isNotEmpty ? (args[0] ?? '').toString() : '';
          final mime = args.length > 1 ? (args[1] ?? '').toString() : '';
          final media =
              looksLikeMediaResponse(url, mime) ? url : mediaUrlFromQuery(url);
          if (media != null) _media.add(MediaCandidate(media, loadId: session));
          return null;
        });
    // Handler names are captured in each document's script. A delayed callback
    // from a previous document can no longer acquire the current loadId.
    await controller.addUserScripts(userScripts: [
      for (final script in [
        _mediaSnifferJs,
        if (_extraScript != null) _extraScript!
      ])
        UserScript(
          source: script.replaceAll("'mediaSniffer'", "'$handler'"),
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          forMainFrameOnly: false,
        ),
    ]);
    final completer = Completer<void>();
    _loaded = completer;
    try {
      _acceptCandidates = url != 'about:blank';
      await controller.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
      await completer.future.timeout(timeout,
          onTimeout: () => throw const HeadlessLoadException('load timed out'));
    } finally {
      if (identical(_loaded, completer)) _loaded = null;
    }
  }

  @override
  Future<dynamic> eval(String script) async =>
      _headless?.webViewController?.evaluateJavascript(source: script);

  @override
  Future<void> dispose() async {
    _loaded = null;
    _acceptCandidates = false;
    _loadId++;
    if (!_media.isClosed) await _media.close();
    try {
      await _headless?.dispose();
    } catch (_) {}
    _headless = null;
  }
}
