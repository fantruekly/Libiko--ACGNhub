### Task 2: `WebviewScraper` + XPath→JS script builders

**Files:**
- Create: `lib/core/video/webview_scraper.dart`
- Test: `test/core/video/xpath_js_test.dart`

**Interfaces:**
- Consumes: `SourceRule` (Task 1).
- Produces: `const String kBrowserUserAgent`; `String buildSearchScript(SourceRule rule)`; `String buildEpisodesScript(SourceRule rule)`; `class WebviewScraper { Future<dynamic> fetchJson({required String url, required String script, String? userAgent, Duration timeout, int attempts}); }`.

- [ ] **Step 1: Write the failing test**

Create `test/core/video/xpath_js_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/video/source_rule.dart';
import 'package:acgnhub/core/video/webview_scraper.dart';

const _rule = SourceRule(
  name: '七色番',
  baseUrl: 'https://www.7sefun.top/',
  searchUrl: 'https://www.7sefun.top/vodsearch/-------------.html?wd=@keyword',
  searchList: '//div[2]/div[2]/div[2]/div[2]/div',
  searchName: '//div[2]/text()',
  searchResult: '//a',
  chapterRoads: '//div[2]/div[2]/div[2]/div/div[2]/div[1]//div',
  chapterResult: '//a',
);

void main() {
  test('buildSearchScript embeds the search XPaths and returns JSON', () {
    final js = buildSearchScript(_rule);
    expect(js, contains('document.evaluate'));
    expect(js, contains('"//div[2]/div[2]/div[2]/div[2]/div"'));
    expect(js, contains('"//div[2]/text()"'));
    expect(js, contains('"//a"'));
    expect(js, contains('JSON.stringify'));
  });

  test('buildEpisodesScript embeds the chapter XPaths and returns JSON', () {
    final js = buildEpisodesScript(_rule);
    expect(js, contains('"//div[2]/div[2]/div[2]/div/div[2]/div[1]//div"'));
    expect(js, contains('"//a"'));
    expect(js, contains('JSON.stringify'));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/video/xpath_js_test.dart`
Expected: FAIL — `webview_scraper.dart` not found.

- [ ] **Step 3: Create `lib/core/video/webview_scraper.dart`**

```dart
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
  return JSON.stringify(rows);
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
  return JSON.stringify(out);
})()
''';

/// Loads a URL in a headless WebView and evaluates an extraction script.
/// Mirrors [StreamResolver]'s lifecycle: create, run, load, dispose.
class WebviewScraper {
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
        if (result is List && result.isNotEmpty) return result;
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/video/xpath_js_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Verify it compiles**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/core/video/webview_scraper.dart test/core/video/xpath_js_test.dart
git commit -m "feat(video): add headless webview scraper and XPath-to-JS builders"
```

---
