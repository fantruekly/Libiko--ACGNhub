import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'cancellation.dart';
import 'headless_browser.dart';
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
function __rel(xpath) {
  return xpath.indexOf('//') === 0 ? '.' + xpath : xpath;
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
      name: __txt(__rel(${jsonEncode(rule.searchName)}), list[i]),
      href: __attr(__rel(${jsonEncode(rule.searchResult)}), list[i], 'href')
    });
  }
  return rows;
})()
''';

/// JS that returns a JSON array of `{title, href}` for every chapter road.
String buildEpisodesScript(SourceRule rule) => '''
(function () {
  $_helpersJs
  var out = [];
  var roads = __ev(${jsonEncode(rule.chapterRoads)}, document);
  for (var r = 0; r < roads.length; r++) {
    var links = __ev(__rel(${jsonEncode(rule.chapterResult)}), roads[r]);
    for (var i = 0; i < links.length; i++) {
      var e = links[i];
      var t = (e.textContent || '').trim();
      var h = ((e.getAttribute && e.getAttribute('href')) || '').trim();
      if (h) {
        out.push({
          title: (roads.length > 1 ? '线路' + (r + 1) + ' ' : '') + t,
          href: h
        });
      }
    }
  }
  return out;
})()
''';

/// Loads a URL in a [HeadlessBrowser] and evaluates an extraction script.
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
    Duration timeout = const Duration(seconds: 12),
    CancellationToken? cancel,
  }) async {
    final browser = createHeadlessBrowser();
    try {
      if (cancel?.isCancelled ?? false) return const <dynamic>[];
      await browser.start(userAgent: userAgent ?? kBrowserUserAgent);
      unawaited(() async {
        try {
          await browser.load(url, timeout: timeout);
        } catch (e) {
          debugPrint('[WebviewScraper] load failed for $url: $e');
        }
      }());
      final deadline = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(deadline)) {
        if (cancel?.isCancelled ?? false) return const <dynamic>[];
        dynamic result;
        try {
          result = await browser
              .eval(script)
              .timeout(const Duration(seconds: 3), onTimeout: () => null);
        } catch (_) {
          result = null;
        }
        final list = decodeResult(result);
        if (list.isNotEmpty) return list;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      return const <dynamic>[];
    } catch (e) {
      debugPrint('[WebviewScraper] failed for $url: $e');
      return null;
    } finally {
      try {
        await browser.dispose();
      } catch (_) {}
    }
  }
}
