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

