import 'dart:async';

import 'headless_browser_inappwebview.dart';

/// One media request observed by a headless browser: its URL plus the request
/// headers it was made with (so the player can replay them and avoid 403s).
class MediaCandidate {
  final String url;
  final Map<String, String> headers;

  const MediaCandidate(this.url, {this.headers = const {}});
}

const Map<String, String> _playerHeaderNames = {
  'referer': 'Referer',
  'user-agent': 'User-Agent',
  'origin': 'Origin',
};

/// Picks the request headers a player must replay: Referer, User-Agent and
/// Origin. Keys are matched case-insensitively and returned canonicalised.
Map<String, String> playerHeadersFrom(Map<String, String> requestHeaders) {
  final out = <String, String>{};
  for (final entry in requestHeaders.entries) {
    final name = _playerHeaderNames[entry.key.toLowerCase()];
    if (name != null && entry.value.isNotEmpty) out[name] = entry.value;
  }
  return out;
}

/// Reports iframe `src` URLs (for rules that expose the player via an iframe).
const String kLegacyIframeScript = r'''
(function () {
  if (window.__libikoIframe) return;
  window.__libikoIframe = true;
  function report(u) {
    try { if (u) window.flutter_inappwebview.callHandler('mediaSniffer', String(u), ''); } catch (e) {}
  }
  function scan() {
    var ifr = document.querySelectorAll('iframe');
    for (var i = 0; i < ifr.length; i++) { try { report(ifr[i].src); } catch (e) {} }
  }
  scan();
  setInterval(scan, 1000);
})();
''';

/// A hidden browser used to render source pages and sniff their media streams.
/// A single `flutter_inappwebview` implementation serves every platform; callers
/// see only this interface.
abstract class HeadlessBrowser {
  /// Creates and starts the browser. [userAgent] defaults to the browser UA
  /// chosen by the implementation. When [extraScript] is non-null it is injected
  /// at document start.
  Future<void> start({String? userAgent, String? extraScript});

  /// Media requests (.m3u8 / .mp4) the browser has observed, filtered by each
  /// implementation's own detection (native sniffing and/or [looksLikeMediaUrl]).
  Stream<MediaCandidate> get mediaUrls;

  /// Navigates to [url] and waits until the page finishes loading, at most
  /// [timeout]. Resolves normally on timeout.
  Future<void> load(String url,
      {Duration timeout = const Duration(seconds: 15)});

  /// Evaluates [script] and returns the decoded value, or null on failure.
  Future<dynamic> eval(String script);

  Future<void> dispose();
}

final RegExp _mediaRe = RegExp(r'\.(m3u8|mp4)$', caseSensitive: false);

/// True when the URL's *path* ends with a media extension. The path is used
/// (not the whole URL) so a player page like
/// `.../player/index.html?url=https://cdn/x/index.m3u8` is not mistaken for
/// the stream it embeds.
bool looksLikeMediaUrl(String url) {
  final path = Uri.tryParse(url)?.path ?? url;
  return _mediaRe.hasMatch(path);
}

/// Extracts a media URL embedded in [url]'s query string, e.g.
/// `https://proxy/a/?url=https://cdn/x/index.m3u8` -> `https://cdn/x/index.m3u8`.
/// Returns null when no query value looks like a media URL.
String? mediaUrlFromQuery(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  for (final value in uri.queryParametersAll.values.expand((v) => v)) {
    if (value.startsWith('//') && looksLikeMediaUrl('https:$value')) {
      return 'https:$value';
    }
    if ((value.startsWith('https://') || value.startsWith('http://')) &&
        looksLikeMediaUrl(value)) {
      return value;
    }
  }
  return null;
}

/// True when either the URL looks like a media file ([looksLikeMediaUrl]) or
/// the response MIME type is a streaming media type. The MIME check exists
/// because some HLS playlists are served from extension-less URLs.
bool looksLikeMediaResponse(String url, String mime) {
  final m = mime.toLowerCase();
  if (m.contains('mpegurl') || m.contains('mp2t')) return true;
  return looksLikeMediaUrl(url);
}

/// Creates the [HeadlessBrowser]. Both platforms use the `flutter_inappwebview`
/// implementation.
HeadlessBrowser createHeadlessBrowser() => InAppWebViewHeadlessBrowser();
