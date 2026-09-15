# 游戏模块（首页浏览 / 详情展示）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 接入 game.galgamezywz.org，把主壳 index 3 的「即将推出」占位页替换为可浏览分区的游戏首页，并提供信息型详情页（含截图画廊与「在原站打开」外链）。

**Architecture:** 与动漫/漫画/轻小说模块同构：`lib/core/game/` 放 `GameSource` 抽象、数据模型与 `GalgameZywzSource`（dio + html 抓取解析）；`lib/modules/game/` 放 Riverpod providers 与 UI（`GameHomePage` / `GameDetailPage`）。解析为纯函数，便于 fixture 单测。

**Tech Stack:** Flutter (Dart 3.6)、flutter_riverpod、dio、html、cached_network_image、url_launcher（新增）。

## Global Constraints

- 平台：先在 Windows 实现；Android 后续。
- 单源：v1 仅 `game.galgamezywz.org`（id `galgamezywz`，名「galgame大玩家」）。
- 非目标：搜索、收藏、历史、网盘下载、播放、第二源（nekogal）、首页 Hero 轮播。
- 复用现有组件与依赖；唯一新增依赖 `url_launcher`。
- UI 文案用中文。
- 分支：在 `dev` 上开发；每个任务结束提交一次，commit 用 conventional commits。
- 解析函数保持纯函数（输入 HTML 字符串），网络层不打桩、靠手动运行验证。
- 测试命令：`flutter test <path>`；静态检查：`flutter analyze`。

---

## 文件结构

- `lib/core/game/models.dart`（新建）：`Game` / `GameBrowseOption` / `GameList` / `GameDetail`。
- `lib/core/game/game_source.dart`（新建）：`GameSource` 抽象 + `GameSourceManager`。
- `lib/core/game/galgamezywz_source.dart`（新建）：常量、解析纯函数、`GalgameZywzSource`。
- `lib/modules/game/game_providers.dart`（新建）：4 个 provider。
- `lib/modules/game/game_home.dart`（新建）：`GameCard` + `GameHomePage`。
- `lib/modules/game/game_detail_page.dart`（新建）：`GameDetailPage` + 截图查看器。
- `lib/shell/main_shell.dart`（修改）：占位页 → `GameHomePage`，删除 `_buildModulePlaceholder`。
- `pubspec.yaml`（修改）：新增 `url_launcher`。
- `test/core/game/models_test.dart`（新建）。
- `test/core/game/game_source_test.dart`（新建）。
- `test/core/game/galgamezywz_parser_test.dart`（新建）。
- `test/core/game/galgamezywz_source_test.dart`（新建）。
- `test/modules/game/game_providers_test.dart`（新建）。
- `test/modules/game/game_home_test.dart`（新建）。
- `test/modules/game/game_detail_page_test.dart`（新建）。

---

## Task 1: 游戏数据模型

**Files:**
- Create: `lib/core/game/models.dart`
- Test: `test/core/game/models_test.dart`

**Interfaces:**
- Consumes: 无。
- Produces: `Game`（字段 `id/title/coverUrl/summary/category/tags/publishedAt/views/extra`，`Game.fromJson`、`toJson`）、`GameBrowseOption(key,label)`、`GameList(items,page,hasMore)`、`GameDetail(game,size,platform,updatedAt,paragraphs,screenshots,sourceUrl)`。

- [ ] **Step 1: Write the failing test**

Create `test/core/game/models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/game/models.dart';

void main() {
  test('Game fromJson/toJson round-trips', () {
    final g = Game(
      id: '1207',
      title: '金辉恋曲四重奏',
      coverUrl: 'https://x/cover.jpg',
      summary: 'sum',
      category: '玩家热评游戏',
      tags: const ['汉化', 'PC'],
      publishedAt: DateTime.utc(2026, 9, 11),
      views: 4300,
      extra: const {'url': 'https://game.galgamezywz.org/game/1207'},
    );
    final back = Game.fromJson(g.toJson());
    expect(back.id, '1207');
    expect(back.title, '金辉恋曲四重奏');
    expect(back.coverUrl, 'https://x/cover.jpg');
    expect(back.summary, 'sum');
    expect(back.category, '玩家热评游戏');
    expect(back.tags, ['汉化', 'PC']);
    expect(back.publishedAt, DateTime.utc(2026, 9, 11));
    expect(back.views, 4300);
    expect(back.extra['url'], 'https://game.galgamezywz.org/game/1207');
  });

  test('Game.fromJson tolerates missing optional fields', () {
    final g = Game.fromJson(const {'id': '1', 'title': 'T'});
    expect(g.coverUrl, isNull);
    expect(g.summary, isNull);
    expect(g.category, isNull);
    expect(g.tags, isEmpty);
    expect(g.publishedAt, isNull);
    expect(g.views, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/game/models_test.dart`
Expected: FAIL（`Error: Couldn't resolve the package 'acgnhub/core/game/models.dart'` 或找不到 `Game`）。

- [ ] **Step 3: Write minimal implementation**

Create `lib/core/game/models.dart`:

```dart
List<String> _stringList(dynamic raw) {
  if (raw is List) {
    return raw
        .map((e) => e?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return const [];
}

class Game {
  final String id;
  final String title;
  final String? coverUrl;
  final String? summary;
  final String? category;
  final List<String> tags;
  final DateTime? publishedAt;
  final int? views;
  final Map<String, dynamic> extra;

  const Game({
    required this.id,
    required this.title,
    this.coverUrl,
    this.summary,
    this.category,
    this.tags = const [],
    this.publishedAt,
    this.views,
    this.extra = const {},
  });

  factory Game.fromJson(Map<String, dynamic> json) => Game(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        coverUrl: json['coverUrl']?.toString(),
        summary: json['summary']?.toString(),
        category: json['category']?.toString(),
        tags: _stringList(json['tags']),
        publishedAt: json['publishedAt'] == null
            ? null
            : DateTime.tryParse(json['publishedAt'].toString()),
        views: json['views'] is int
            ? json['views'] as int
            : int.tryParse('${json['views']}'),
        extra: (json['extra'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (coverUrl != null) 'coverUrl': coverUrl,
        if (summary != null) 'summary': summary,
        if (category != null) 'category': category,
        if (tags.isNotEmpty) 'tags': tags,
        if (publishedAt != null) 'publishedAt': publishedAt!.toIso8601String(),
        if (views != null) 'views': views,
        if (extra.isNotEmpty) 'extra': extra,
      };
}

class GameBrowseOption {
  final String key;
  final String label;
  const GameBrowseOption({required this.key, required this.label});
}

class GameList {
  final List<Game> items;
  final int page;
  final bool hasMore;
  const GameList({required this.items, required this.page, required this.hasMore});
}

class GameDetail {
  final Game game;
  final String? size;
  final String? platform;
  final DateTime? updatedAt;
  final List<String> paragraphs;
  final List<String> screenshots;
  final String sourceUrl;

  const GameDetail({
    required this.game,
    this.size,
    this.platform,
    this.updatedAt,
    this.paragraphs = const [],
    this.screenshots = const [],
    required this.sourceUrl,
  });
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/game/models_test.dart`
Expected: PASS（2 tests）。

- [ ] **Step 5: Commit**

```bash
git add lib/core/game/models.dart test/core/game/models_test.dart
git commit -m "feat(game): add game data models"
```

---

## Task 2: GameSource 抽象与管理器

**Files:**
- Create: `lib/core/game/game_source.dart`
- Test: `test/core/game/game_source_test.dart`

**Interfaces:**
- Consumes: `lib/core/game/models.dart`（Task 1）。
- Produces: `abstract class GameSource { String get id; String get name; String get baseUrl; List<GameBrowseOption> get browseOptions; Future<GameList> browse(String optionKey, {int page = 1}); Future<GameDetail> detail(String id); }` 与 `GameSourceManager({List<GameSource>? sources})`（`sources` / `register` / `byId`）。

- [ ] **Step 1: Write the failing test**

Create `test/core/game/game_source_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/game/game_source.dart';
import 'package:acgnhub/core/game/models.dart';

class _FakeSource implements GameSource {
  @override
  String get id => 'fake';
  @override
  String get name => 'Fake';
  @override
  String get baseUrl => 'https://fake';
  @override
  List<GameBrowseOption> get browseOptions =>
      const [GameBrowseOption(key: 'latest', label: '最近更新')];
  @override
  Future<GameList> browse(String optionKey, {int page = 1}) async =>
      GameList(items: const [], page: page, hasMore: false);
  @override
  Future<GameDetail> detail(String id) async =>
      GameDetail(game: Game(id: id, title: id), sourceUrl: 'https://fake/$id');
}

void main() {
  test('manager exposes registered sources', () {
    final m = GameSourceManager(sources: [_FakeSource()]);
    expect(m.sources.map((s) => s.id), ['fake']);
    expect(m.byId('fake')!.name, 'Fake');
    expect(m.byId('nope'), isNull);
  });

  test('manager rejects duplicate ids', () {
    final m = GameSourceManager(sources: [_FakeSource()]);
    expect(() => m.register(_FakeSource()), throwsArgumentError);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/game/game_source_test.dart`
Expected: FAIL（找不到 `GameSourceManager` / `GameSource`）。

- [ ] **Step 3: Write minimal implementation**

Create `lib/core/game/game_source.dart`:

```dart
import 'models.dart';

abstract class GameSource {
  String get id;
  String get name;
  String get baseUrl;

  /// 该源声明的浏览分区（首页顶部 chip）。
  List<GameBrowseOption> get browseOptions;

  /// 按分区选项分页拉取。
  Future<GameList> browse(String optionKey, {int page = 1});

  /// 详情。
  Future<GameDetail> detail(String id);
}

class GameSourceManager {
  GameSourceManager({List<GameSource>? sources}) {
    for (final s in sources ?? const <GameSource>[]) {
      register(s);
    }
  }

  final List<GameSource> _sources = [];

  List<GameSource> get sources => List.unmodifiable(_sources);

  void register(GameSource source) {
    if (_sources.any((s) => s.id == source.id)) {
      throw ArgumentError('duplicate game source id: ${source.id}');
    }
    _sources.add(source);
  }

  GameSource? byId(String id) {
    for (final s in _sources) {
      if (s.id == id) return s;
    }
    return null;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/game/game_source_test.dart`
Expected: PASS（2 tests）。

- [ ] **Step 5: Commit**

```bash
git add lib/core/game/game_source.dart test/core/game/game_source_test.dart
git commit -m "feat(game): add GameSource abstraction and manager"
```

---

## Task 3: galgamezywz 列表与分页解析

**Files:**
- Create: `lib/core/game/galgamezywz_source.dart`（本任务只含常量、辅助函数、列表/分页解析、路径函数）
- Test: `test/core/game/galgamezywz_parser_test.dart`

**Interfaces:**
- Consumes: `models.dart`（Task 1）。
- Produces:
  - `const String galgameZywzBaseUrl`、`galgameZywzUserAgent`、`Map<String,String> gameImageHeaders`
  - `String? gameIdFromHref(String? href)`
  - `int? parseCount(String raw)`
  - `String galgameZywzBrowsePath(String optionKey, int page)`
  - `List<Game> parseGameList(String html)`
  - `bool parseHasNextPage(String html, {required int itemCount})`

- [ ] **Step 1: Write the failing test**

Create `test/core/game/galgamezywz_parser_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/game/galgamezywz_source.dart';

const _listHtml = '''
<section class="container">
  <div class="posts-warp row">
    <div class="col">
      <article class="post-item item-grid">
        <div class="entry-media ratio ratio-3x2">
          <a class="media-img lazy bg-cover bg-center" href="https://game.galgamezywz.org/game/1207" data-bg="https://game.galgamezywz.org/wp-content/uploads/2025/03/cover.webp"></a>
        </div>
        <div class="entry-wrapper">
          <div class="entry-cat-dot"><a href="https://game.galgamezywz.org/lm/wanjiareping">玩家热评游戏</a></div>
          <h2 class="entry-title"><a href="https://game.galgamezywz.org/game/1207" title="金辉恋曲四重奏">金辉恋曲四重奏</a></h2>
          <div class="entry-desc">这是一段简介。</div>
          <div class="entry-meta">
            <span class="meta-date"><time class="pub-date" datetime="2026-09-11T10:21:10+08:00">4 天前</time></span>
            <span class="meta-likes">1</span>
            <span class="meta-fav">7</span>
            <span class="meta-views">4.3K</span>
            <span class="meta-price">0</span>
          </div>
        </div>
      </article>
    </div>
    <div class="col">
      <article class="post-item item-grid">
        <h2 class="entry-title"><a href="https://game.galgamezywz.org/lm/galgame">没有游戏链接的条目</a></h2>
      </article>
    </div>
  </div>
  <nav class="page-nav mt-4"><ul class="pagination">
    <li class="page-item disabled"><span class="page-link">1/171</span></li>
    <li class="page-item"><a class="page-link page-next" href="https://game.galgamezywz.org/page/2">下一页</a></li>
  </ul></nav>
</section>
''';

const _listNoNextHtml = '''
<section class="container">
  <div class="posts-warp row">
    <div class="col">
      <article class="post-item item-grid">
        <h2 class="entry-title"><a href="https://game.galgamezywz.org/game/9">最后一页</a></h2>
      </article>
    </div>
  </div>
  <nav class="page-nav"><ul class="pagination">
    <li class="page-item disabled"><span class="page-link">171/171</span></li>
  </ul></nav>
</section>
''';

void main() {
  test('gameIdFromHref extracts the numeric id', () {
    expect(gameIdFromHref('https://game.galgamezywz.org/game/1207'), '1207');
    expect(gameIdFromHref('/game/9'), '9');
    expect(gameIdFromHref('https://game.galgamezywz.org/lm/galgame'), isNull);
    expect(gameIdFromHref(null), isNull);
  });

  test('parseCount parses K/M suffixes and raw numbers', () {
    expect(parseCount('4.3K'), 4300);
    expect(parseCount('125.2K'), 125200);
    expect(parseCount('6.2K'), 6200);
    expect(parseCount('664'), 664);
    expect(parseCount('浏览热度: (4.3K)'), 4300);
    expect(parseCount(''), isNull);
  });

  test('galgameZywzBrowsePath maps options to paths', () {
    expect(galgameZywzBrowsePath('latest', 1), '/');
    expect(galgameZywzBrowsePath('latest', 3), '/page/3');
    expect(galgameZywzBrowsePath('galgame', 1), '/lm/galgame');
    expect(galgameZywzBrowsePath('galgame', 2), '/lm/galgame/page/2');
    expect(() => galgameZywzBrowsePath('nope', 1), throwsArgumentError);
  });

  test('parseGameList keeps items with a /game/<id> link and skips others', () {
    final items = parseGameList(_listHtml);
    expect(items, hasLength(1));
    expect(items.first.id, '1207');
    expect(items.first.title, '金辉恋曲四重奏');
    expect(items.first.coverUrl,
        'https://game.galgamezywz.org/wp-content/uploads/2025/03/cover.webp');
    expect(items.first.summary, '这是一段简介。');
    expect(items.first.category, '玩家热评游戏');
    expect(items.first.publishedAt, DateTime.parse('2026-09-11T10:21:10+08:00'));
    expect(items.first.views, 4300);
  });

  test('parseHasNextPage follows the next link, else the item-count fallback',
      () {
    expect(parseHasNextPage(_listHtml, itemCount: 1), isTrue);
    expect(parseHasNextPage(_listNoNextHtml, itemCount: 1), isFalse);
    expect(parseHasNextPage('<html></html>', itemCount: 12), isTrue);
    expect(parseHasNextPage('<html></html>', itemCount: 3), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/game/galgamezywz_parser_test.dart`
Expected: FAIL（找不到 `galgamezywz_source.dart`）。

- [ ] **Step 3: Write minimal implementation**

Create `lib/core/game/galgamezywz_source.dart`:

```dart
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'models.dart';

const String galgameZywzBaseUrl = 'https://game.galgamezywz.org';
const String galgameZywzUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

const Map<String, String> gameImageHeaders = {
  'Referer': '$galgameZywzBaseUrl/',
};

const Map<String, String> _categorySlugs = {
  'wanjiareping': 'wanjiareping',
  'galgame': 'galgame',
  'haoyoutuijian': 'haoyoutuijian',
  'wanjiazuiai': 'wanjiazuiai',
};

final RegExp _gameHref = RegExp(r'/game/(\d+)');

String? gameIdFromHref(String? href) {
  if (href == null) return null;
  return _gameHref.firstMatch(href)?.group(1);
}

String _absUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  if (url.startsWith('http')) return url;
  if (url.startsWith('//')) return 'https:$url';
  return url.startsWith('/') ? '$galgameZywzBaseUrl$url' : '$galgameZywzBaseUrl/$url';
}

String _textOf(dom.Element? el) => el?.text.trim() ?? '';

/// 解析预格式化计数（'6.2K' -> 6200，'1.2M' -> 1200000，'664' -> 664）。
int? parseCount(String raw) {
  final s = raw.replaceAll(RegExp(r'[^0-9KkMm.]'), '').trim();
  if (s.isEmpty) return null;
  final m = RegExp(r'^([0-9]+(?:\.[0-9]+)?)([KkMm]?)$').firstMatch(s);
  if (m == null) return null;
  final value = double.tryParse(m.group(1)!);
  if (value == null) return null;
  final suffix = m.group(2)?.toLowerCase();
  final factor = suffix == 'k' ? 1000 : (suffix == 'm' ? 1000000 : 1);
  return (value * factor).round();
}

/// 分区选项 -> 相对路径（相对 galgameZywzBaseUrl）。
String galgameZywzBrowsePath(String optionKey, int page) {
  if (optionKey == 'latest') {
    return page <= 1 ? '/' : '/page/$page';
  }
  final slug = _categorySlugs[optionKey];
  if (slug == null) {
    throw ArgumentError('unknown game browse option: $optionKey');
  }
  return page <= 1 ? '/lm/$slug' : '/lm/$slug/page/$page';
}

dom.Element? _firstPostsWarp(dom.Document doc) =>
    doc.querySelector('div.posts-warp');

/// 从列表容器向上找分页所在的 section.container / .home-widget。
dom.Element _paginationScope(dom.Element warp) {
  dom.Element? node = warp.parent;
  while (node != null) {
    if (node.classes.contains('home-widget')) return node;
    if (node.localName == 'section' && node.classes.contains('container')) {
      return node;
    }
    node = node.parent;
  }
  return warp;
}

Game? _gameFromItem(dom.Element item) {
  final titleA = item.querySelector('.entry-title a');
  final id = gameIdFromHref(titleA?.attributes['href']);
  if (titleA == null || id == null) return null;
  final media = item.querySelector('a.media-img');
  final cover = _absUrl(media?.attributes['data-bg'] ??
      media?.attributes['data-src'] ??
      media?.attributes['src']);
  final summary = _textOf(item.querySelector('.entry-desc'));
  final category = _textOf(item.querySelector('.entry-cat-dot a'));
  final dateRaw = item.querySelector('time.pub-date')?.attributes['datetime'];
  return Game(
    id: id,
    title: _textOf(titleA),
    coverUrl: cover.isEmpty ? null : cover,
    summary: summary.isEmpty ? null : summary,
    category: category.isEmpty ? null : category,
    publishedAt: dateRaw == null ? null : DateTime.tryParse(dateRaw),
    views: parseCount(_textOf(item.querySelector('.meta-views'))),
    extra: {'url': '$galgameZywzBaseUrl/game/$id'},
  );
}

List<Game> parseGameList(String html) {
  final doc = html_parser.parse(html);
  final scope = _firstPostsWarp(doc) ?? doc.documentElement;
  final out = <Game>[];
  if (scope == null) return out;
  for (final item in scope.querySelectorAll('article.post-item')) {
    final g = _gameFromItem(item);
    if (g != null) out.add(g);
  }
  return out;
}

bool parseHasNextPage(String html, {required int itemCount}) {
  final doc = html_parser.parse(html);
  final warp = _firstPostsWarp(doc);
  final scoped = warp == null ? null : _paginationScope(warp);
  final nav =
      (scoped ?? doc).querySelector('nav.page-nav') ?? doc.querySelector('nav.page-nav');
  if (nav != null) {
    return nav.querySelector('a.page-link.page-next') != null;
  }
  return itemCount >= 12;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/game/galgamezywz_parser_test.dart`
Expected: PASS（5 tests）。

- [ ] **Step 5: Commit**

```bash
git add lib/core/game/galgamezywz_source.dart test/core/game/galgamezywz_parser_test.dart
git commit -m "feat(game): parse galgamezywz listing and pagination"
```

---

## Task 4: galgamezywz 详情解析

**Files:**
- Modify: `lib/core/game/galgamezywz_source.dart`（追加详情解析）
- Test: `test/core/game/galgamezywz_parser_test.dart`（追加详情用例）

**Interfaces:**
- Consumes: Task 3 的辅助函数（`_absUrl` / `_textOf` / `parseCount` / `gameIdFromHref`）。
- Produces: `GameDetail parseGameDetail(String html, String sourceUrl)`。

- [ ] **Step 1: Write the failing test**

在 `test/core/game/galgamezywz_parser_test.dart` 末尾追加（`main()` 内）：

```dart
  test('parseGameDetail extracts meta, paragraphs, tags and screenshots', () {
    final detail = parseGameDetail(_detailHtml, '$galgameZywzBaseUrl/game/1207');
    expect(detail.game.id, '1207');
    expect(detail.game.title, '金辉恋曲四重奏');
    expect(detail.game.coverUrl,
        'https://game.galgamezywz.org/wp-content/uploads/cover.jpg');
    expect(detail.game.category, '玩家热评游戏');
    expect(detail.game.tags, ['汉化', 'PC']);
    expect(detail.game.views, 4300);
    expect(detail.game.publishedAt, DateTime.parse('2026-09-11'));
    expect(detail.updatedAt, DateTime.parse('2026-09-12'));
    expect(detail.size, '14.3GB');
    expect(detail.platform, 'PC+安卓直装');
    expect(detail.paragraphs, ['第一段简介。', '第二段简介。']);
    expect(detail.screenshots, [
      'https://game.galgamezywz.org/wp-content/uploads/1.jpg',
    ]);
    expect(detail.sourceUrl, '$galgameZywzBaseUrl/game/1207');
  });
```

并在文件顶部（`_listNoNextHtml` 之后）加入 fixture：

```dart
const _detailHtml = '''
<div class="archive-shop">
  <div class="img-box"><img class="lazy" src="https://game.galgamezywz.org/wp-content/uploads/cover.jpg"></div>
  <div class="info-box">
    <ul class="article-meta">
      <li>资源分类: <a href="https://game.galgamezywz.org/lm/wanjiareping">玩家热评游戏</a></li>
      <li>浏览热度: (4.3K)</li>
      <li>发布时间: 2026-09-11</li>
      <li>最近更新: 2026-09-12</li>
      <li>游戏大小: 14.3GB</li>
      <li>游戏平台: PC+安卓直装</li>
    </ul>
  </div>
</div>
<h1 class="post-title">金辉恋曲四重奏</h1>
<div class="entry-tags">
  <a rel="tag" href="https://game.galgamezywz.org/bq/hanhua">汉化</a>
  <a rel="tag" href="https://game.galgamezywz.org/bq/pc">PC</a>
</div>
<article class="post-content">
  <p>第一段简介。</p>
  <p>第二段简介。</p>
  <img src="https://game.galgamezywz.org/wp-content/uploads/1.jpg" class="aligncenter wp-image-1">
  <img src="https://game.galgamezywz.org/wp-content/uploads/1.jpg" class="aligncenter">
  <img src="data:image/gif;base64,AAAA">
</article>
''';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/game/galgamezywz_parser_test.dart`
Expected: FAIL（`parseGameDetail` 未定义）。

- [ ] **Step 3: Write minimal implementation**

在 `lib/core/game/galgamezywz_source.dart` 末尾追加：

```dart
String _valueAfterColon(String text) {
  final ascii = text.indexOf(':');
  final wide = text.indexOf('：');
  final cut = ascii >= 0 ? ascii : wide;
  if (cut < 0) return text.trim();
  return text.substring(cut + 1).trim();
}

DateTime? _dateAfterColon(String text) =>
    DateTime.tryParse(_valueAfterColon(text));

GameDetail parseGameDetail(String html, String sourceUrl) {
  final doc = html_parser.parse(html);
  final id = gameIdFromHref(sourceUrl) ?? '';
  final title = _textOf(doc.querySelector('h1.post-title'));
  final titleFallback = _textOf(doc.querySelector('.entry-title'));
  final img = doc.querySelector('.archive-shop .img-box img');
  final cover = _absUrl(img?.attributes['src'] ?? img?.attributes['data-src']);

  String? category;
  int? views;
  DateTime? publishedAt;
  DateTime? updatedAt;
  String? size;
  String? platform;
  for (final li
      in doc.querySelectorAll('.archive-shop .info-box .article-meta li')) {
    final text = _textOf(li);
    if (text.contains('资源分类')) {
      final a = _textOf(li.querySelector('a'));
      category = a.isNotEmpty ? a : _valueAfterColon(text);
    } else if (text.contains('浏览热度')) {
      views = parseCount(text);
    } else if (text.contains('发布时间')) {
      publishedAt = _dateAfterColon(text);
    } else if (text.contains('最近更新')) {
      updatedAt = _dateAfterColon(text);
    } else if (text.contains('游戏大小')) {
      size = _valueAfterColon(text);
    } else if (text.contains('游戏平台')) {
      platform = _valueAfterColon(text);
    }
  }

  final tags = <String>[
    for (final a in doc.querySelectorAll('.entry-tags a[rel="tag"]'))
      if (_textOf(a).isNotEmpty) _textOf(a),
  ];

  final paragraphs = <String>[];
  final screenshots = <String>[];
  final content = doc.querySelector('article.post-content');
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
      final src = _absUrl(im.attributes['src'] ?? im.attributes['data-src']);
      if (src.isEmpty || src.startsWith('data:')) continue;
      if (cover.isNotEmpty && src == cover) continue;
      if (seen.add(src)) screenshots.add(src);
    }
  }

  final game = Game(
    id: id,
    title: title.isNotEmpty ? title : titleFallback,
    coverUrl: cover.isEmpty ? null : cover,
    category: (category == null || category.isEmpty) ? null : category,
    tags: tags,
    publishedAt: publishedAt,
    views: views,
    extra: {'url': sourceUrl},
  );

  return GameDetail(
    game: game,
    size: (size == null || size.isEmpty) ? null : size,
    platform: (platform == null || platform.isEmpty) ? null : platform,
    updatedAt: updatedAt,
    paragraphs: paragraphs,
    screenshots: screenshots,
    sourceUrl: sourceUrl,
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/game/galgamezywz_parser_test.dart`
Expected: PASS（6 tests）。

- [ ] **Step 5: Commit**

```bash
git add lib/core/game/galgamezywz_source.dart test/core/game/galgamezywz_parser_test.dart
git commit -m "feat(game): parse galgamezywz detail page"
```

---

## Task 5: GalgameZywzSource 类（HTTP 接线）

**Files:**
- Modify: `lib/core/game/galgamezywz_source.dart`（追加 `GalgameZywzSource` 类与 dio import）
- Test: `test/core/game/galgamezywz_source_test.dart`

**Interfaces:**
- Consumes: Task 2 的 `GameSource`、Task 3/4 的解析函数。
- Produces: `class GalgameZywzSource implements GameSource { GalgameZywzSource({Dio? dio}); ... }`，`id='galgamezywz'`、`name='galgame大玩家'`、`browseOptions`（latest/wanjiareping/galgame/haoyoutuijian/wanjiazuiai）、`browse`、`detail`。

- [ ] **Step 1: Write the failing test**

Create `test/core/game/galgamezywz_source_test.dart`:

```dart
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/game/galgamezywz_source.dart';

const _listHtml = '''
<div class="posts-warp">
  <article class="post-item item-grid">
    <a class="media-img" href="/game/1207" data-bg="https://game.galgamezywz.org/wp-content/uploads/cover.jpg"></a>
    <h2 class="entry-title"><a href="/game/1207">金辉恋曲四重奏</a></h2>
    <div class="entry-meta"><span class="meta-views">4.3K</span></div>
  </article>
</div>
<nav class="page-nav"><ul class="pagination">
  <li class="page-item"><a class="page-link page-next" href="/page/2">下一页</a></li>
</ul></nav>
''';

const _detailHtml = '''
<div class="archive-shop">
  <div class="img-box"><img src="https://game.galgamezywz.org/wp-content/uploads/cover.jpg"></div>
  <div class="info-box"><ul class="article-meta">
    <li>资源分类: <a href="/lm/galgame">galgame资源推荐</a></li>
    <li>游戏大小: 14.3GB</li>
  </ul></div>
</div>
<h1 class="post-title">金辉恋曲四重奏</h1>
<article class="post-content"><p>简介。</p></article>
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
  test('browse requests the option path and parses the list', () async {
    final dio = Dio(BaseOptions(baseUrl: galgameZywzBaseUrl));
    final adapter = _FakeAdapter({'/lm/galgame': _listHtml});
    dio.httpClientAdapter = adapter;
    final source = GalgameZywzSource(dio: dio);

    final list = await source.browse('galgame', page: 1);
    expect(adapter.requested, ['/lm/galgame']);
    expect(list.items.single.id, '1207');
    expect(list.items.single.title, '金辉恋曲四重奏');
    expect(list.page, 1);
    expect(list.hasMore, isTrue);
  });

  test('detail requests /game/<id> and parses fields', () async {
    final dio = Dio(BaseOptions(baseUrl: galgameZywzBaseUrl));
    final adapter = _FakeAdapter({'/game/1207': _detailHtml});
    dio.httpClientAdapter = adapter;
    final source = GalgameZywzSource(dio: dio);

    final detail = await source.detail('1207');
    expect(adapter.requested, ['/game/1207']);
    expect(detail.game.title, '金辉恋曲四重奏');
    expect(detail.size, '14.3GB');
    expect(detail.sourceUrl, '$galgameZywzBaseUrl/game/1207');
  });

  test('exposes identity and browse options', () {
    final source = GalgameZywzSource(dio: Dio());
    expect(source.id, 'galgamezywz');
    expect(source.name, 'galgame大玩家');
    expect(source.browseOptions.map((o) => o.key),
        ['latest', 'wanjiareping', 'galgame', 'haoyoutuijian', 'wanjiazuiai']);
    expect(source.browseOptions.first.label, '最近更新');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/game/galgamezywz_source_test.dart`
Expected: FAIL（`GalgameZywzSource` 未定义）。

- [ ] **Step 3: Write minimal implementation**

在 `lib/core/game/galgamezywz_source.dart` 顶部加入：

```dart
import 'package:dio/dio.dart';
```

在文件末尾追加：

```dart
class GalgameZywzSource implements GameSource {
  GalgameZywzSource({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: galgameZywzBaseUrl,
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 20),
              headers: {
                'User-Agent': galgameZywzUserAgent,
                'Accept':
                    'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
                'Referer': '$galgameZywzBaseUrl/',
              },
            ));

  final Dio _dio;

  @override
  String get id => 'galgamezywz';

  @override
  String get name => 'galgame大玩家';

  @override
  String get baseUrl => galgameZywzBaseUrl;

  @override
  List<GameBrowseOption> get browseOptions => const [
        GameBrowseOption(key: 'latest', label: '最近更新'),
        GameBrowseOption(key: 'wanjiareping', label: '玩家热评'),
        GameBrowseOption(key: 'galgame', label: '资源推荐'),
        GameBrowseOption(key: 'haoyoutuijian', label: '好游推荐'),
        GameBrowseOption(key: 'wanjiazuiai', label: '玩家最爱'),
      ];

  @override
  Future<GameList> browse(String optionKey, {int page = 1}) async {
    final html = await _get(galgameZywzBrowsePath(optionKey, page));
    final items = parseGameList(html);
    final hasMore = parseHasNextPage(html, itemCount: items.length);
    return GameList(items: items, page: page, hasMore: hasMore);
  }

  @override
  Future<GameDetail> detail(String id) async {
    final html = await _get('/game/$id');
    return parseGameDetail(html, '$galgameZywzBaseUrl/game/$id');
  }

  Future<String> _get(String path) async {
    final res = await _dio.get<String>(
      path,
      options: Options(responseType: ResponseType.plain),
    );
    final data = res.data;
    if (res.statusCode != 200 || data == null) {
      throw Exception('galgamezywz 请求失败：$path (${res.statusCode})');
    }
    return data;
  }
}
```

并把顶部 import 区块补上 `game_source.dart`：

```dart
import 'game_source.dart';
```

（最终 `galgamezywz_source.dart` 顶部 import 顺序：`package:dio/dio.dart`、`package:html/dom.dart as dom`、`package:html/parser.dart as html_parser`、`game_source.dart`、`models.dart`。）

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/game/galgamezywz_source_test.dart`
Expected: PASS（3 tests）。

- [ ] **Step 5: Commit**

```bash
git add lib/core/game/galgamezywz_source.dart test/core/game/galgamezywz_source_test.dart
git commit -m "feat(game): add GalgameZywzSource with dio wiring"
```

---

## Task 6: Riverpod Providers

**Files:**
- Create: `lib/modules/game/game_providers.dart`
- Test: `test/modules/game/game_providers_test.dart`

**Interfaces:**
- Consumes: `GalgameZywzSource`（Task 5）、`GameSourceManager`（Task 2）、模型（Task 1）。
- Produces: `gameSourceManagerProvider`、`gameSourcesProvider`、`gameBrowseProvider((String,String,int))`、`gameDetailProvider((String,String))`。

- [ ] **Step 1: Write the failing test**

Create `test/modules/game/game_providers_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/game/game_source.dart';
import 'package:acgnhub/core/game/models.dart';
import 'package:acgnhub/modules/game/game_providers.dart';

class _FakeSource implements GameSource {
  @override
  String get id => 'fake';
  @override
  String get name => 'Fake';
  @override
  String get baseUrl => 'https://fake';
  @override
  List<GameBrowseOption> get browseOptions =>
      const [GameBrowseOption(key: 'latest', label: '最近更新')];
  @override
  Future<GameList> browse(String optionKey, {int page = 1}) async =>
      GameList(
        items: [Game(id: '$optionKey-$page', title: '游戏$optionKey')],
        page: page,
        hasMore: false,
      );
  @override
  Future<GameDetail> detail(String id) async => GameDetail(
        game: Game(id: id, title: '游戏$id'),
        sourceUrl: 'https://fake/game/$id',
      );
}

ProviderContainer _container() => ProviderContainer(overrides: [
      gameSourceManagerProvider
          .overrideWithValue(GameSourceManager(sources: [_FakeSource()])),
    ]);

void main() {
  test('gameBrowseProvider delegates to the registered source', () async {
    final container = _container();
    addTearDown(container.dispose);
    final list =
        await container.read(gameBrowseProvider(('fake', 'latest', 2)).future);
    expect(list.page, 2);
    expect(list.items.single.title, '游戏latest');
  });

  test('gameDetailProvider delegates to the registered source', () async {
    final container = _container();
    addTearDown(container.dispose);
    final detail = await container.read(gameDetailProvider(('fake', '1')).future);
    expect(detail.game.id, '1');
    expect(detail.sourceUrl, 'https://fake/game/1');
  });

  test('unknown source id throws', () async {
    final container = _container();
    addTearDown(container.dispose);
    expect(
      container.read(gameBrowseProvider(('nope', 'latest', 1)).future),
      throwsStateError,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/modules/game/game_providers_test.dart`
Expected: FAIL（找不到 `game_providers.dart`）。

- [ ] **Step 3: Write minimal implementation**

Create `lib/modules/game/game_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/game/galgamezywz_source.dart';
import '../../core/game/game_source.dart';
import '../../core/game/models.dart';

final gameSourceManagerProvider = Provider<GameSourceManager>(
  (ref) => GameSourceManager(sources: [GalgameZywzSource()]),
);

final gameSourcesProvider = Provider<List<GameSource>>(
  (ref) => ref.watch(gameSourceManagerProvider).sources,
);

final gameBrowseProvider =
    FutureProvider.family<GameList, (String, String, int)>((ref, key) async {
  final (sourceId, optionKey, page) = key;
  final source = ref.watch(gameSourceManagerProvider).byId(sourceId);
  if (source == null) throw StateError('game source $sourceId not found');
  return source.browse(optionKey, page: page);
});

final gameDetailProvider =
    FutureProvider.family<GameDetail, (String, String)>((ref, key) async {
  final (sourceId, gameId) = key;
  final source = ref.watch(gameSourceManagerProvider).byId(sourceId);
  if (source == null) throw StateError('game source $sourceId not found');
  return source.detail(gameId);
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/modules/game/game_providers_test.dart`
Expected: PASS（3 tests）。

- [ ] **Step 5: Commit**

```bash
git add lib/modules/game/game_providers.dart test/modules/game/game_providers_test.dart
git commit -m "feat(game): add game Riverpod providers"
```

---

## Task 7: 首页 UI（GameCard + GameHomePage）

**Files:**
- Create: `lib/modules/game/game_home.dart`
- Test: `test/modules/game/game_home_test.dart`

**Interfaces:**
- Consumes: `gameSourcesProvider` / `gameBrowseProvider`（Task 6）、`GameCard` 用到的 `gameImageHeaders`（Task 3）、`ChipBar` / `ShimmerLoader` / `EmptyState` / `noTransitionRoute`。
- Produces: `class GameCard extends StatelessWidget { GameCard({required Game game, VoidCallback? onTap}) }`、`class GameHomePage extends ConsumerStatefulWidget { const GameHomePage({super.key}) }`。

- [ ] **Step 1: Write the failing test**

Create `test/modules/game/game_home_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/game/game_source.dart';
import 'package:acgnhub/core/game/models.dart';
import 'package:acgnhub/modules/game/game_home.dart';
import 'package:acgnhub/modules/game/game_providers.dart';

class _FakeSource implements GameSource {
  @override
  String get id => 'galgamezywz';
  @override
  String get name => 'galgame大玩家';
  @override
  String get baseUrl => 'https://fake';
  @override
  List<GameBrowseOption> get browseOptions => const [
        GameBrowseOption(key: 'latest', label: '最近更新'),
        GameBrowseOption(key: 'wanjiareping', label: '玩家热评'),
      ];
  @override
  Future<GameList> browse(String optionKey, {int page = 1}) async => GameList(
        items: [Game(id: '$optionKey-$page', title: '游戏$optionKey$page')],
        page: page,
        hasMore: optionKey == 'latest' && page == 1,
      );
  @override
  Future<GameDetail> detail(String id) async =>
      GameDetail(game: Game(id: id, title: id), sourceUrl: 'https://fake/$id');
}

void main() {
  testWidgets('renders source/section chips, grid and pager', (tester) async {
    final container = ProviderContainer(overrides: [
      gameSourceManagerProvider
          .overrideWithValue(GameSourceManager(sources: [_FakeSource()])),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: GameHomePage())),
    ));
    await tester.pumpAndSettle();

    expect(find.text('galgame大玩家'), findsOneWidget);
    expect(find.text('最近更新'), findsOneWidget);
    expect(find.text('玩家热评'), findsOneWidget);
    expect(find.text('游戏latest1'), findsOneWidget);
    expect(find.text('第 1 页'), findsOneWidget);

    await tester.tap(find.byTooltip('下一页'));
    await tester.pumpAndSettle();

    expect(find.text('第 2 页'), findsOneWidget);
    expect(find.text('游戏latest2'), findsOneWidget);
    // 第 2 页 hasMore=false → 下一页禁用
    final next = tester.widget<IconButton>(find.byTooltip('下一页'));
    expect(next.onPressed, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/modules/game/game_home_test.dart`
Expected: FAIL（找不到 `game_home.dart`）。

- [ ] **Step 3: Write minimal implementation**

Create `lib/modules/game/game_home.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/game/galgamezywz_source.dart';
import '../../core/game/game_source.dart';
import '../../core/game/models.dart';
import '../../core/widgets/chip_bar.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../core/widgets/smooth_route.dart';
import 'game_detail_page.dart';
import 'game_providers.dart';

const _accent = Color(0xFF007AFF);
const _muted = Color(0xFF5A5A5F);
const _fg = Color(0xFF1C1C1E);

class GameCard extends StatelessWidget {
  final Game game;
  final VoidCallback? onTap;
  const GameCard({super.key, required this.game, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: game.coverUrl != null && game.coverUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: game.coverUrl!,
                      fit: BoxFit.cover,
                      memCacheWidth: 400,
                      fadeInDuration: Duration.zero,
                      httpHeaders: gameImageHeaders,
                      placeholder: (_, __) => _placeholder(),
                      errorWidget: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 38,
            child: Text(
              game.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                  color: _fg),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    final hash = game.title.hashCode.abs();
    const bg = [
      Color(0xFFF3E5F5),
      Color(0xFFEDE7F6),
      Color(0xFFE8EAF6),
      Color(0xFFE0F2F1),
    ];
    return Container(
      color: bg[hash % bg.length],
      child: Center(
        child: Text(
          game.title.isEmpty ? '游' : game.title.characters.first,
          style: TextStyle(
              color: _accent.withValues(alpha: 0.2),
              fontSize: 28,
              fontWeight: FontWeight.w400),
        ),
      ),
    );
  }
}

class GameHomePage extends ConsumerStatefulWidget {
  const GameHomePage({super.key});

  @override
  ConsumerState<GameHomePage> createState() => _GameHomePageState();
}

class _GameHomePageState extends ConsumerState<GameHomePage> {
  String _sourceId = 'galgamezywz';
  int _optionIndex = 0;
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(gameSourcesProvider);
    final source = ref.watch(gameSourceManagerProvider).byId(_sourceId);
    final options = source?.browseOptions ?? const <GameBrowseOption>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        _sourceChips(sources),
        _sectionChips(options),
        Expanded(child: _body(options)),
      ],
    );
  }

  Widget _sourceChips(List<GameSource> sources) {
    if (sources.isEmpty) return const SizedBox.shrink();
    final labels = [for (final s in sources) s.name];
    final index = sources.indexWhere((s) => s.id == _sourceId);
    return ChipBar(
      labels: labels,
      selectedIndex: index < 0 ? 0 : index,
      onSelected: (i) => setState(() {
        _sourceId = sources[i].id;
        _optionIndex = 0;
        _page = 1;
      }),
    );
  }

  Widget _sectionChips(List<GameBrowseOption> options) {
    final labels = [for (final o in options) o.label];
    if (labels.isEmpty) return const SizedBox.shrink();
    return ChipBar(
      labels: labels,
      selectedIndex: _optionIndex.clamp(0, labels.length - 1),
      onSelected: (i) => setState(() {
        _optionIndex = i;
        _page = 1;
      }),
    );
  }

  Widget _body(List<GameBrowseOption> options) {
    if (options.isEmpty) {
      return const EmptyState(icon: Icons.games_rounded, message: '暂无内容');
    }
    final option = options[_optionIndex.clamp(0, options.length - 1)];
    final key = (_sourceId, option.key, _page);
    final async = ref.watch(gameBrowseProvider(key));
    return async.when(
      loading: () => const ShimmerLoader(
          crossAxisCount: 6,
          itemCount: 12,
          aspectRatio: 0.58,
          padding: EdgeInsets.fromLTRB(16, 8, 16, 24)),
      error: (_, __) => EmptyState(
        icon: Icons.cloud_off_rounded,
        message: '加载失败',
        actionLabel: '重试',
        onAction: () => ref.invalidate(gameBrowseProvider(key)),
      ),
      data: (list) => Column(
        children: [
          Expanded(child: _grid(list.items)),
          _pager(list.hasMore),
        ],
      ),
    );
  }

  Widget _pager(bool hasMore) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: '上一页',
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: _page > 1 ? () => setState(() => _page--) : null,
          ),
          const SizedBox(width: 16),
          Text('第 $_page 页',
              style: const TextStyle(fontSize: 13, color: _muted)),
          const SizedBox(width: 16),
          IconButton(
            tooltip: '下一页',
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: hasMore ? () => setState(() => _page++) : null,
          ),
        ],
      ),
    );
  }

  Widget _grid(List<Game> items) {
    if (items.isEmpty) {
      return const EmptyState(icon: Icons.games_rounded, message: '暂无内容');
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          mainAxisSpacing: 20,
          crossAxisSpacing: 16,
          childAspectRatio: 0.58),
      itemCount: items.length,
      itemBuilder: (_, i) => GameCard(
        game: items[i],
        onTap: () => Navigator.push(
          context,
          noTransitionRoute(GameDetailPage(
            sourceKey: _sourceId,
            gameId: items[i].id,
            title: items[i].title,
            cover: items[i].coverUrl,
          )),
        ),
      ),
    );
  }
}
```

> 注：`game_detail_page.dart` 在本任务尚未创建。为避免 Task 7 无法编译，先在 `lib/modules/game/game_detail_page.dart` 放一个最小占位（Task 8 会整体替换）：

```dart
import 'package:flutter/material.dart';

class GameDetailPage extends StatelessWidget {
  final String sourceKey;
  final String gameId;
  final String title;
  final String? cover;
  const GameDetailPage({
    super.key,
    required this.sourceKey,
    required this.gameId,
    required this.title,
    this.cover,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/modules/game/game_home_test.dart`
Expected: PASS（1 test）。

- [ ] **Step 5: Commit**

```bash
git add lib/modules/game/game_home.dart lib/modules/game/game_detail_page.dart test/modules/game/game_home_test.dart
git commit -m "feat(game): add game home page with cards and paging"
```

---

## Task 8: 详情页 UI（含 url_launcher）

**Files:**
- Modify: `pubspec.yaml`（新增 `url_launcher`）
- Modify: `lib/modules/game/game_detail_page.dart`（整体替换 Task 7 的占位）
- Test: `test/modules/game/game_detail_page_test.dart`

**Interfaces:**
- Consumes: `gameDetailProvider`（Task 6）、`gameImageHeaders`（Task 3）、`EmptyState` / `ShimmerLoader` / `WindowControls`。
- Produces: `class GameDetailPage extends ConsumerWidget { GameDetailPage({required String sourceKey, required String gameId, required String title, String? cover}) }`。

- [ ] **Step 1: 新增依赖并拉取**

在 `pubspec.yaml` 的 `dependencies` 中（`pointycastle: ^3.9.1` 之后）加入：

```yaml
  url_launcher: ^6.3.1
```

Run: `flutter pub get`
Expected: 成功解析并写入 `pubspec.lock`。

- [ ] **Step 2: Write the failing test**

Create `test/modules/game/game_detail_page_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/game/models.dart';
import 'package:acgnhub/modules/game/game_detail_page.dart';
import 'package:acgnhub/modules/game/game_providers.dart';

void main() {
  testWidgets('renders title, meta, tags, paragraphs and source button',
      (tester) async {
    final detail = GameDetail(
      game: Game(
        id: '1207',
        title: '金辉恋曲四重奏',
        category: '玩家热评游戏',
        tags: const ['汉化', 'PC'],
        publishedAt: DateTime(2026, 9, 11),
        views: 4300,
      ),
      size: '14.3GB',
      platform: 'PC+安卓直装',
      updatedAt: DateTime(2026, 9, 12),
      paragraphs: const ['第一段简介。', '第二段简介。'],
      sourceUrl: 'https://game.galgamezywz.org/game/1207',
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        gameDetailProvider(('galgamezywz', '1207'))
            .overrideWith((ref) async => detail),
      ],
      child: const MaterialApp(
        home: GameDetailPage(
            sourceKey: 'galgamezywz', gameId: '1207', title: '金辉恋曲四重奏'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('金辉恋曲四重奏'), findsWidgets);
    expect(find.text('玩家热评游戏'), findsOneWidget);
    expect(find.text('汉化'), findsOneWidget);
    expect(find.text('PC'), findsOneWidget);
    expect(find.text('14.3GB'), findsOneWidget);
    expect(find.text('PC+安卓直装'), findsOneWidget);
    expect(find.text('第一段简介。'), findsOneWidget);
    expect(find.text('第二段简介。'), findsOneWidget);
    expect(find.text('简介'), findsOneWidget);
    expect(find.byTooltip('在原站打开'), findsOneWidget);
    expect(find.text('数据来源 game.galgamezywz.org'), findsOneWidget);
  });

  testWidgets('shows a retry action on error', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        gameDetailProvider(('galgamezywz', '404'))
            .overrideWith((ref) async => throw Exception('boom')),
      ],
      child: const MaterialApp(
        home: GameDetailPage(
            sourceKey: 'galgamezywz', gameId: '404', title: '加载失败'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('加载失败'), findsWidgets);
    expect(find.text('重试'), findsOneWidget);
  });
}
```

> 说明：用例刻意让 `coverUrl` 为空、`screenshots` 为空，避免在测试环境触发网络图片加载（`CachedNetworkImage`）。截图画廊的数据由 Task 3/4 的解析单测覆盖，画廊渲染手动验证。

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/modules/game/game_detail_page_test.dart`
Expected: FAIL（占位页没有标题/简介/按钮）。

- [ ] **Step 4: Write the implementation**

整体替换 `lib/modules/game/game_detail_page.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/game/galgamezywz_source.dart';
import '../../core/game/models.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../core/widgets/window_controls.dart';
import 'game_providers.dart';

const _accent = Color(0xFF007AFF);
const _muted = Color(0xFF5A5A5F);
const _fg = Color(0xFF1C1C1E);

class GameDetailPage extends ConsumerWidget {
  final String sourceKey;
  final String gameId;
  final String title;
  final String? cover;

  const GameDetailPage({
    super.key,
    required this.sourceKey,
    required this.gameId,
    required this.title,
    this.cover,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (sourceKey, gameId);
    final async = ref.watch(gameDetailProvider(key));
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Column(
        children: [
          _header(context, async.valueOrNull),
          Expanded(
            child: async.when(
              loading: () => const ShimmerLoader(
                  crossAxisCount: 6,
                  itemCount: 12,
                  aspectRatio: 0.58,
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 24)),
              error: (_, __) => EmptyState(
                icon: Icons.cloud_off_rounded,
                message: '加载失败',
                actionLabel: '重试',
                onAction: () => ref.invalidate(gameDetailProvider(key)),
              ),
              data: (detail) => _content(context, detail),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, GameDetail? detail) {
    return DragToMoveArea(
      child: Container(
        height: 48,
        padding: const EdgeInsets.only(left: 4),
        decoration: const BoxDecoration(
          color: Color(0xFFFFFFFF),
          border:
              Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              color: _fg,
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: _fg),
              ),
            ),
            IconButton(
              tooltip: '在原站打开',
              icon: const Icon(Icons.open_in_new_rounded, size: 20),
              color: _muted,
              onPressed: detail == null
                  ? null
                  : () => _openSource(detail.sourceUrl),
            ),
            const WindowControls(),
          ],
        ),
      ),
    );
  }

  Future<void> _openSource(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _content(BuildContext context, GameDetail detail) {
    final game = detail.game;
    final coverUrl = (game.coverUrl?.isNotEmpty ?? false)
        ? game.coverUrl
        : ((cover?.isNotEmpty ?? false) ? cover : null);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _infoCard(game, coverUrl, detail),
        if (detail.paragraphs.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionTitle('简介'),
          const SizedBox(height: 8),
          for (final p in detail.paragraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(p,
                  style: const TextStyle(fontSize: 13, height: 1.6, color: _fg)),
            ),
        ],
        if (detail.screenshots.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionTitle('截图'),
          const SizedBox(height: 8),
          _gallery(context, detail.screenshots),
        ],
        const SizedBox(height: 20),
        const Text('数据来源 game.galgamezywz.org',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: _muted)),
      ],
    );
  }

  Widget _infoCard(Game game, String? coverUrl, GameDetail detail) {
    final meta = <(String, String)>[
      if (game.publishedAt != null) ('发布时间', _formatDate(game.publishedAt!)),
      if (detail.updatedAt != null) ('最近更新', _formatDate(detail.updatedAt!)),
      if (detail.size != null && detail.size!.isNotEmpty)
        ('游戏大小', detail.size!),
      if (detail.platform != null && detail.platform!.isNotEmpty)
        ('游戏平台', detail.platform!),
      if (game.views != null) ('浏览热度', _formatCount(game.views!)),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(width: 100, height: 132, child: _cover(coverUrl)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(game.title,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: _fg)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (game.category != null && game.category!.isNotEmpty)
                          _tag(game.category!),
                        for (final t in game.tags) _tag(t),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final (label, value) in meta)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                        width: 72,
                        child: Text(label,
                            style: const TextStyle(fontSize: 12, color: _muted))),
                    Expanded(
                        child: Text(value,
                            style: const TextStyle(fontSize: 12, color: _fg))),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _gallery(BuildContext context, List<String> urls) {
    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => _ImageViewerPage(urls: urls, initialIndex: i)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 200,
              height: 130,
              child: CachedNetworkImage(
                imageUrl: urls[i],
                fit: BoxFit.cover,
                httpHeaders: gameImageHeaders,
                placeholder: (_, __) => Container(color: const Color(0xFFE5E5EA)),
                errorWidget: (_, __, ___) =>
                    Container(color: const Color(0xFFE5E5EA)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(text,
      style: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600, color: _fg));

  Widget _tag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: const Color(0xFFE8F0FE),
            borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11, color: _accent, fontWeight: FontWeight.w500)),
      );

  Widget _cover(String? url) {
    if (url == null || url.isEmpty) {
      return Container(color: const Color(0xFFE8EAF6));
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: 300,
      httpHeaders: gameImageHeaders,
      placeholder: (_, __) => Container(color: const Color(0xFFE8EAF6)),
      errorWidget: (_, __, ___) => Container(color: const Color(0xFFE8EAF6)),
    );
  }

  String _formatDate(DateTime d) {
    final l = d.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-'
        '${l.day.toString().padLeft(2, '0')}';
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _ImageViewerPage extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  const _ImageViewerPage({required this.urls, required this.initialIndex});

  @override
  State<_ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<_ImageViewerPage> {
  late final PageController _ctrl;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _ctrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _ctrl,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: widget.urls[i],
                  fit: BoxFit.contain,
                  httpHeaders: gameImageHeaders,
                  placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(color: Colors.white54)),
                  errorWidget: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: Colors.white38, size: 48)),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          if (widget.urls.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Text('${_index + 1} / ${widget.urls.length}',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/modules/game/game_detail_page_test.dart`
Expected: PASS（2 tests）。

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/modules/game/game_detail_page.dart test/modules/game/game_detail_page_test.dart
git commit -m "feat(game): add game detail page with gallery and source link"
```

---

## Task 9: 接入主壳

**Files:**
- Modify: `lib/shell/main_shell.dart`
- Test: 复用 `test/shell/main_shell_test.dart`（回归）

**Interfaces:**
- Consumes: `GameHomePage`（Task 7）。
- Produces: 主壳 index 3 渲染 `GameHomePage`；删除未使用的 `_buildModulePlaceholder`。

- [ ] **Step 1: 修改主壳**

在 `lib/shell/main_shell.dart`：

1. import 区加入（在 `import '../modules/novel/novel_search.dart';` 之后）：

```dart
import '../modules/game/game_home.dart';
```

2. 将 `_pages` 的第 4 项由占位改为 `GameHomePage`：

```dart
  final _pages = <Widget>[
    const AnimeHomePage(),
    const ComicHomePage(),
    const NovelHomePage(),
    const GameHomePage(),
  ];
```

3. 删除整个 `_buildModulePlaceholder(...)` 静态方法（第 39-73 行那一段），因为不再有调用点。

- [ ] **Step 2: 运行回归测试**

Run: `flutter test test/shell/main_shell_test.dart`
Expected: PASS（1 test）。若失败，检查 `_buildModulePlaceholder` 是否已删除、`GameHomePage` 是否 import。

- [ ] **Step 3: 静态检查**

Run: `flutter analyze`
Expected: `No issues found!`（若提示 `_buildModulePlaceholder` 未使用，说明第 3 步未删干净）。

- [ ] **Step 4: 全量测试**

Run: `flutter test`
Expected: 全部 PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/shell/main_shell.dart
git commit -m "feat(shell): mount the game home page"
```

---

## 手动验证（实现完成后、提 PR 前）

在 Windows 上 `flutter run -d windows`，进入「游戏」Tab：

1. 首页默认「最近更新」有封面网格；切换「玩家热评 / 资源推荐 / 好游推荐 / 玩家最爱」分区能加载不同内容。
2. 「下一页」可用并翻到第 2 页；末页时「下一页」禁用。
3. 点任一卡片进入详情页：封面、标题、分类/标签、发布日期/大小/平台、简介段落、截图画廊均正常。
4. 点截图能全屏放大（可缩放、左右滑动）。
5. 点右上「在原站打开」用系统浏览器打开对应 `game.galgamezywz.org/game/<id>` 页面。
6. 断开网络后重进，显示「加载失败 / 重试」。

---

## 自查记录（Self-Review）

- **Spec 覆盖**：模型→Task 1；`GameSource`→Task 2；列表/分页解析→Task 3；详情解析→Task 4；`GalgameZywzSource`→Task 5；providers→Task 6；首页→Task 7；详情页 + url_launcher→Task 8；主壳接入→Task 9。错误处理与测试散落各任务并有回归步骤。
- **类型一致性**：`GameDetail` 字段（`size/platform/updatedAt/paragraphs/screenshots/sourceUrl`）在 Task 1 定义，Task 4 构造、Task 8 消费一致；`parseHasNextPage(html, {required itemCount})` 在 Task 3 定义并被 Task 5 调用；`gameBrowseProvider` 键类型 `(String,String,int)` 在 Task 6/7 一致。
- **占位符**：无 TBD/TODO；每个代码步骤均给出完整代码与命令。
- **偏差说明**：详情页 widget 测试不含截图画廊断言（避免测试环境加载网络图片），画廊数据由 Task 3/4 解析单测覆盖、渲染手动验证。
