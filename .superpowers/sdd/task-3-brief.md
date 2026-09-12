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
