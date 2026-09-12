import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:webview_windows/webview_windows.dart';

import 'source_rule.dart';

const String kBrowserUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

const String _helpersJs = r'''
function __ev(xpath, ctx) {
  try {
    var r = document.evaluate(xpath, ctx || document, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null);
    var out = [];
    for (var i = 0; i < r.snapshotLength; i++) out.push(r.snapshotItem(i));
    return out;
  } catch (e) { return []; }
}
function __txt(xpath, ctx) {
  var n = __ev(xpath, ctx);
  if (!n.length) return '';
  return (n[0].textContent || '').trim();
}
function __attr(xpath, ctx, name) {
  var n = __ev(xpath, ctx);
  if (!n.length) return '';
  var e = n[0];
  return ((e.getAttribute && e.getAttribute(name)) || '').trim();
}
''';

/// JS that returns a JSON array of `{name, href}` for the rule's search page.
String buildSearchScript(SourceRule rule) => '''
(function () {
  $_helpersJs
  var rows = [];
  var list = __ev(${jsonEncode(rule.searchList)}, document);
  for (var i = 0; i < list.length; i++) {
    rows.push({
      name: __txt(${jsonEncode(rule.searchName)}, list[i]),
      href: __attr(${jsonEncode(rule.searchResult)}, list[i], 'href')
    });
  }
  return rows;
})()
''';

/// JS that returns a JSON array of `{title, href}` for the rule's first road.
String buildEpisodesScript(SourceRule rule) => '''
(function () {
  $_helpersJs
  var out = [];
  var roads = __ev(${jsonEncode(rule.chapterRoads)}, document);
  if (roads.length) {
    var links = __ev(${jsonEncode(rule.chapterResult)}, roads[0]);
    for (var i = 0; i < links.length; i++) {
      var e = links[i];
      out.push({
        title: (e.textContent || '').trim(),
        href: ((e.getAttribute && e.getAttribute('href')) || '').trim()
      });
    }
  }
  return out;
})()
''';

/// Loads a URL in a headless WebView and evaluates an extraction script.
/// Mirrors [StreamResolver]'s lifecycle: create, run, load, dispose.
class WebviewScraper {
  /// Normalizes an `executeScript` result to a list. The webview returns the
  /// decoded JSON value; accept a `List` directly and tolerate a JSON string.
  @visibleForTesting
  static List<dynamic> decodeResult(dynamic result) {
    if (result is List) return result;
    if (result is String) {
      try {
        final decoded = jsonDecode(result);
        if (decoded is List) return decoded;
      } catch (_) {}
    }
    return const <dynamic>[];
  }

  Future<dynamic> fetchJson({
    required String url,
    required String script,
    String? userAgent,
    Duration timeout = const Duration(seconds: 20),
    int attempts = 3,
  }) async {
    final webview = HeadlessWebview();
    final subs = <StreamSubscription>[];
    final loaded = Completer<void>();

    try {
      await webview.run();
      try {
        await webview.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      } catch (_) {}
      await webview.setUserAgent(userAgent ?? kBrowserUserAgent);

      subs.add(webview.loadingState.listen((state) {
        if (state == LoadingState.navigationCompleted && !loaded.isCompleted) {
          loaded.complete();
        }
      }));

      await webview.loadUrl(url);
      await loaded.future.timeout(timeout, onTimeout: () {});

      for (var attempt = 0; attempt < attempts; attempt++) {
        dynamic result;
        try {
          result = await webview.executeScript(script);
        } catch (_) {
          result = null;
        }
        final list = decodeResult(result);
        if (list.isNotEmpty) return list;
        if (attempt < attempts - 1) {
          await Future.delayed(const Duration(milliseconds: 600));
        }
      }
      return const <dynamic>[];
    } catch (e) {
      debugPrint('[WebviewScraper] failed for $url: $e');
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
