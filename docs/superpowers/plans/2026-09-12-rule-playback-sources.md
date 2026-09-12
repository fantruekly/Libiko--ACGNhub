# Rule-based Playback Sources Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Kazumi-compatible rule sources (JSON rules + headless-WebView scraping) and make the anime detail page auto-search every source, listing results as long bar cards (title + source name) that expand into episode buttons.

**Architecture:** `SourceRule` parses Kazumi plugin JSON. `WebviewScraper` loads a URL in the existing `HeadlessWebview` fork, waits for navigation, and runs a generated XPath→JS extraction returning JSON. `RuleVideoSource` implements the existing `VideoSource` interface on top of those two. `RuleStore` loads bundled rules from `assets/source_rules/` plus user-imported rules from the app-support dir; `video_sources.dart` exposes the combined list. The detail page's 概览 tab replaces its per-source 播放源 block with an aggregated 播放资源 section that searches all sources concurrently and streams results in.

**Tech Stack:** Flutter 3.35, Dart 3, Riverpod 2, `webview_windows` (Predidit fork, already a dependency), `path_provider`, `file_selector` (new), `html`/`dio` (existing sources).

## Global Constraints

- Target platform: Windows only; WebView2 is installed.
- Default browser `User-Agent`: `Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36`.
- New bundled rules live in `assets/source_rules/` (NOT `assets/rules/`, which is the legacy `AnimeRule` format).
- The legacy `AnimeRule` / `assets/rules/` scaffolding and `animeSourceListProvider` are untouched.
- Scraper timeout 20 s per page, up to 3 attempts for empty SPA results; whole-source timeout 25 s.
- Search concurrency cap: 3.
- Design tokens: accent `#007AFF`, surface `#FFFFFF`, border `#E5E5EA`, fg `#1C1C1E`, muted `#8E8E93`.
- `search`/`episodes` mapping is pure and unit-testable; the WebView and player are manual/integration-tested.
- Commit after every task (the user's `agent.md` requires committing per unit of work).
- Flutter commands run with `$env:Path = "C:\flutter\bin;$env:Path";` prefixed.

---

### Task 1: `SourceRule` model

**Files:**
- Create: `lib/core/video/source_rule.dart`
- Test: `test/core/video/source_rule_test.dart`

**Interfaces:**
- Produces: `class SourceRule` with fields `name`, `baseUrl`, `searchUrl`, `searchList`, `searchName`, `searchResult`, `chapterRoads`, `chapterResult`, `userAgent` (`String?`), a getter `String get id`, `factory SourceRule.fromJson(Map<String, dynamic>)`, `factory SourceRule.fromJsonString(String)`, and `String buildSearchUrl(String keyword)`.

- [ ] **Step 1: Write the failing test**

Create `test/core/video/source_rule_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/video/source_rule.dart';

void main() {
  const validJson = '''
  {
    "api": "4",
    "type": "anime",
    "name": "七色番",
    "version": "1.3",
    "muliSources": true,
    "useWebview": true,
    "useNativePlayer": true,
    "userAgent": "",
    "baseURL": "https://www.7sefun.top/",
    "searchURL": "https://www.7sefun.top/vodsearch/-------------.html?wd=@keyword",
    "searchList": "//div[2]/div[2]/div[2]/div[2]/div",
    "searchName": "//div[2]/text()",
    "searchResult": "//a",
    "chapterRoads": "//div[2]/div[2]/div[2]/div/div[2]/div[1]//div",
    "chapterResult": "//a"
  }''';

  test('fromJsonString parses a Kazumi plugin and ignores unknown keys', () {
    final rule = SourceRule.fromJsonString(validJson);
    expect(rule.name, '七色番');
    expect(rule.baseUrl, 'https://www.7sefun.top/');
    expect(rule.searchList, '//div[2]/div[2]/div[2]/div[2]/div');
    expect(rule.chapterResult, '//a');
    expect(rule.userAgent, isNull); // empty string -> null
    expect(rule.id, 'rule:七色番');
  });

  test('buildSearchUrl substitutes and URL-encodes @keyword', () {
    final rule = SourceRule.fromJsonString(validJson);
    expect(
      rule.buildSearchUrl('进击的巨人'),
      'https://www.7sefun.top/vodsearch/-------------.html?wd=%E8%BF%9B%E5%87%BB%E7%9A%84%E5%B7%A8%E4%BA%BA',
    );
  });

  test('fromJson throws FormatException on a missing required field', () {
    expect(
      () => SourceRule.fromJson({'name': 'x', 'baseURL': 'https://a/'}),
      throwsFormatException,
    );
  });

  test('fromJsonString throws FormatException on a non-object', () {
    expect(() => SourceRule.fromJsonString('[1,2,3]'), throwsFormatException);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/video/source_rule_test.dart`
Expected: FAIL — `source_rule.dart` not found.

- [ ] **Step 3: Create `lib/core/video/source_rule.dart`**

```dart
import 'dart:convert';

/// A Kazumi-compatible source rule: XPath selectors plus the URLs needed to
/// search a site and list its episodes. Unknown JSON keys are ignored so that
/// Kazumi plugin files import cleanly.
class SourceRule {
  final String name;
  final String baseUrl;
  final String searchUrl;
  final String searchList;
  final String searchName;
  final String searchResult;
  final String chapterRoads;
  final String chapterResult;
  final String? userAgent;

  const SourceRule({
    required this.name,
    required this.baseUrl,
    required this.searchUrl,
    required this.searchList,
    required this.searchName,
    required this.searchResult,
    required this.chapterRoads,
    required this.chapterResult,
    this.userAgent,
  });

  String get id => 'rule:$name';

  factory SourceRule.fromJson(Map<String, dynamic> json) {
    String req(String key) {
      final v = json[key];
      if (v is! String || v.trim().isEmpty) {
        throw FormatException('缺少或非法的字段: $key');
      }
      return v.trim();
    }

    final ua = json['userAgent'];
    return SourceRule(
      name: req('name'),
      baseUrl: req('baseURL'),
      searchUrl: req('searchURL'),
      searchList: req('searchList'),
      searchName: req('searchName'),
      searchResult: req('searchResult'),
      chapterRoads: req('chapterRoads'),
      chapterResult: req('chapterResult'),
      userAgent: (ua is String && ua.trim().isNotEmpty) ? ua.trim() : null,
    );
  }

  factory SourceRule.fromJsonString(String source) {
    final decoded = json.decode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('规则必须是 JSON 对象');
    }
    return SourceRule.fromJson(decoded);
  }

  String buildSearchUrl(String keyword) =>
      searchUrl.replaceAll('@keyword', Uri.encodeComponent(keyword));
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/video/source_rule_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/video/source_rule.dart test/core/video/source_rule_test.dart
git commit -m "feat(video): add Kazumi-compatible SourceRule model"
```

---

### Task 2: `WebviewScraper` + XPath→JS script builders

**Files:**
- Create: `lib/core/video/webview_scraper.dart`
- Test: `test/core/video/xpath_js_test.dart`

**Interfaces:**
- Consumes: `SourceRule` (Task 1).
- Produces: `const String kBrowserUserAgent`; `String buildSearchScript(SourceRule rule)`; `String buildEpisodesScript(SourceRule rule)`; `class WebviewScraper { static List<dynamic> decodeResult(dynamic result); Future<dynamic> fetchJson({required String url, required String script, String? userAgent, Duration timeout, int attempts}); }`.

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
    expect(js, contains('return rows;'));
    expect(js, isNot(contains('JSON.stringify')));
  });

  test('buildEpisodesScript embeds the chapter XPaths and returns an array', () {
    final js = buildEpisodesScript(_rule);
    expect(js, contains('"//div[2]/div[2]/div[2]/div/div[2]/div[1]//div"'));
    expect(js, contains('"//a"'));
    expect(js, contains('return out;'));
    expect(js, isNot(contains('JSON.stringify')));
  });

  test('decodeResult passes a list through and decodes a JSON string', () {
    expect(WebviewScraper.decodeResult([
      {'name': 'a'}
    ]), hasLength(1));
    expect(WebviewScraper.decodeResult('[{"name":"a"}]'), hasLength(1));
    expect(WebviewScraper.decodeResult('"oops"'), isEmpty);
    expect(WebviewScraper.decodeResult(null), isEmpty);
    expect(WebviewScraper.decodeResult('not json'), isEmpty);
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/video/xpath_js_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Verify it compiles**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/core/video/webview_scraper.dart test/core/video/xpath_js_test.dart
git commit -m "feat(video): add headless webview scraper and XPath-to-JS builders"
```

---

### Task 3: `RuleVideoSource`

**Files:**
- Create: `lib/core/video/rule_source.dart`
- Test: `test/core/video/rule_source_test.dart`

**Interfaces:**
- Consumes: `SourceRule` (Task 1); `WebviewScraper`, `buildSearchScript`, `buildEpisodesScript` (Task 2); `VideoSource`, `VideoItem`, `VideoEpisode` (existing).
- Produces: `class RuleVideoSource implements VideoSource` with `RuleVideoSource(SourceRule rule, {WebviewScraper? scraper})` and `@visibleForTesting static` `mapSearch(SourceRule, dynamic)`, `mapEpisodes(SourceRule, dynamic)`, `resolveUrl(String, String)`.

- [ ] **Step 1: Write the failing test**

Create `test/core/video/rule_source_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/video/rule_source.dart';
import 'package:acgnhub/core/video/source_rule.dart';

const _rule = SourceRule(
  name: '七色番',
  baseUrl: 'https://www.7sefun.top',
  searchUrl: 'https://www.7sefun.top/vodsearch/-------------.html?wd=@keyword',
  searchList: '//div',
  searchName: '//div[2]/text()',
  searchResult: '//a',
  chapterRoads: '//div',
  chapterResult: '//a',
);

void main() {
  test('mapSearch resolves relative hrefs and drops empty rows', () {
    final items = RuleVideoSource.mapSearch(_rule, [
      {'name': '进击的巨人', 'href': '/vod/1.html'},
      {'name': '第二季', 'href': 'https://other.test/vod/2.html'},
      {'name': '', 'href': '/vod/3.html'},
      {'name': '空链接', 'href': ''},
    ]);
    expect(items, hasLength(2));
    expect(items[0].title, '进击的巨人');
    expect(items[0].detailUrl, 'https://www.7sefun.top/vod/1.html');
    expect(items[1].detailUrl, 'https://other.test/vod/2.html');
  });

  test('mapEpisodes assigns 0-based indexes and fallback titles', () {
    final eps = RuleVideoSource.mapEpisodes(_rule, [
      {'title': '第1集', 'href': '/play/1'},
      {'title': '', 'href': '//cdn.test/play/2'},
    ]);
    expect(eps, hasLength(2));
    expect(eps[0].index, 0);
    expect(eps[0].playUrl, 'https://www.7sefun.top/play/1');
    expect(eps[1].title, '第2集');
    expect(eps[1].playUrl, 'https://cdn.test/play/2');
  });

  test('mapSearch returns empty for non-list input', () {
    expect(RuleVideoSource.mapSearch(_rule, null), isEmpty);
    expect(RuleVideoSource.mapSearch(_rule, 'oops'), isEmpty);
  });

  test('resolveUrl upgrades http and normalizes slashes', () {
    expect(RuleVideoSource.resolveUrl('http://a.test/x', 'https://b.test'),
        'https://a.test/x');
    expect(RuleVideoSource.resolveUrl('vod/1', 'https://b.test/'),
        'https://b.test/vod/1');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/video/rule_source_test.dart`
Expected: FAIL — `rule_source.dart` not found.

- [ ] **Step 3: Create `lib/core/video/rule_source.dart`**

```dart
import 'package:flutter/foundation.dart';

import 'source_rule.dart';
import 'video_source.dart';
import 'webview_scraper.dart';

/// A [VideoSource] backed by a Kazumi-compatible [SourceRule]. The search and
/// chapter pages are rendered in a headless WebView, then XPath-extracted.
class RuleVideoSource implements VideoSource {
  final SourceRule rule;
  final WebviewScraper _scraper;

  RuleVideoSource(this.rule, {WebviewScraper? scraper})
      : _scraper = scraper ?? WebviewScraper();

  @override
  String get id => rule.id;

  @override
  String get name => rule.name;

  @override
  String get baseUrl => rule.baseUrl;

  @override
  Future<List<VideoItem>> search(String keyword) async {
    final result = await _scraper.fetchJson(
      url: rule.buildSearchUrl(keyword),
      script: buildSearchScript(rule),
      userAgent: rule.userAgent,
    );
    return mapSearch(rule, result);
  }

  @override
  Future<List<VideoEpisode>> episodes(String detailUrl) async {
    final result = await _scraper.fetchJson(
      url: detailUrl,
      script: buildEpisodesScript(rule),
      userAgent: rule.userAgent,
    );
    return mapEpisodes(rule, result);
  }

  @visibleForTesting
  static List<VideoItem> mapSearch(SourceRule rule, dynamic json) {
    if (json is! List) return const [];
    final items = <VideoItem>[];
    for (final row in json) {
      if (row is! Map) continue;
      final title = (row['name'] ?? '').toString().trim();
      final href = (row['href'] ?? '').toString().trim();
      if (title.isEmpty || href.isEmpty) continue;
      final url = resolveUrl(href, rule.baseUrl);
      items.add(VideoItem(id: url, title: title, detailUrl: url));
    }
    return items;
  }

  @visibleForTesting
  static List<VideoEpisode> mapEpisodes(SourceRule rule, dynamic json) {
    if (json is! List) return const [];
    final eps = <VideoEpisode>[];
    for (final row in json) {
      if (row is! Map) continue;
      final href = (row['href'] ?? '').toString().trim();
      if (href.isEmpty) continue;
      final rawTitle = (row['title'] ?? '').toString().trim();
      final url = resolveUrl(href, rule.baseUrl);
      eps.add(VideoEpisode(
        id: url,
        title: rawTitle.isEmpty ? '第${eps.length + 1}集' : rawTitle,
        index: eps.length,
        playUrl: url,
      ));
    }
    return eps;
  }

  @visibleForTesting
  static String resolveUrl(String url, String base) {
    if (url.startsWith('http')) {
      return url.startsWith('http://')
          ? url.replaceFirst('http://', 'https://')
          : url;
    }
    if (url.startsWith('//')) return 'https:$url';
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    if (url.startsWith('/')) return '$b$url';
    return '$b/$url';
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/video/rule_source_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/video/rule_source.dart test/core/video/rule_source_test.dart
git commit -m "feat(video): add RuleVideoSource with pure search/episode mapping"
```

---

### Task 4: `RuleStore`, source registry, and the bundled 7sefun rule

**Files:**
- Create: `lib/core/video/rule_store.dart`
- Create: `lib/core/video/video_sources.dart`
- Create: `assets/source_rules/7sefun.json`
- Modify: `pubspec.yaml`
- Test: `test/core/video/rule_store_test.dart`

**Interfaces:**
- Consumes: `SourceRule` (Task 1); `RuleVideoSource` (Task 3); `AgedmSource`, `GimySource` (existing).
- Produces: `class RuleStore { Future<List<SourceRule>> loadAll(); Future<List<SourceRule>> loadBuiltIn(); Future<List<SourceRule>> loadImported(); Future<SourceRule> importJson(String rawJson); }`; `@visibleForTesting static List<SourceRule> mergeRules(List<SourceRule> builtIn, List<SourceRule> imported)`; `final ruleStoreProvider = Provider<RuleStore>(...)`; `final videoSourcesProvider = FutureProvider<List<VideoSource>>(...)`; `List<VideoSource> buildSources(List<SourceRule> rules)`.

- [ ] **Step 1: Write the failing test**

Create `test/core/video/rule_store_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/video/rule_store.dart';
import 'package:acgnhub/core/video/source_rule.dart';

SourceRule _rule(String name) => SourceRule(
      name: name,
      baseUrl: 'https://$name.test/',
      searchUrl: 'https://$name.test/s?wd=@keyword',
      searchList: '//div',
      searchName: '//div[2]',
      searchResult: '//a',
      chapterRoads: '//div',
      chapterResult: '//a',
    );

void main() {
  test('mergeRules dedupes by name and imported wins', () {
    final merged = RuleStore.mergeRules(
      [_rule('a'), _rule('b')],
      [_rule('b'), _rule('c')],
    );
    expect(merged.map((r) => r.name).toSet(), {'a', 'b', 'c'});
    expect(merged.firstWhere((r) => r.name == 'b').baseUrl, 'https://b.test/');
  });

  test('bundled 7sefun rule parses from disk', () async {
    final raw = await File('assets/source_rules/7sefun.json').readAsString();
    final rule = SourceRule.fromJsonString(raw);
    expect(rule.name, '七色番');
    expect(rule.searchUrl, contains('@keyword'));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/video/rule_store_test.dart`
Expected: FAIL — `rule_store.dart` not found.

- [ ] **Step 3: Create `assets/source_rules/7sefun.json`**

```json
{
  "api": "4",
  "type": "anime",
  "name": "七色番",
  "version": "1.3",
  "muliSources": true,
  "useWebview": true,
  "useNativePlayer": true,
  "userAgent": "",
  "baseURL": "https://www.7sefun.top/",
  "searchURL": "https://www.7sefun.top/vodsearch/-------------.html?wd=@keyword",
  "searchList": "//div[2]/div[2]/div[2]/div[2]/div",
  "searchName": "//div[2]/text()",
  "searchResult": "//a",
  "chapterRoads": "//div[2]/div[2]/div[2]/div/div[2]/div[1]//div",
  "chapterResult": "//a"
}
```

- [ ] **Step 4: Declare the asset directory in `pubspec.yaml`**

Under `flutter: assets:` add the new line (keep the existing two entries):

```yaml
  assets:
    - assets/rules/
    - assets/source_rules/
    - assets/anime_seed.json
```

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter pub get`
Expected: `Got dependencies!`

- [ ] **Step 5: Create `lib/core/video/rule_store.dart`**

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'source_rule.dart';

/// Loads built-in rules from `assets/source_rules/` and user-imported rules
/// from `<app support dir>/rules/`. Imported rules win on a name collision.
class RuleStore {
  static const _assetDir = 'assets/source_rules/';
  static const _manifest = 'AssetManifest.json';

  Future<List<SourceRule>> loadAll() async {
    final builtIn = await loadBuiltIn();
    final imported = await loadImported();
    return mergeRules(builtIn, imported);
  }

  Future<List<SourceRule>> loadBuiltIn() async {
    final rules = <SourceRule>[];
    final manifestJson = await rootBundle.loadString(_manifest);
    final manifest = json.decode(manifestJson) as Map<String, dynamic>;
    final files = manifest.keys
        .where((k) => k.startsWith(_assetDir) && k.endsWith('.json'))
        .toList()
      ..sort();
    for (final file in files) {
      try {
        rules.add(SourceRule.fromJsonString(await rootBundle.loadString(file)));
      } catch (e) {
        debugPrint('[RuleStore] bad built-in rule $file: $e');
      }
    }
    return rules;
  }

  Future<Directory> _importDir() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'rules'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<List<SourceRule>> loadImported() async {
    final dir = await _importDir();
    final rules = <SourceRule>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        rules.add(SourceRule.fromJsonString(await entity.readAsString()));
      } catch (e) {
        debugPrint('[RuleStore] bad imported rule ${entity.path}: $e');
      }
    }
    return rules;
  }

  /// Parses [rawJson] (throws [FormatException] if invalid) and persists it.
  Future<SourceRule> importJson(String rawJson) async {
    final rule = SourceRule.fromJsonString(rawJson);
    final dir = await _importDir();
    final file = File(p.join(dir.path, '${_safeName(rule.name)}.json'));
    await file.writeAsString(rawJson);
    return rule;
  }

  static String _safeName(String name) =>
      name.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');

  @visibleForTesting
  static List<SourceRule> mergeRules(
      List<SourceRule> builtIn, List<SourceRule> imported) {
    final byName = <String, SourceRule>{};
    for (final r in builtIn) {
      byName[r.name] = r;
    }
    for (final r in imported) {
      byName[r.name] = r;
    }
    return byName.values.toList();
  }
}

final ruleStoreProvider = Provider<RuleStore>((ref) => RuleStore());
```

- [ ] **Step 6: Create `lib/core/video/video_sources.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'agedm_source.dart';
import 'gimy_source.dart';
import 'rule_source.dart';
import 'rule_store.dart';
import 'source_rule.dart';
import 'video_source.dart';

/// All playback sources: the hand-written HTTP sources plus every rule source.
List<VideoSource> buildSources(List<SourceRule> rules) => [
      AgedmSource(),
      GimySource(),
      for (final rule in rules) RuleVideoSource(rule),
    ];

final videoSourcesProvider = FutureProvider<List<VideoSource>>((ref) async {
  final rules = await ref.watch(ruleStoreProvider).loadAll();
  return buildSources(rules);
});
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/video/rule_store_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 8: Verify it compiles**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

- [ ] **Step 9: Commit**

```bash
git add lib/core/video/rule_store.dart lib/core/video/video_sources.dart assets/source_rules/7sefun.json pubspec.yaml test/core/video/rule_store_test.dart
git commit -m "feat(video): add rule store, source registry, and bundled 7sefun rule"
```

---

### Task 5: Detail-page resource section (auto-search + cards + episodes)

**Files:**
- Modify: `lib/modules/anime/anime_detail_page.dart`

**Interfaces:**
- Consumes: `videoSourcesProvider` (Task 4); `VideoSource`, `VideoItem`, `VideoEpisode` (existing); `StreamResolver` (existing); `VideoPlayerPage` (existing).
- Produces: nothing consumed by later tasks (UI only).

- [ ] **Step 1: Update imports and state fields**

In `lib/modules/anime/anime_detail_page.dart`, replace the video imports (lines 11–13) with:

```dart
import '../../core/video/stream_resolver.dart';
import '../../core/video/video_source.dart';
import '../../core/video/video_sources.dart';
```

Replace the state fields (lines 29–36) — delete `_sources`, `_sourceIndex`, `_videoResults`, `_videoEpisodes`, `_videoLoading`, `_videoError`, `_videoGen`, `_selectedItem`, `_retry` and add:

```dart
  List<_SourceResult> _sourceResults = const [];
  int _searchGen = 0;
  int _searchSeq = 0;
  VideoItem? _expandedItem;
  VideoSource? _expandedSource;
  List<VideoEpisode>? _episodes;
  bool _episodesLoading = false;
  String? _episodesError;
```

Add these top-level types after the imports (before `class AnimeDetailPage`):

```dart
enum _SourceStatus { loading, done, failed }

class _SourceResult {
  final VideoSource source;
  _SourceStatus status = _SourceStatus.loading;
  List<VideoItem> items = const [];
  int seq = 0;
  _SourceResult(this.source);
}
```

- [ ] **Step 2: Trigger the search after the detail loads**

In `_load()`, replace the final line `_loadExtras();` with:

```dart
    _loadExtras();
    _scheduleSearch();
```

Add this method to `_AnimeDetailPageState`:

```dart
  void _scheduleSearch() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _searchAllSources();
    });
  }
```

- [ ] **Step 3: Replace the playback methods**

Delete `_searchVideos`, `_loadEpisodes`, `_playEpisode` and the old `_playSection` / `_resultList` / `_episodeGrid`, and add:

```dart
  Future<void> _searchAllSources() async {
    final List<VideoSource> sources;
    try {
      sources = await ref.read(videoSourcesProvider.future);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    final gen = ++_searchGen;
    setState(() {
      _sourceResults = [for (final s in sources) _SourceResult(s)];
      _expandedItem = null;
      _episodes = null;
      _episodesError = null;
      _episodesLoading = false;
    });

    final queue = [..._sourceResults];
    var next = 0;
    Future<void> worker() async {
      while (next < queue.length) {
        final r = queue[next];
        next++;
        await _searchOne(r, gen);
      }
    }

    await Future.wait([for (var i = 0; i < 3; i++) worker()]);
  }

  Future<void> _searchOne(_SourceResult r, int gen) async {
    try {
      final items =
          await r.source.search(_work.title).timeout(const Duration(seconds: 25));
      if (!mounted || gen != _searchGen) return;
      setState(() {
        r.items = items;
        r.status = _SourceStatus.done;
        r.seq = ++_searchSeq;
      });
    } catch (_) {
      if (!mounted || gen != _searchGen) return;
      setState(() => r.status = _SourceStatus.failed);
    }
  }

  List<(VideoItem, VideoSource)> get _flatResults {
    final done = _sourceResults
        .where((r) => r.status == _SourceStatus.done)
        .toList()
      ..sort((a, b) => a.seq.compareTo(b.seq));
    return [
      for (final r in done)
        for (final item in r.items) (item, r.source),
    ];
  }

  Future<void> _expandItem(VideoItem item, VideoSource source) async {
    if (identical(_expandedItem, item)) {
      setState(() {
        _expandedItem = null;
        _episodes = null;
        _episodesError = null;
        _episodesLoading = false;
      });
      return;
    }
    setState(() {
      _expandedItem = item;
      _expandedSource = source;
      _episodes = null;
      _episodesError = null;
      _episodesLoading = true;
    });
    try {
      final eps = await source.episodes(item.detailUrl);
      if (!mounted || !identical(_expandedItem, item)) return;
      setState(() {
        _episodes = eps;
        _episodesLoading = false;
      });
    } catch (_) {
      if (!mounted || !identical(_expandedItem, item)) return;
      setState(() {
        _episodesLoading = false;
        _episodesError = '获取剧集失败，请重试';
      });
    }
  }

  Future<void> _playEpisode(VideoEpisode ep) async {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final url = await StreamResolver().resolve(ep.playUrl);
    if (!mounted) return;
    Navigator.of(context).pop();
    if (url == null) {
      messenger.showSnackBar(const SnackBar(content: Text('无法解析播放地址')));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerPage(
          title: _work.title,
          episodes: _episodes ?? const [],
          initialIndex: ep.index,
        ),
      ),
    );
  }
```

- [ ] **Step 4: Replace `_playSection` with the aggregated resource section**

Replace the whole `_playSection` method with:

```dart
  Widget _playSection(Work w, ColorScheme cs) {
    final results = _flatResults;
    final loading =
        _sourceResults.any((r) => r.status == _SourceStatus.loading);
    final doneCount =
        _sourceResults.where((r) => r.status != _SourceStatus.loading).length;
    final failed = _sourceResults
        .where((r) => r.status == _SourceStatus.failed ||
            (r.status == _SourceStatus.done && r.items.isEmpty))
        .toList();

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: GlassSurface(
          blur: 0,
          borderRadius: BorderRadius.circular(16),
          padding: const EdgeInsets.all(16),
          border: Border.all(color: const Color(0xFFE5E5EA)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, 6)),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('播放资源',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface)),
                  const SizedBox(width: 10),
                  if (loading)
                    Text('搜索中 $doneCount/${_sourceResults.length}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF8E8E93)))
                  else
                    Text('共 ${results.length} 条',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF8E8E93))),
                  const Spacer(),
                  if (loading)
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  IconButton(
                    tooltip: '重新搜索',
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    onPressed: loading ? null : _searchAllSources,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_sourceResults.isEmpty)
                Text('正在准备播放源…',
                    style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.5)))
              else if (results.isEmpty && !loading)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('未找到播放资源',
                        style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withValues(alpha: 0.5))),
                    const SizedBox(height: 8),
                    TextButton(onPressed: _searchAllSources, child: const Text('重试')),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (item, source) in results)
                      _resourceCard(item, source),
                  ],
                ),
              if (failed.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${failed.length} 个源无结果或失败（${failed.map((r) => r.source.name).join('、')}）',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _resourceCard(VideoItem item, VideoSource source) {
    final expanded = identical(_expandedItem, item);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _expandItem(item, source),
              borderRadius: BorderRadius.circular(12),
              hoverColor: const Color(0x14007AFF),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E5EA)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF1C1C1E)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        source.name,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF007AFF)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded) _episodeArea(),
        ],
      ),
    );
  }

  Widget _episodeArea() {
    if (_episodesLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
            child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (_episodesError != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Text(_episodesError!,
                style: const TextStyle(
                    fontSize: 12, color: Colors.redAccent)),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                final item = _expandedItem;
                final source = _expandedSource;
                if (item == null || source == null) return;
                _expandItem(item, source);
              },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    final eps = _episodes ?? const <VideoEpisode>[];
    if (eps.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text('暂无剧集',
            style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final ep in eps)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _playEpisode(ep),
                borderRadius: BorderRadius.circular(10),
                hoverColor: const Color(0x1F007AFF),
                child: Container(
                  width: 104,
                  height: 44,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0x0F007AFF),
                    border: Border.all(color: const Color(0x4D007AFF)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    ep.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF007AFF)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
```

Note: `_expandedSource` is set in `_expandItem` (Step 3) and read by the retry above.

- [ ] **Step 5: Verify it compiles**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib`
Expected: `No issues found!`

- [ ] **Step 6: Build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug`
Expected: `Built build\windows\x64\runner\Debug\acgnhub.exe`

- [ ] **Step 7: Commit**

```bash
git add lib/modules/anime/anime_detail_page.dart
git commit -m "feat(anime): aggregate all playback sources in the detail page"
```

---

### Task 6: Import-rule button

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/modules/anime/anime_detail_page.dart`

**Interfaces:**
- Consumes: `ruleStoreProvider` (Task 4), `videoSourcesProvider` (Task 4).
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Add the file picker dependency**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter pub add file_selector`
Expected: `Got dependencies!` and a `file_selector:` line in `pubspec.yaml`.

- [ ] **Step 2: Add the import handler**

In `lib/modules/anime/anime_detail_page.dart`, add imports:

```dart
import 'package:file_selector/file_selector.dart';
import '../../core/video/rule_store.dart';
```

Add this method to `_AnimeDetailPageState`:

```dart
  Future<void> _importRule() async {
    final messenger = ScaffoldMessenger.of(context);
    const typeGroup = XTypeGroup(label: 'Kazumi 规则', extensions: ['json']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;
    try {
      final rule = await ref.read(ruleStoreProvider).importJson(
            await file.readAsString(),
          );
      ref.invalidate(videoSourcesProvider);
      if (!mounted) return;
      messenger.showSnackBar(
          SnackBar(content: Text('已导入规则：${rule.name}')));
      _searchAllSources();
    } on FormatException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
          SnackBar(content: Text('规则无效：${e.message}')));
    }
  }
```

- [ ] **Step 3: Add the button to the section header**

In `_playSection`, in the header `Row`, insert before the refresh `IconButton`:

```dart
                  IconButton(
                    tooltip: '导入规则',
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    onPressed: _importRule,
                    icon: const Icon(Icons.file_download_outlined),
                  ),
```

- [ ] **Step 4: Verify it compiles and builds**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib`
Expected: `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug`
Expected: `Built build\windows\x64\runner\Debug\acgnhub.exe`

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/modules/anime/anime_detail_page.dart
git commit -m "feat(anime): import Kazumi rule JSON from the resource section"
```

---

### Task 7: Final verification and rule calibration

**Files:** none (verification only); fixes may touch any file above.

- [ ] **Step 1: Analyze and test**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: all tests pass (the existing 49 plus the new video tests).

- [ ] **Step 2: Build and smoke-run**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug`
Then launch `build\windows\x64\runner\Debug\acgnhub.exe`.
Expected: open an anime detail page → the 概览 tab's bottom shows 播放资源 → `搜索中 n/m` then cards → a card expands to episode buttons → an episode plays.

- [ ] **Step 3: Calibrate the bundled rule**

In the app, verify the 七色番 rule returns search results and episodes for a real title. If the XPaths are wrong (0 results), inspect the rendered DOM with headless Chrome and fix `assets/source_rules/7sefun.json`:

```
& "C:\Program Files\Google\Chrome\Application\chrome.exe" --headless=new --disable-gpu --no-sandbox --virtual-time-budget=9000 --dump-dom "<search url>" > dom.html
```

Repeat until the rule works, or delete the bundled rule if the site is unusable. Record the outcome in the task report.

- [ ] **Step 4: Commit any calibration fixes**

```bash
git add assets/source_rules/ lib/core/video/ lib/modules/anime/anime_detail_page.dart
git commit -m "fix(video): calibrate bundled rule against the live site"
```

---

## Self-Review

- **Spec coverage:** §4 rule format → Task 1; §5 scraper + script builders → Task 2; `RuleVideoSource` → Task 3; §6 rule store + import + registry + `file_selector` → Tasks 4 & 6; §7 detail resource section → Task 5; §8 error handling → Tasks 2, 3, 5; §9 tests → Tasks 1–4, 7. All spec sections covered.
- **Placeholders:** none — every step has concrete code or an exact command.
- **Type consistency:** `SourceRule{name,baseUrl,searchUrl,searchList,searchName,searchResult,chapterRoads,chapterResult,userAgent}` + `id` + `buildSearchUrl`; `buildSearchScript`/`buildEpisodesScript`/`WebviewScraper.fetchJson({url,script,userAgent,timeout,attempts})`; `RuleVideoSource(SourceRule,{scraper})` + `mapSearch`/`mapEpisodes`/`resolveUrl`; `RuleStore.loadAll/loadBuiltIn/loadImported/importJson` + `mergeRules`; `ruleStoreProvider`, `videoSourcesProvider`, `buildSources` — used consistently across tasks. `_SourceResult{source,status,items,seq}` and `_SourceStatus` are local to Task 5.
