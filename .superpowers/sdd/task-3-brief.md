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

