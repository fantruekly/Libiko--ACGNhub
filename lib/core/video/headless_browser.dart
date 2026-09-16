import 'dart:async';

import 'headless_browser_android.dart';
import 'headless_browser_windows.dart';
import '../platform.dart';

/// A hidden browser used to render source pages and sniff their media streams.
/// Windows and Android have different native implementations; callers see only
/// this interface.
abstract class HeadlessBrowser {
  /// Creates and starts the browser. [userAgent] defaults to the browser UA
  /// chosen by the implementation.
  Future<void> start({String? userAgent});

  /// Media URLs (.m3u8 / .mp4) the browser has observed, filtered by each
  /// implementation's own detection (native sniffing and/or [looksLikeMediaUrl]).
  Stream<String> get mediaUrls;

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

/// True when either the URL looks like a media file ([looksLikeMediaUrl]) or
/// the response MIME type is a streaming media type. The MIME check exists
/// because some HLS playlists are served from extension-less URLs.
bool looksLikeMediaResponse(String url, String mime) {
  final m = mime.toLowerCase();
  if (m.contains('mpegurl') || m.contains('mp2t')) return true;
  return looksLikeMediaUrl(url);
}

/// Creates the platform's [HeadlessBrowser]. [desktop] overrides the platform
/// check for tests.
HeadlessBrowser createHeadlessBrowser({bool? desktop}) =>
    (desktop ?? isDesktop)
        ? WindowsHeadlessBrowser()
        : AndroidHeadlessBrowser();
