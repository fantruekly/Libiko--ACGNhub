# 游戏第二源 nekogal.com Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 接入第二游戏源 `www.nekogal.com`（分区：PC资源/汉化资源/生肉资源/模拟器资源），并把两源共用的分页与图片请求头逻辑抽出。

**Architecture:** 新增 `NekogalSource implements GameSource`（dio + html 抓取解析）；把「每 App 页 24 = 抓 2 个源站页再裁剪」的累积逻辑抽到 `game_paging.dart` 供两源共用；把图片 Referer 改为按域名选择（`game_image.dart`）。

**Tech Stack:** Flutter (Dart 3.6)、dio、html（均已有，无新增依赖）。

## Global Constraints

- 仅改动游戏模块；不改其它模块、不改游戏首页网格/详情页布局。
- 无新增依赖。不添加代码注释（除非下方给定代码已含）。
- 每 App 页仍为 24 个。
- nekogal 分区：`pcgame` PC资源、`hhzy` 汉化资源、`srzy` 生肉资源、`pegame` 模拟器资源。
- 在 `dev` 分支开发；每个任务结束提交一次。
- 测试命令：`C:\flutter\bin\flutter.bat test <path>`；静态检查：`C:\flutter\bin\flutter.bat analyze`。

---

## Task 1: 共享分页逻辑

**Files:**
- Create: `lib/core/game/game_paging.dart`
- Modify: `lib/core/game/galgamezywz_source.dart`
- Test: `test/core/game/game_paging_test.dart`

**Interfaces:**
- Consumes: `GameList` / `Game`（`models.dart`）。
- Produces: `const int gamePageSize`（24）；`class GameSourcePage { List<Game> items; bool hasMore; }`；`Future<GameList> buildGamePage({required int page, required int sourcePageSize, required Future<GameSourcePage> Function(int sourcePage) fetch})`。

### Step 1: 写测试（先失败）

Create `test/core/game/game_paging_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/game/game_paging.dart';
import 'package:acgnhub/core/game/models.dart';

Game _g(String id) => Game(id: id, title: id);

void main() {
  test('accumulates source pages to the app page size', () async {
    final requested = <int>[];
    final list =
        await buildGamePage(page: 1, sourcePageSize: 12, fetch: (p) async {
      requested.add(p);
      return GameSourcePage(
        items: [for (var i = 0; i < 12; i++) _g('$p-$i')],
        hasMore: p < 9,
      );
    });
    expect(requested, [1, 2]);
    expect(list.items, hasLength(24));
    expect(list.items.first.id, '1-0');
    expect(list.items.last.id, '2-11');
    expect(list.page, 1);
    expect(list.hasMore, isTrue);
  });

  test('trims a larger accumulation to 24', () async {
    final list =
        await buildGamePage(page: 1, sourcePageSize: 13, fetch: (p) async {
      return GameSourcePage(
        items: [for (var i = 0; i < 13; i++) _g('$p-$i')],
        hasMore: true,
      );
    });
    expect(list.items, hasLength(24));
    expect(list.items.last.id, '2-10');
  });

  test('stops early when a source page has no next', () async {
    final requested = <int>[];
    final list =
        await buildGamePage(page: 1, sourcePageSize: 12, fetch: (p) async {
      requested.add(p);
      return GameSourcePage(
        items: [for (var i = 0; i < 12; i++) _g('$p-$i')],
        hasMore: p < 1,
      );
    });
    expect(requested, [1]);
    expect(list.items, hasLength(12));
    expect(list.hasMore, isFalse);
  });

  test('stops when a later source page fails', () async {
    final requested = <int>[];
    final list =
        await buildGamePage(page: 1, sourcePageSize: 12, fetch: (p) async {
      requested.add(p);
      if (p == 2) throw Exception('boom');
      return GameSourcePage(
        items: [for (var i = 0; i < 12; i++) _g('$p-$i')],
        hasMore: true,
      );
    });
    expect(requested, [1, 2]);
    expect(list.items, hasLength(12));
    expect(list.hasMore, isFalse);
  });

  test('rethrows when the first source page fails', () {
    expect(
      () => buildGamePage(
          page: 1,
          sourcePageSize: 12,
          fetch: (p) async => throw Exception('boom')),
      throwsException,
    );
  });

  test('page 2 starts at the right source page', () async {
    final requested = <int>[];
    await buildGamePage(page: 2, sourcePageSize: 12, fetch: (p) async {
      requested.add(p);
      return GameSourcePage(items: [_g('$p')], hasMore: true);
    });
    expect(requested, [3, 4]);
  });
}
```

Run: `C:\flutter\bin\flutter.bat test test/core/game/game_paging_test.dart`
Expected: FAIL（找不到 `game_paging.dart`）。

### Step 2: 实现 `game_paging.dart`

Create `lib/core/game/game_paging.dart`:

```dart
import 'models.dart';

const int gamePageSize = 24;

class GameSourcePage {
  final List<Game> items;
  final bool hasMore;
  const GameSourcePage({required this.items, required this.hasMore});
}

Future<GameList> buildGamePage({
  required int page,
  required int sourcePageSize,
  required Future<GameSourcePage> Function(int sourcePage) fetch,
}) async {
  final pagesPerApp = (gamePageSize / sourcePageSize).ceil();
  final startServer = (page - 1) * pagesPerApp + 1;
  final items = <Game>[];
  var hasMore = false;
  for (var i = 0; i < pagesPerApp; i++) {
    final GameSourcePage result;
    try {
      result = await fetch(startServer + i);
    } catch (_) {
      if (i == 0) rethrow;
      hasMore = false;
      break;
    }
    if (result.items.isEmpty) {
      hasMore = false;
      break;
    }
    items.addAll(result.items);
    hasMore = result.hasMore;
    if (!hasMore) break;
  }
  final trimmed =
      items.length > gamePageSize ? items.sublist(0, gamePageSize) : items;
  return GameList(items: trimmed, page: page, hasMore: hasMore);
}
```

Run: `C:\flutter\bin\flutter.bat test test/core/game/game_paging_test.dart`
Expected: PASS（6 tests）。

### Step 3: 让 `GalgameZywzSource` 使用共享分页

在 `lib/core/game/galgamezywz_source.dart`：

1) 顶部 import 加入（在 `import 'game_source.dart';` 之前）：

```dart
import 'game_paging.dart';
```

2) 删除常量 `galgameZywzPageSize`（保留 `galgameZywzSourcePageSize = 12`）：

```dart
const int galgameZywzSourcePageSize = 12;
```

3) 把 `GalgameZywzSource.browse`（第 262–292 行）替换为：

```dart
  @override
  Future<GameList> browse(String optionKey, {int page = 1}) {
    return buildGamePage(
      page: page,
      sourcePageSize: galgameZywzSourcePageSize,
      fetch: (serverPage) async {
        final html = await _get(galgameZywzBrowsePath(optionKey, serverPage));
        final items = parseGameList(html);
        return GameSourcePage(
          items: items,
          hasMore: parseHasNextPage(html, itemCount: items.length),
        );
      },
    );
  }
```

Run:
- `C:\flutter\bin\flutter.bat test test/core/game/game_paging_test.dart`
- `C:\flutter\bin\flutter.bat test test/core/game/galgamezywz_source_test.dart`
Expected: 均 PASS（行为与原来一致）。

### Step 4: 静态检查 + 提交

Run: `C:\flutter\bin\flutter.bat analyze`
Expected: `No issues found!`

```bash
git add lib/core/game/game_paging.dart lib/core/game/galgamezywz_source.dart test/core/game/game_paging_test.dart
git commit -m "refactor(game): share the aligned paging logic between sources"
```

---

## Task 2: 按域名选择图片请求头

**Files:**
- Create: `lib/core/game/game_image.dart`
- Modify: `lib/core/game/galgamezywz_source.dart`
- Modify: `lib/modules/game/game_home.dart`
- Modify: `lib/modules/game/game_detail_page.dart`
- Test: `test/core/game/game_image_test.dart`

**Interfaces:**
- Produces: `gameImageHeadersFor(String? url) -> Map<String,String>`。

### Step 1: 写测试（先失败）

Create `test/core/game/game_image_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/game/game_image.dart';

void main() {
  test('selects the referer by host', () {
    expect(gameImageHeadersFor('https://pan.nekogal.top/f/x.jpg')['Referer'],
        'https://www.nekogal.com/');
    expect(gameImageHeadersFor('https://www.nekogal.com/x.jpg')['Referer'],
        'https://www.nekogal.com/');
    expect(
        gameImageHeadersFor('https://game.galgamezywz.org/x.jpg')['Referer'],
        'https://game.galgamezywz.org/');
    expect(gameImageHeadersFor(null)['Referer'],
        'https://game.galgamezywz.org/');
  });
}
```

Run: `C:\flutter\bin\flutter.bat test test/core/game/game_image_test.dart`
Expected: FAIL（找不到 `game_image.dart`）。

### Step 2: 实现 `game_image.dart`

Create `lib/core/game/game_image.dart`:

```dart
const Map<String, String> galgameZywzImageHeaders = {
  'Referer': 'https://game.galgamezywz.org/',
};

const Map<String, String> nekogalImageHeaders = {
  'Referer': 'https://www.nekogal.com/',
};

Map<String, String> gameImageHeadersFor(String? url) {
  if (url != null && url.contains('nekogal')) return nekogalImageHeaders;
  return galgameZywzImageHeaders;
}
```

Run: `C:\flutter\bin\flutter.bat test test/core/game/game_image_test.dart`
Expected: PASS（1 test）。

### Step 3: 迁移并替换调用点

1) 在 `lib/core/game/galgamezywz_source.dart` 中删除常量 `gameImageHeaders`（已迁到 `game_image.dart`，改名 `galgameZywzImageHeaders`）。

2) `lib/modules/game/game_home.dart`：
   - import 加入 `import '../../core/game/game_image.dart';`
   - `GameCard` 封面（第 46 行）`httpHeaders: gameImageHeaders,` → `httpHeaders: gameImageHeadersFor(game.coverUrl),`

3) `lib/modules/game/game_detail_page.dart`：
   - import 加入 `import '../../core/game/game_image.dart';`
   - `_gallery` 画廊缩略图（第 252 行）`httpHeaders: gameImageHeaders,` → `httpHeaders: gameImageHeadersFor(urls[i]),`
   - `_cover`（第 286 行）`httpHeaders: gameImageHeaders,` → `httpHeaders: gameImageHeadersFor(url),`
   - `_ImageViewerPage`（第 348 行）`httpHeaders: gameImageHeaders,` → `httpHeaders: gameImageHeadersFor(widget.urls[i]),`

Run:
- `C:\flutter\bin\flutter.bat test test/core/game/game_image_test.dart`
- `C:\flutter\bin\flutter.bat test test/modules/game/game_home_test.dart`
- `C:\flutter\bin\flutter.bat test test/modules/game/game_detail_page_test.dart`
- `C:\flutter\bin\flutter.bat analyze`
Expected: 均 PASS；analyze `No issues found!`（无残留 `gameImageHeaders` 引用）。

### Step 4: 提交

```bash
git add lib/core/game/game_image.dart lib/core/game/galgamezywz_source.dart lib/modules/game/game_home.dart lib/modules/game/game_detail_page.dart test/core/game/game_image_test.dart
git commit -m "feat(game): choose image referer by host"
```

---

## Task 3: NekogalSource

**Files:**
- Create: `lib/core/game/nekogal_source.dart`
- Modify: `lib/modules/game/game_providers.dart`
- Test: `test/core/game/nekogal_parser_test.dart`
- Test: `test/core/game/nekogal_source_test.dart`

**Interfaces:**
- Consumes: `buildGamePage` / `GameSourcePage`（Task 1）、`GameSource` / `Game` / `GameDetail` / `GameList` / `GameBrowseOption`。
- Produces: `class NekogalSource implements GameSource`（id `nekogal`、name `NekoGAL`、baseUrl `https://www.nekogal.com`）；解析函数 `nekogalIdFromHref` / `parseNekogalCount` / `nekogalBrowsePath` / `parseNekogalList` / `parseNekogalHasNext` / `parseNekogalDetail`。

### Step 1: 写解析测试（先失败）

Create `test/core/game/nekogal_parser_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/game/nekogal_source.dart';

const _listHtml = '''
<div class="posts-row ajaxpager">
  <posts class="posts-item list ajax-item flex">
    <div class="item-thumbnail"><a href="/archives/6661"><img src="/thumbnail.svg" data-src="https://pan.nekogal.top/f/x/cover.jpg" class="lazyload"></a></div>
    <h2 class="item-heading"><a href="/archives/6661">【PC游戏/机翻】制服女友3</a></h2>
    <div class="item-excerpt muted-color">游戏简介文本。</div>
    <div class="item-tags"><a href="/archives/tag/adv" class="but"># ADV</a></div>
    <item class="meta-author"><span title="2026-09-14 20:56:06">20小时前</span></item>
    <div class="meta-right"><item class="meta-comm">1</item><item class="meta-view">451</item><item class="meta-like">8</item></div>
  </posts>
  <posts class="posts-item list ajax-item">
    <h2 class="item-heading"><a href="/archives/category/pcgame">没有详情链接</a></h2>
  </posts>
</div>
<nav class="navigation pagination"><a class="next page-numbers" href="/archives/category/pcgame/page/2">下一页</a></nav>
''';

const _listNoNextHtml = '''
<div class="posts-row ajaxpager">
  <posts class="posts-item list ajax-item">
    <h2 class="item-heading"><a href="/archives/9">最后一页</a></h2>
  </posts>
</div>
<nav class="navigation pagination"><span class="page-numbers current">1</span></nav>
''';

const _detailHtml = '''
<div class="single-head-cover"><div class="graphic single-cover imgbox-container">
  <img class="fit-cover lazyload" src="/thumbnail-lg.svg" data-src="https://pan.nekogal.top/f/x/cover.jpg">
  <h1 class="article-title title-h-left">【PC游戏/机翻】制服女友3</h1>
  <ul class="breadcrumb"><a href="/archives/category/pcgame">PC资源</a></ul>
  <div class="post-metas"><item class="meta-view">451</item><item class="meta-like">8</item></div>
</div></div>
<div class="article-header"><span title="2026年09月14日 20:56发布">2026-09-14</span></div>
<article class="article"><div class="article-content"><div class="wp-posts-content">
  <h2>游戏简介</h2>
  <p>第一段简介。</p>
  <p>第二段简介。</p>
  <img src="/lazy.svg" data-src="https://pan.nekogal.top/f/x/1.jpg">
  <img data-src="https://pan.nekogal.top/f/x/1.jpg">
  <img src="data:image/gif;base64,AAAA">
</div></div></article>
<div class="theme-box article-tags">
  <a class="but c-blue" href="/archives/category/pcgame">PC资源</a>
  <a class="but c-yellow" href="/archives/category/pcgame/hhzy">汉化资源</a>
  <a href="/archives/tag/adv" class="but"># ADV</a>
</div>
''';

void main() {
  test('nekogalIdFromHref extracts the numeric id', () {
    expect(nekogalIdFromHref('https://www.nekogal.com/archives/6661'), '6661');
    expect(nekogalIdFromHref('/archives/9'), '9');
    expect(nekogalIdFromHref('/archives/category/pcgame'), isNull);
    expect(nekogalIdFromHref(null), isNull);
  });

  test('parseNekogalCount strips non-digits', () {
    expect(parseNekogalCount('451'), 451);
    expect(parseNekogalCount('1.2K'), 12);
    expect(parseNekogalCount(''), isNull);
  });

  test('nekogalBrowsePath maps options to paths', () {
    expect(nekogalBrowsePath('pcgame', 1), '/archives/category/pcgame');
    expect(nekogalBrowsePath('pcgame', 3), '/archives/category/pcgame/page/3');
    expect(nekogalBrowsePath('hhzy', 1), '/archives/category/pcgame/hhzy');
    expect(nekogalBrowsePath('pegame', 2), '/archives/category/pegame/page/2');
    expect(() => nekogalBrowsePath('nope', 1), throwsArgumentError);
  });

  test('parseNekogalList parses items and skips link-less ones', () {
    final items = parseNekogalList(_listHtml);
    expect(items, hasLength(1));
    expect(items.first.id, '6661');
    expect(items.first.title, '【PC游戏/机翻】制服女友3');
    expect(items.first.coverUrl, 'https://pan.nekogal.top/f/x/cover.jpg');
    expect(items.first.summary, '游戏简介文本。');
    expect(items.first.publishedAt, DateTime.parse('2026-09-14 20:56:06'));
    expect(items.first.views, 451);
    expect(items.first.extra['url'], 'https://www.nekogal.com/archives/6661');
  });

  test('parseNekogalHasNext follows the next link, else the item-count fallback',
      () {
    expect(parseNekogalHasNext(_listHtml, itemCount: 1), isTrue);
    expect(parseNekogalHasNext(_listNoNextHtml, itemCount: 1), isFalse);
    expect(parseNekogalHasNext('<html></html>', itemCount: 12), isTrue);
    expect(parseNekogalHasNext('<html></html>', itemCount: 3), isFalse);
  });

  test('parseNekogalDetail extracts fields', () {
    final detail =
        parseNekogalDetail(_detailHtml, 'https://www.nekogal.com/archives/6661');
    expect(detail.game.id, '6661');
    expect(detail.game.title, '【PC游戏/机翻】制服女友3');
    expect(detail.game.coverUrl, 'https://pan.nekogal.top/f/x/cover.jpg');
    expect(detail.game.category, 'PC资源');
    expect(detail.game.tags, ['ADV']);
    expect(detail.game.views, 451);
    expect(detail.game.publishedAt, DateTime(2026, 9, 14));
    expect(detail.paragraphs, ['第一段简介。', '第二段简介。']);
    expect(detail.screenshots, ['https://pan.nekogal.top/f/x/1.jpg']);
    expect(detail.size, isNull);
    expect(detail.platform, isNull);
    expect(detail.sourceUrl, 'https://www.nekogal.com/archives/6661');
  });
}
```

Run: `C:\flutter\bin\flutter.bat test test/core/game/nekogal_parser_test.dart`
Expected: FAIL（找不到 `nekogal_source.dart`）。

### Step 2: 实现 `nekogal_source.dart`

Create `lib/core/game/nekogal_source.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'game_paging.dart';
import 'game_source.dart';
import 'models.dart';

const String nekogalBaseUrl = 'https://www.nekogal.com';
const String nekogalUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
const int nekogalSourcePageSize = 12;

const Map<String, String> _nekogalCategoryPaths = {
  'pcgame': '/archives/category/pcgame',
  'hhzy': '/archives/category/pcgame/hhzy',
  'srzy': '/archives/category/pcgame/srzy',
  'pegame': '/archives/category/pegame',
};

final RegExp _postHref = RegExp(r'/archives/(\d+)');

String? nekogalIdFromHref(String? href) {
  if (href == null) return null;
  return _postHref.firstMatch(href)?.group(1);
}

String _absUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  if (url.startsWith('http')) return url;
  if (url.startsWith('//')) return 'https:$url';
  return url.startsWith('/') ? '$nekogalBaseUrl$url' : '$nekogalBaseUrl/$url';
}

String _textOf(dom.Element? el) => el?.text.trim() ?? '';

int? parseNekogalCount(String raw) {
  final s = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (s.isEmpty) return null;
  return int.tryParse(s);
}

String nekogalBrowsePath(String optionKey, int page) {
  final path = _nekogalCategoryPaths[optionKey];
  if (path == null) {
    throw ArgumentError('unknown nekogal browse option: $optionKey');
  }
  return page <= 1 ? path : '$path/page/$page';
}

Game? _gameFromItem(dom.Element item) {
  final titleA = item.querySelector('.item-heading a');
  final id = nekogalIdFromHref(titleA?.attributes['href']);
  if (titleA == null || id == null) return null;
  final img = item.querySelector('.item-thumbnail img');
  final cover = _absUrl(img?.attributes['data-src'] ?? img?.attributes['src']);
  final summary = _textOf(item.querySelector('.item-excerpt'));
  final dateRaw = item.querySelector('.meta-author span')?.attributes['title'];
  return Game(
    id: id,
    title: _textOf(titleA),
    coverUrl: cover.isEmpty ? null : cover,
    summary: summary.isEmpty ? null : summary,
    publishedAt: dateRaw == null ? null : DateTime.tryParse(dateRaw),
    views: parseNekogalCount(_textOf(item.querySelector('item.meta-view'))),
    extra: {'url': '$nekogalBaseUrl/archives/$id'},
  );
}

List<Game> parseNekogalList(String html) {
  final doc = html_parser.parse(html);
  final out = <Game>[];
  for (final item in doc.querySelectorAll('posts.posts-item')) {
    final g = _gameFromItem(item);
    if (g != null) out.add(g);
  }
  return out;
}

bool parseNekogalHasNext(String html, {required int itemCount}) {
  final doc = html_parser.parse(html);
  if (doc.querySelector('a.next.page-numbers') != null) return true;
  if (doc.querySelector('.page-numbers') != null) return false;
  return itemCount >= 12;
}

DateTime? _parseChineseDate(String raw) {
  final m = RegExp(r'(\d{4})年(\d{2})月(\d{2})日').firstMatch(raw);
  if (m == null) return DateTime.tryParse(raw);
  return DateTime(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
  );
}

GameDetail parseNekogalDetail(String html, String sourceUrl) {
  final doc = html_parser.parse(html);
  final id = nekogalIdFromHref(sourceUrl) ?? '';
  final title = _textOf(doc.querySelector('h1.article-title'));
  final img = doc.querySelector('.single-cover img');
  final cover = _absUrl(img?.attributes['data-src'] ?? img?.attributes['src']);

  String? category;
  final tags = <String>[];
  for (final a in doc.querySelectorAll('.article-tags a')) {
    final href = a.attributes['href'] ?? '';
    final text = _textOf(a);
    if (text.isEmpty) continue;
    if (href.contains('/archives/tag/')) {
      tags.add(text.startsWith('#') ? text.substring(1).trim() : text);
    } else if (category == null && a.classes.contains('c-blue')) {
      category = text;
    }
  }

  final dateRaw = doc.querySelector('.article-header span')?.attributes['title'];

  final paragraphs = <String>[];
  final screenshots = <String>[];
  final content = doc.querySelector('.article-content .wp-posts-content') ??
      doc.querySelector('.article-content');
  if (content != null) {
    final ps = content.querySelectorAll('p');
    if (ps.isEmpty) {
      final t = _textOf(content);
      if (t.isNotEmpty) paragraphs.add(t);
    } else {
      for (final p in ps) {
        final t = _textOf(p);
        if (t.isNotEmpty) paragraphs.add(t);
      }
    }
    final seen = <String>{};
    for (final im in content.querySelectorAll('img')) {
      final raw = im.attributes['data-src'] ?? im.attributes['src'];
      if (raw == null || raw.isEmpty || raw.startsWith('data:')) continue;
      final src = _absUrl(raw);
      if (cover.isNotEmpty && src == cover) continue;
      if (seen.add(src)) screenshots.add(src);
    }
  }

  final game = Game(
    id: id,
    title: title,
    coverUrl: cover.isEmpty ? null : cover,
    category: category,
    tags: tags,
    publishedAt: dateRaw == null ? null : _parseChineseDate(dateRaw),
    views: parseNekogalCount(
        _textOf(doc.querySelector('.post-metas item.meta-view'))),
    extra: {'url': sourceUrl},
  );

  return GameDetail(
    game: game,
    paragraphs: paragraphs,
    screenshots: screenshots,
    sourceUrl: sourceUrl,
  );
}

class NekogalSource implements GameSource {
  NekogalSource({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: nekogalBaseUrl,
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 20),
              headers: {
                'User-Agent': nekogalUserAgent,
                'Accept':
                    'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
                'Referer': '$nekogalBaseUrl/',
              },
            ));

  final Dio _dio;

  @override
  String get id => 'nekogal';

  @override
  String get name => 'NekoGAL';

  @override
  String get baseUrl => nekogalBaseUrl;

  @override
  List<GameBrowseOption> get browseOptions => const [
        GameBrowseOption(key: 'pcgame', label: 'PC资源'),
        GameBrowseOption(key: 'hhzy', label: '汉化资源'),
        GameBrowseOption(key: 'srzy', label: '生肉资源'),
        GameBrowseOption(key: 'pegame', label: '模拟器资源'),
      ];

  @override
  Future<GameList> browse(String optionKey, {int page = 1}) {
    return buildGamePage(
      page: page,
      sourcePageSize: nekogalSourcePageSize,
      fetch: (serverPage) async {
        final html = await _get(nekogalBrowsePath(optionKey, serverPage));
        final items = parseNekogalList(html);
        return GameSourcePage(
          items: items,
          hasMore: parseNekogalHasNext(html, itemCount: items.length),
        );
      },
    );
  }

  @override
  Future<GameDetail> detail(String id) async {
    final html = await _get('/archives/$id');
    return parseNekogalDetail(html, '$nekogalBaseUrl/archives/$id');
  }

  Future<String> _get(String path) async {
    final res = await _dio.get<String>(
      path,
      options: Options(responseType: ResponseType.plain),
    );
    final data = res.data;
    if (res.statusCode != 200 || data == null) {
      throw Exception('nekogal 请求失败：$path (${res.statusCode})');
    }
    return data;
  }
}
```

Run: `C:\flutter\bin\flutter.bat test test/core/game/nekogal_parser_test.dart`
Expected: PASS（6 tests）。

### Step 3: 写源接线测试

Create `test/core/game/nekogal_source_test.dart`:

```dart
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/game/nekogal_source.dart';

String _listPageHtml(int count, {String? next, int base = 0}) {
  final items = StringBuffer();
  for (var i = 0; i < count; i++) {
    final id = base + i;
    items.write(
        '<posts class="posts-item list ajax-item">'
        '<div class="item-thumbnail"><a href="/archives/$id"><img data-src="https://pan.nekogal.top/f/x/$id.jpg"></a></div>'
        '<h2 class="item-heading"><a href="/archives/$id">游戏$id</a></h2>'
        '</posts>');
  }
  final nav = next == null
      ? '<nav class="navigation pagination"><span class="page-numbers current">1</span></nav>'
      : '<nav class="navigation pagination"><a class="next page-numbers" href="$next">下一页</a></nav>';
  return '<div class="posts-row ajaxpager">$items</div>$nav';
}

const _detailHtml = '''
<div class="single-head-cover"><div class="graphic single-cover">
  <img class="lazyload" data-src="https://pan.nekogal.top/f/x/cover.jpg">
  <h1 class="article-title">【PC游戏/机翻】制服女友3</h1>
  <div class="post-metas"><item class="meta-view">451</item></div>
</div></div>
<div class="article-header"><span title="2026年09月14日 20:56发布">x</span></div>
<div class="article-content"><div class="wp-posts-content"><p>简介。</p></div></div>
''';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.htmlByPath);
  final Map<String, String> htmlByPath;
  final List<String> requested = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requested.add(options.path);
    final html = htmlByPath[options.path] ?? '';
    return ResponseBody.fromString(html, 200, headers: {
      Headers.contentTypeHeader: ['text/plain; charset=utf-8'],
    });
  }
}

void main() {
  test('browse requests two source pages and returns 24', () async {
    final dio = Dio(BaseOptions(baseUrl: nekogalBaseUrl));
    final adapter = _FakeAdapter({
      '/archives/category/pcgame':
          _listPageHtml(12, next: '/archives/category/pcgame/page/2', base: 100),
      '/archives/category/pcgame/page/2':
          _listPageHtml(12, next: '/archives/category/pcgame/page/3', base: 200),
    });
    dio.httpClientAdapter = adapter;
    final source = NekogalSource(dio: dio);

    final list = await source.browse('pcgame', page: 1);
    expect(adapter.requested,
        ['/archives/category/pcgame', '/archives/category/pcgame/page/2']);
    expect(list.items, hasLength(24));
    expect(list.items.first.id, '100');
    expect(list.items.last.id, '211');
    expect(list.hasMore, isTrue);
  });

  test('detail requests /archives/<id> and parses fields', () async {
    final dio = Dio(BaseOptions(baseUrl: nekogalBaseUrl));
    final adapter = _FakeAdapter({'/archives/6661': _detailHtml});
    dio.httpClientAdapter = adapter;
    final source = NekogalSource(dio: dio);

    final detail = await source.detail('6661');
    expect(adapter.requested, ['/archives/6661']);
    expect(detail.game.title, '【PC游戏/机翻】制服女友3');
    expect(detail.sourceUrl, '$nekogalBaseUrl/archives/6661');
  });

  test('exposes identity and browse options', () {
    final source = NekogalSource(dio: Dio());
    expect(source.id, 'nekogal');
    expect(source.name, 'NekoGAL');
    expect(source.browseOptions.map((o) => o.key),
        ['pcgame', 'hhzy', 'srzy', 'pegame']);
    expect(source.browseOptions.first.label, 'PC资源');
  });
}
```

Run: `C:\flutter\bin\flutter.bat test test/core/game/nekogal_source_test.dart`
Expected: PASS（3 tests）。

### Step 4: 注册源

在 `lib/modules/game/game_providers.dart`：

1) import 加入：

```dart
import '../../core/game/nekogal_source.dart';
```

2) 把 manager 构造改为：

```dart
final gameSourceManagerProvider = Provider<GameSourceManager>(
  (ref) => GameSourceManager(sources: [GalgameZywzSource(), NekogalSource()]),
);
```

Run:
- `C:\flutter\bin\flutter.bat test test/core/game/nekogal_source_test.dart`
- `C:\flutter\bin\flutter.bat test test/modules/game/game_providers_test.dart`
- `C:\flutter\bin\flutter.bat test test/modules/game/game_home_test.dart`
Expected: 均 PASS。

### Step 5: 静态检查 + 提交

Run: `C:\flutter\bin\flutter.bat analyze`
Expected: `No issues found!`

```bash
git add lib/core/game/nekogal_source.dart lib/modules/game/game_providers.dart test/core/game/nekogal_parser_test.dart test/core/game/nekogal_source_test.dart
git commit -m "feat(game): add the nekogal second source"
```

---

## 手动验证（合并前，由用户执行）

在 Windows 上运行应用，进入「游戏」Tab：
1. 源 chip 出现「galgame大玩家」和「NekoGAL」。
2. 切到 NekoGAL：分区 chip 显示 PC资源 / 汉化资源 / 生肉资源 / 模拟器资源。
3. 各分区能加载、翻页（每页 24），封面正常显示（来自 `pan.nekogal.top`，无防盗链裂图）。
4. 点卡片进详情：标题、封面、简介段落、截图画廊正常；「在原站打开」跳转到 nekogal 详情页。

## 自查记录（Self-Review）

- **Spec 覆盖**：共享分页 → Task 1；图片请求头 → Task 2；nekogal 源/注册 → Task 3；测试散落各任务。
- **类型一致性**：`buildGamePage` 签名在 Task 1 定义、Task 3 使用；`GameSourcePage` 一致；`NekogalSource` 实现 `GameSource` 的 6 个成员；`GameBrowseOption` key 与 `_nekogalCategoryPaths` 一致。
- **占位符**：无 TBD/TODO；所有步骤给出完整代码与命令。
- **注意**：Task 1 会小改已评审的 `galgamezywz_source.dart`（`galgameZywzPageSize` 移除、browse 改用 helper），行为不变、由既有测试兜底。
