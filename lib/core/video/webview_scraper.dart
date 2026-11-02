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
class SourceQueueTimeoutException implements Exception {
  const SourceQueueTimeoutException();

  @override
  String toString() => 'Source browser queue is busy';
}

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
    Duration timeout = const Duration(seconds: 20),
    Duration queueTimeout = const Duration(seconds: 8),
    CancellationToken? cancel,
  }) async {
    if (cancel?.isCancelled ?? false) return const <dynamic>[];
    final operationCancel = CancellationToken();
    final cancelled = Completer<List<dynamic>>();
    void onCancel() {
      if (!cancelled.isCompleted) cancelled.complete(const <dynamic>[]);
      operationCancel.cancel();
    }

    cancel?.addListener(onCancel);
    try {
      return await Future.any<List<dynamic>>([
        _fetch(
            url: url,
            script: script,
            userAgent: userAgent,
            timeout: timeout,
            queueTimeout: queueTimeout,
            cancel: operationCancel),
        cancelled.future,
      ]);
    } finally {
      operationCancel.cancel();
      cancel?.removeListener(onCancel);
    }
  }

  Future<List<dynamic>> _fetch(
      {required String url,
      required String script,
      required Duration timeout,
      required Duration queueTimeout,
      required CancellationToken cancel,
      String? userAgent}) async {
    PooledBrowser? pooled;
    var loaded = false;
    void abandon() {
      final borrowed = pooled;
      if (borrowed != null) unawaited(borrowed.release(discard: true));
    }

    cancel.addListener(abandon);
    try {
      pooled = await _pool
          .acquire(
              userAgent: userAgent ?? kBrowserUserAgent,
              priority: BrowserPriority.background,
              cancel: cancel)
          .timeout(queueTimeout, onTimeout: () {
        cancel.cancel();
        throw const SourceQueueTimeoutException();
      });
      if (cancel.isCancelled) return const <dynamic>[];
      final browser = pooled;
      Object? loadError;
      StackTrace? loadStack;
      final loadDone = Completer<void>();
      // Observe errors immediately, including when early extraction wins.
      unawaited(browser.load(url, timeout: timeout).then((_) {
        loaded = true;
        loadDone.complete();
      }, onError: (Object error, StackTrace stack) {
        loadError = error;
        loadStack = stack;
        loadDone.complete();
      }));
      final afterLoad = Stopwatch();
      Future<List<dynamic>> extract() async {
        while (!cancel.isCancelled) {
          if (loadError != null) {
            Error.throwWithStackTrace(loadError!, loadStack!);
          }
          final wasLoaded = loaded;
          final result = await browser
              .evalCurrentDocument(script, allowLoadedFallback: loaded)
              .timeout(const Duration(seconds: 3));
          if (cancel.isCancelled) return const <dynamic>[];
          final list = decodeResult(result);
          if (list.isNotEmpty) return list;
          if (!wasLoaded && loaded) continue;
          if (loaded) {
            if (!afterLoad.isRunning) afterLoad.start();
            if (afterLoad.elapsed >= const Duration(seconds: 2)) {
              return const <dynamic>[];
            }
          }
          await Future.any<void>([
            Future<void>.delayed(const Duration(milliseconds: 250)),
            if (!loaded && loadError == null) loadDone.future,
          ]);
        }
        return const <dynamic>[];
      }

      return await extract().timeout(timeout, onTimeout: () {
        cancel.cancel();
        throw TimeoutException('Source page request timed out', timeout);
      });
    } finally {
      cancel.removeListener(abandon);
      final borrowed = pooled;
      if (borrowed != null) {
        unawaited(borrowed.release(discard: cancel.isCancelled || !loaded));
      }
    }
  }
}
