import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'browser_pool.dart';
import 'cancellation.dart';
import 'headless_browser.dart';
import 'source_rule.dart';

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
          episodeTitle: t,
          lineId: 'road:' + r,
          lineName: '线路' + (r + 1),
          episodeNumber: i + 1,
          href: h
        });
      }
    }
  }
  return out;
})()
''';

/// Loads a URL in a pooled [HeadlessBrowser] and evaluates an extraction script.
class WebviewScraper {
  WebviewScraper({HeadlessBrowserPool? pool})
      : _pool = pool ?? sharedBrowserPool;

  final HeadlessBrowserPool _pool;

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
    if (cancel?.isCancelled ?? false) return const <dynamic>[];
    final operationCancel = CancellationToken();
    final cancelled = Completer<List<dynamic>>();
    void onCancel() {
      operationCancel.cancel();
      if (!cancelled.isCompleted) cancelled.complete(const <dynamic>[]);
    }

    cancel?.addListener(onCancel);
    try {
      return await Future.any<List<dynamic>>([
        _fetch(
            url: url,
            script: script,
            userAgent: userAgent,
            timeout: timeout,
            cancel: operationCancel),
        cancelled.future,
      ]).timeout(timeout, onTimeout: () {
        operationCancel.cancel();
        throw TimeoutException('Source page request timed out', timeout);
      });
    } finally {
      operationCancel.cancel();
      cancel?.removeListener(onCancel);
    }
  }

  Future<List<dynamic>> _fetch(
      {required String url,
      required String script,
      required Duration timeout,
      required CancellationToken cancel,
      String? userAgent}) async {
    PooledBrowser? pooled;
    try {
      pooled = await _pool.acquire(
          userAgent: userAgent ?? kBrowserUserAgent,
          priority: BrowserPriority.background,
          cancel: cancel);
      if (cancel.isCancelled) return const <dynamic>[];
      // Await the current navigation before extracting: a pooled browser can
      // still be flushing the previous document through its blank-page barrier.
      // Its old rows must never become a successful result for the new source.
      await pooled.load(url, timeout: timeout);
      if (cancel.isCancelled) return const <dynamic>[];
      final loadedAt = DateTime.now();
      while (!cancel.isCancelled) {
        final result =
            await pooled.eval(script).timeout(const Duration(seconds: 3));
        if (cancel.isCancelled) return const <dynamic>[];
        final list = decodeResult(result);
        if (list.isNotEmpty) return list;
        if (DateTime.now().difference(loadedAt) >= const Duration(seconds: 2)) {
          return const <dynamic>[];
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      return const <dynamic>[];
    } catch (_) {
      if (cancel.isCancelled) return const <dynamic>[];
      // A failed navigation, engine error or timeout is not an empty search.
      // Propagate it so callers cannot cache it or label the source successful.
      rethrow;
    } finally {
      final borrowed = pooled;
      if (borrowed != null) unawaited(borrowed.release());
    }
  }
}
