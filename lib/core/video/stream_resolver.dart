import 'dart:async';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class StreamResolver {
  static final _mediaRe = RegExp(r'\.(m3u8|mp4)(\?|$)', caseSensitive: false);

  Future<String?> resolve(
    String playPageUrl, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final completer = Completer<String?>();
    HeadlessInAppWebView? webView;

    void finish(String? url) {
      if (!completer.isCompleted) completer.complete(url);
    }

    try {
      webView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(playPageUrl)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          useShouldInterceptRequest: true,
          mediaPlaybackRequiresUserGesture: false,
        ),
        onWebViewCreated: (controller) {
          controller.addJavaScriptHandler(
            handlerName: 'stream',
            callback: (args) {
              if (args.isNotEmpty) finish(args.first.toString());
              return null;
            },
          );
        },
        shouldInterceptRequest: (controller, request) async {
          final url = request.url.toString();
          if (_mediaRe.hasMatch(url)) finish(url);
          return null;
        },
        onLoadStop: (controller, url) async {
          await controller.evaluateJavascript(source: _hookJs);
        },
      );
      await webView.run();
      return await completer.future.timeout(timeout, onTimeout: () => null);
    } catch (_) {
      return null;
    } finally {
      try {
        await webView?.dispose();
      } catch (_) {}
    }
  }

  static const _hookJs = r'''
  (function(){
    if (window.__streamHooked) return; window.__streamHooked = true;
    function report(u){ try{ if(u && /\.(m3u8|mp4)(\?|$)/i.test(u)){ window.flutter_inappwebview.callHandler('stream', u); } }catch(e){} }
    var oo = XMLHttpRequest.prototype.open;
    XMLHttpRequest.prototype.open = function(m,u){ report(u); return oo.apply(this, arguments); };
    var of = window.fetch;
    if (of) { window.fetch = function(i){ report(typeof i === 'string' ? i : (i && i.url)); return of.apply(this, arguments); }; }
    setInterval(function(){ document.querySelectorAll('video').forEach(function(v){ if(v.src) report(v.src); if(v.currentSrc) report(v.currentSrc); }); }, 1000);
  })();
  ''';
}
