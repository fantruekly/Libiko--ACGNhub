### Task 3: linovelib 纯解析函数

**Files:**
- Create: `lib/core/novel/linovelib_source.dart`（本任务只放解析函数与常量）
- Test: `test/core/novel/linovelib_parser_test.dart`

**Interfaces:**
- Consumes: `models.dart`（Task 1）。
- Produces（顶层函数，均定义在 `lib/core/novel/linovelib_source.dart`）：
  - `String? novelIdFromHref(String? href)` — 从 `/novel/<id>.html` 取 `<id>`；不匹配返回 `null`。
  - `List<Novel> parseBookList(String html)` — 解析首页/文库的 `div.lists ul li`（只取含 `a.title` 的项）。
  - `List<Novel> parseRankRows(String html)` — 解析排行 `div.rank_i_li`。
  - `List<NovelSection> parseHome(String html)` — 解析 `div.tab-lists` 为带标题的书单。
  - `bool hasNextPage(String html)` — 页面存在「下一页」链接时为 true。

- [ ] **Step 1: 写失败测试（含真实精简 fixture）**

`test/core/novel/linovelib_parser_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/novel/linovelib_source.dart';

const _bookListHtml = '''
<div class="tab-lists qtbg_color">
  <div class="top-title clearfix"><div class="title fl">强推榜</div></div>
  <div class="lists"><ul>
    <li class="postion-right">
      <div class="imgbox fl"><a href="/novel/2059.html"><img src="x.svg" data-original="https://www.linovelib.com/files/article/image/2/2059/2059s.jpg" alt="安达与岛村"></a></div>
      <a class="title" href="/novel/2059.html" target="_blank" title="">安达与岛村</a>
      <a class="author" href="/authorarticle/入间人间.html" title="入间人间">入间人间</a>
      <a class="cate" href="/wenku/dengekibunko/1.html" title="">[电击文库]</a>
    </li>
    <li><a class="author2" href="/authorarticle/x.html">某人</a><a href="/novel/4649.html" title="玩乐关系">玩乐关系</a></li>
  </ul></div>
</div>
''';

const _rankHtml = '''
<div class="rank_i_lists">
  <div class="borderB_c_dsh rank_i_li rank_i_li1 clearfix">
    <div class="rank_i_num fr">1</div>
    <div class="rank_i_bname fr">
      <a href="/novel/5340.html" class="rank_i_l_a_book">不相容的異種族妻子們</a>
      <a href="/authorarticle/x.html" class="rank_i_l_a_author">이만두</a>
      <a href="/wenku/0/1.html" class="rank_i_l_a_category">[novelpia]</a>
      <div class="rank_i_l_font">115人推荐</div>
    </div>
    <div class="rank_i_bcount fl"><a href="/novel/5340.html"><img data-original="https://www.linovelib.com/files/article/image/5/5340/5340s.jpg"></a></div>
  </div>
</div>
''';

const _nextPageHtml = '<div class="pagination"><a href="/top/monthvote/2.html">下一页</a></div>';

void main() {
  test('novelIdFromHref extracts id', () {
    expect(novelIdFromHref('/novel/2059.html'), '2059');
    expect(novelIdFromHref('https://www.linovelib.com/novel/5340.html'), '5340');
    expect(novelIdFromHref('/wenku/dengekibunko/1.html'), isNull);
    expect(novelIdFromHref(null), isNull);
  });

  test('parseBookList keeps only book entries with a.title', () {
    final items = parseBookList(_bookListHtml);
    expect(items, hasLength(1));
    expect(items.first.id, '2059');
    expect(items.first.title, '安达与岛村');
    expect(items.first.author, '入间人间');
    expect(items.first.coverUrl, 'https://www.linovelib.com/files/article/image/2/2059/2059s.jpg');
    expect(items.first.tags, ['电击文库']);
  });

  test('parseHome returns titled sections', () {
    final sections = parseHome(_bookListHtml);
    expect(sections, hasLength(1));
    expect(sections.first.title, '强推榜');
    expect(sections.first.items.single.title, '安达与岛村');
  });

  test('parseRankRows parses rank rows', () {
    final items = parseRankRows(_rankHtml);
    expect(items, hasLength(1));
    expect(items.first.id, '5340');
    expect(items.first.title, '不相容的異種族妻子們');
    expect(items.first.author, '이만두');
    expect(items.first.coverUrl, 'https://www.linovelib.com/files/article/image/5/5340/5340s.jpg');
    expect(items.first.extra['rank'], 1);
  });

  test('hasNextPage detects the next link', () {
    expect(hasNextPage(_nextPageHtml), isTrue);
    expect(hasNextPage(_bookListHtml), isFalse);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_parser_test.dart`
Expected: FAIL（`linovelib_source.dart` 不存在）

- [ ] **Step 3: 实现解析函数**

在 `lib/core/novel/linovelib_source.dart` 顶部写：

```dart
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'models.dart';

const String linovelibBaseUrl = 'https://www.linovelib.com';
const String linovelibUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

final RegExp _novelHref = RegExp(r'/novel/(\d+)\.html');

String? novelIdFromHref(String? href) {
  if (href == null) return null;
  final m = _novelHref.firstMatch(href);
  return m?.group(1);
}

String _absUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  if (url.startsWith('http')) return url;
  if (url.startsWith('//')) return 'https:$url';
  return url.startsWith('/') ? '$linovelibBaseUrl$url' : '$linovelibBaseUrl/$url';
}

String _textOf(dom.Element? el) => el?.text.trim() ?? '';

Novel? _novelFromBookLi(dom.Element li) {
  final titleA = li.querySelector('a.title');
  final id = novelIdFromHref(titleA?.attributes['href']);
  if (titleA == null || id == null) return null;
  final img = li.querySelector('div.imgbox img');
  final cover = _absUrl(img?.attributes['data-original'] ?? img?.attributes['src']);
  final author = _textOf(li.querySelector('a.author'));
  final cate = _textOf(li.querySelector('a.cate'));
  final tags = <String>[];
  if (cate.isNotEmpty) {
    tags.add(cate.replaceAll('[', '').replaceAll(']', ''));
  }
  return Novel(
    id: id,
    title: _textOf(titleA),
    author: author.isEmpty ? null : author,
    coverUrl: cover.isEmpty ? null : cover,
    tags: tags,
    extra: {'url': '$linovelibBaseUrl/novel/$id.html'},
  );
}

List<Novel> parseBookList(String html) {
  final doc = html_parser.parse(html);
  final out = <Novel>[];
  for (final li in doc.querySelectorAll('div.lists ul li')) {
    final n = _novelFromBookLi(li);
    if (n != null) out.add(n);
  }
  return out;
}

List<NovelSection> parseHome(String html) {
  final doc = html_parser.parse(html);
  final sections = <NovelSection>[];
  for (final block in doc.querySelectorAll('div.tab-lists')) {
    final title = _textOf(block.querySelector('div.top-title .title'));
    final items = <Novel>[];
    for (final li in block.querySelectorAll('div.lists ul li')) {
      final n = _novelFromBookLi(li);
      if (n != null) items.add(n);
    }
    if (items.isNotEmpty) {
      sections.add(NovelSection(title: title.isEmpty ? '推荐' : title, items: items));
    }
  }
  return sections;
}

List<Novel> parseRankRows(String html) {
  final doc = html_parser.parse(html);
  final out = <Novel>[];
  for (final row in doc.querySelectorAll('div.rank_i_li')) {
    final bookA = row.querySelector('a.rank_i_l_a_book') ??
        row.querySelector('div.rank_i_bname a[href*="/novel/"]');
    final id = novelIdFromHref(bookA?.attributes['href']);
    if (bookA == null || id == null) continue;
    final img = row.querySelector('div.rank_i_bcount img');
    final cover = _absUrl(img?.attributes['data-original'] ?? img?.attributes['src']);
    final author = _textOf(row.querySelector('a.rank_i_l_a_author'));
    final rank = int.tryParse(_textOf(row.querySelector('div.rank_i_num')));
    out.add(Novel(
      id: id,
      title: _textOf(bookA),
      author: author.isEmpty ? null : author,
      coverUrl: cover.isEmpty ? null : cover,
      extra: {
        'url': '$linovelibBaseUrl/novel/$id.html',
        if (rank != null) 'rank': rank,
      },
    ));
  }
  return out;
}

bool hasNextPage(String html) {
  final doc = html_parser.parse(html);
  for (final a in doc.querySelectorAll('a')) {
    final t = a.text.trim();
    if (t.contains('下一页') || t.contains('下页')) return true;
  }
  return false;
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_parser_test.dart`
Expected: PASS（5 tests）

- [ ] **Step 5: 提交**

```bash
git add lib/core/novel/linovelib_source.dart test/core/novel/linovelib_parser_test.dart
git commit -m "feat(novel): add linovelib html parsers"
git push
```

---
