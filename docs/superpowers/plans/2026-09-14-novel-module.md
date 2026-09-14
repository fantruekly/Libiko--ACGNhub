# 轻小说模块（v1：首页浏览/排行）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用 linovelib（哔哩轻小说）源替换 `main_shell.dart` 的「轻小说」占位页，实现可浏览「推荐 / 排行 / 文库分类」的首页网格。

**Architecture:** `lib/core/novel/` 放 `NovelSource` 抽象、`LinovelibSource` 抓取实现与 `Novel` 等模型；纯解析逻辑抽成纯函数以便单测。`lib/modules/novel/` 放 Riverpod providers 与首页 UI。`main_shell.dart` 用 `NovelHomePage` 替换占位页。

**Tech Stack:** Flutter（Windows）、Riverpod 2.6、`dio`、`html` 包；**不引入新依赖**。

## Global Constraints

- `environment.sdk >=3.6.0`；`flutter_riverpod ^2.6.1`；`dio ^5.7.0`；`html ^0.15.5`。**不新增依赖。**
- 平台：Windows 桌面。
- 源：`https://www.linovelib.com`，响应 **UTF-8**；UA 用桌面 Chrome，`Referer: https://www.linovelib.com/`，超时 20s。
- 设计色：accent `0xFF007AFF`、fg `0xFF1C1C1E`、muted `0xFF5A5A5F`、bg `0xFFF2F2F7`、border `0xFFE5E5EA`。
- 复用共享组件：`lib/core/widgets/empty_state.dart`（`EmptyState`）、`lib/core/widgets/shimmer_loader.dart`（`ShimmerLoader`）、`lib/core/widgets/smooth_route.dart`（`smoothRoute`）。
- 字体族已全局配置为 `NotoSansSC`，`TextStyle` 里**不要**设 `fontFamily`。
- 每个 task 收尾：`flutter analyze lib test` 无问题、`flutter test` 全绿，然后 `git add` 指定文件 + `git commit` + `git push`。
- 命令前缀（PowerShell）：`$env:Path = "C:\flutter\bin;$env:Path";`
- 交流用中文。

## File Structure

- Create `lib/core/novel/models.dart` — `Novel` / `NovelSection` / `NovelHome` / `NovelList` / `NovelBrowse` / `NovelDetail` / `NovelChapter`。
- Create `lib/core/novel/novel_source.dart` — `NovelSource` 抽象 + `NovelSourceManager`。
- Create `lib/core/novel/linovelib_source.dart` — `LinovelibSource` + 纯解析函数。
- Create `lib/modules/novel/novel_providers.dart` — providers。
- Create `lib/modules/novel/novel_home.dart` — `NovelHomePage` + `NovelCard`。
- Modify `lib/shell/main_shell.dart` — index 2 换成 `NovelHomePage`。
- Create `test/core/novel/models_test.dart`、`test/core/novel/linovelib_parser_test.dart`、`test/core/novel/linovelib_source_test.dart`。

---

### Task 1: 模型 `models.dart`

**Files:**
- Create: `lib/core/novel/models.dart`
- Test: `test/core/novel/models_test.dart`

**Interfaces:**
- Produces:
  - `Novel { String id; String title; String? author; String? coverUrl; List<String> tags; String? summary; Map<String,dynamic> extra; }`，构造 `const Novel({required id, required title, author, coverUrl, tags = const [], summary, extra = const {}})`；`Novel.fromJson(Map<String,dynamic>)` / `Map<String,dynamic> toJson()`。
  - `NovelSection { String title; List<Novel> items; }`，`const NovelSection({required title, required items})`。
  - `NovelHome { List<NovelSection> sections; }`，`const NovelHome({required sections})`。
  - `NovelList { List<Novel> items; int page; bool hasMore; }`，`const NovelList({required items, required page, required hasMore})`。
  - `enum NovelBrowseKind { ranking, bunko }`。
  - `NovelBrowse { NovelBrowseKind kind; String key; }`，`const NovelBrowse(this.kind, this.key)`。
  - `NovelDetail { Novel novel; Map<String,String> chapters; }`，`const NovelDetail({required novel, required chapters})`。
  - `NovelChapter { String title; String content; }`，`const NovelChapter({required title, required content})`。

- [ ] **Step 1: 写失败测试**

`test/core/novel/models_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/novel/models.dart';

void main() {
  test('Novel round-trips through JSON', () {
    const novel = Novel(
      id: '2059',
      title: '安达与岛村',
      author: '入间人间',
      coverUrl: 'https://x/2059s.jpg',
      tags: ['电击文库'],
      summary: '简介',
      extra: {'url': '/novel/2059.html'},
    );
    final restored = Novel.fromJson(
      json.decode(json.encode(novel.toJson())) as Map<String, dynamic>,
    );
    expect(restored.id, '2059');
    expect(restored.title, '安达与岛村');
    expect(restored.author, '入间人间');
    expect(restored.coverUrl, 'https://x/2059s.jpg');
    expect(restored.tags, ['电击文库']);
    expect(restored.summary, '简介');
    expect(restored.extra['url'], '/novel/2059.html');
  });

  test('Novel.fromJson tolerates missing optional fields', () {
    final n = Novel.fromJson(const {'id': '1', 'title': 'T'});
    expect(n.author, isNull);
    expect(n.coverUrl, isNull);
    expect(n.tags, isEmpty);
    expect(n.extra, isEmpty);
  });

  test('NovelBrowse holds kind and key', () {
    const b = NovelBrowse(NovelBrowseKind.bunko, 'dengekibunko');
    expect(b.kind, NovelBrowseKind.bunko);
    expect(b.key, 'dengekibunko');
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/models_test.dart`
Expected: FAIL（`models.dart` 不存在 / 类未定义）

- [ ] **Step 3: 实现 `lib/core/novel/models.dart`**

```dart
List<String> _stringList(dynamic raw) {
  if (raw is List) {
    return raw.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
  }
  return const [];
}

class Novel {
  final String id;
  final String title;
  final String? author;
  final String? coverUrl;
  final List<String> tags;
  final String? summary;
  final Map<String, dynamic> extra;

  const Novel({
    required this.id,
    required this.title,
    this.author,
    this.coverUrl,
    this.tags = const [],
    this.summary,
    this.extra = const {},
  });

  factory Novel.fromJson(Map<String, dynamic> json) => Novel(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        author: json['author']?.toString(),
        coverUrl: json['coverUrl']?.toString(),
        tags: _stringList(json['tags']),
        summary: json['summary']?.toString(),
        extra: (json['extra'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (author != null) 'author': author,
        if (coverUrl != null) 'coverUrl': coverUrl,
        if (tags.isNotEmpty) 'tags': tags,
        if (summary != null) 'summary': summary,
        if (extra.isNotEmpty) 'extra': extra,
      };
}

class NovelSection {
  final String title;
  final List<Novel> items;
  const NovelSection({required this.title, required this.items});
}

class NovelHome {
  final List<NovelSection> sections;
  const NovelHome({required this.sections});
}

class NovelList {
  final List<Novel> items;
  final int page;
  final bool hasMore;
  const NovelList({required this.items, required this.page, required this.hasMore});
}

enum NovelBrowseKind { ranking, bunko }

class NovelBrowse {
  final NovelBrowseKind kind;
  final String key;
  const NovelBrowse(this.kind, this.key);
}

class NovelDetail {
  final Novel novel;
  final Map<String, String> chapters;
  const NovelDetail({required this.novel, required this.chapters});
}

class NovelChapter {
  final String title;
  final String content;
  const NovelChapter({required this.title, required this.content});
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/models_test.dart`
Expected: PASS（3 tests）

- [ ] **Step 5: 提交**

```bash
git add lib/core/novel/models.dart test/core/novel/models_test.dart
git commit -m "feat(novel): add novel models"
git push
```

---

### Task 2: `NovelSource` 抽象与 `NovelSourceManager`

**Files:**
- Create: `lib/core/novel/novel_source.dart`
- Test: `test/core/novel/novel_source_test.dart`

**Interfaces:**
- Consumes: `lib/core/novel/models.dart`（Task 1）。
- Produces:
  - `abstract class NovelSource { String get id; String get name; String get baseUrl; Future<NovelHome> home(); Future<NovelList> browse(NovelBrowse browse, {int page = 1}); Future<List<Novel>> search(String keyword, {int page = 1}); Future<NovelDetail> detail(String id); Future<NovelChapter> chapter(String novelId, String chapterId); }`
  - `class NovelSourceManager { NovelSourceManager({List<NovelSource>? sources}); List<NovelSource> get sources; void register(NovelSource s); NovelSource? byId(String id); }`（`register` 对重复 id 抛 `ArgumentError`）

- [ ] **Step 1: 写失败测试**

`test/core/novel/novel_source_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/novel/models.dart';
import 'package:acgnhub/core/novel/novel_source.dart';

class _FakeSource extends NovelSource {
  @override
  String get id => 'fake';
  @override
  String get name => 'Fake';
  @override
  String get baseUrl => 'https://fake';
  @override
  Future<NovelHome> home() async => const NovelHome(sections: []);
  @override
  Future<NovelList> browse(NovelBrowse browse, {int page = 1}) async =>
      NovelList(items: const [], page: page, hasMore: false);
  @override
  Future<List<Novel>> search(String keyword, {int page = 1}) async => const [];
  @override
  Future<NovelDetail> detail(String id) async =>
      const NovelDetail(novel: Novel(id: 'x', title: 'x'), chapters: {});
  @override
  Future<NovelChapter> chapter(String novelId, String chapterId) async =>
      const NovelChapter(title: 't', content: 'c');
}

void main() {
  test('manager exposes registered sources', () {
    final m = NovelSourceManager(sources: [_FakeSource()]);
    expect(m.sources.map((s) => s.id), ['fake']);
    expect(m.byId('fake')!.name, 'Fake');
    expect(m.byId('nope'), isNull);
  });

  test('manager rejects duplicate ids', () {
    final m = NovelSourceManager(sources: [_FakeSource()]);
    expect(() => m.register(_FakeSource()), throwsArgumentError);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/novel_source_test.dart`
Expected: FAIL（`novel_source.dart` 不存在）

- [ ] **Step 3: 实现 `lib/core/novel/novel_source.dart`**

```dart
import 'models.dart';

abstract class NovelSource {
  String get id;
  String get name;
  String get baseUrl;

  /// 首页：若干带标题的书单。
  Future<NovelHome> home();

  /// 排行 / 文库分类，分页。
  Future<NovelList> browse(NovelBrowse browse, {int page = 1});

  // v1 仅声明，后续实现：
  Future<List<Novel>> search(String keyword, {int page = 1});
  Future<NovelDetail> detail(String id);
  Future<NovelChapter> chapter(String novelId, String chapterId);
}

class NovelSourceManager {
  NovelSourceManager({List<NovelSource>? sources}) {
    for (final s in sources ?? const <NovelSource>[]) {
      register(s);
    }
  }

  final List<NovelSource> _sources = [];

  List<NovelSource> get sources => List.unmodifiable(_sources);

  void register(NovelSource source) {
    if (_sources.any((s) => s.id == source.id)) {
      throw ArgumentError('duplicate novel source id: ${source.id}');
    }
    _sources.add(source);
  }

  NovelSource? byId(String id) {
    for (final s in _sources) {
      if (s.id == id) return s;
    }
    return null;
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/novel_source_test.dart`
Expected: PASS（2 tests）

- [ ] **Step 5: 提交**

```bash
git add lib/core/novel/novel_source.dart test/core/novel/novel_source_test.dart
git commit -m "feat(novel): add NovelSource interface and manager"
git push
```

---

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

### Task 4: `LinovelibSource`（HTTP + URL 拼接）

**Files:**
- Modify: `lib/core/novel/linovelib_source.dart`（在 Task 3 的解析函数之后追加）
- Test: `test/core/novel/linovelib_source_test.dart`

**Interfaces:**
- Consumes: Task 1/2/3。
- Produces:
  - `class LinovelibSource implements NovelSource`：`id == 'linovelib'`、`name == '哔哩轻小说'`、`baseUrl == linovelibBaseUrl`；`home()`、`browse(...)` 实现；`search/detail/chapter` 抛 `UnimplementedError`。
  - `static String LinovelibSource.rankPath(String key, int page)` → `/top/<key>/<page>.html`（`key == 'allvisit'` 时 → `/top.html`）。
  - `static String LinovelibSource.bunkoPath(String key, int page)` → `/wenku/<key>/<page>.html`。

- [ ] **Step 1: 写失败测试**

`test/core/novel/linovelib_source_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/novel/linovelib_source.dart';
import 'package:acgnhub/core/novel/models.dart';

void main() {
  test('rankPath builds the ranking url', () {
    expect(LinovelibSource.rankPath('monthvote', 1), '/top/monthvote/1.html');
    expect(LinovelibSource.rankPath('allvisit', 1), '/top.html');
  });

  test('bunkoPath builds the bunko url', () {
    expect(LinovelibSource.bunkoPath('dengekibunko', 2), '/wenku/dengekibunko/2.html');
  });

  test('source identity', () {
    final s = LinovelibSource();
    expect(s.id, 'linovelib');
    expect(s.name, '哔哩轻小说');
    expect(s.baseUrl, linovelibBaseUrl);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_source_test.dart`
Expected: FAIL（`LinovelibSource` 未定义）

- [ ] **Step 3: 实现 `LinovelibSource`**

在 `lib/core/novel/linovelib_source.dart` 追加（顶部补 `import 'package:dio/dio.dart';` 与 `import 'novel_source.dart';`）：

```dart
class LinovelibSource implements NovelSource {
  LinovelibSource({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: linovelibBaseUrl,
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 20),
              headers: {
                'User-Agent': linovelibUserAgent,
                'Referer': '$linovelibBaseUrl/',
              },
            ));

  final Dio _dio;

  @override
  String get id => 'linovelib';

  @override
  String get name => '哔哩轻小说';

  @override
  String get baseUrl => linovelibBaseUrl;

  static String rankPath(String key, int page) =>
      key == 'allvisit' ? '/top.html' : '/top/$key/$page.html';

  static String bunkoPath(String key, int page) => '/wenku/$key/$page.html';

  Future<String> _get(String path) async {
    final res = await _dio.get<String>(
      path,
      options: Options(responseType: ResponseType.plain),
    );
    final data = res.data;
    if (res.statusCode != 200 || data == null) {
      throw Exception('linovelib 请求失败：$path (${res.statusCode})');
    }
    return data;
  }

  @override
  Future<NovelHome> home() async {
    final html = await _get('/');
    final sections = parseHome(html);
    if (sections.isEmpty) throw Exception('linovelib 首页解析为空');
    return NovelHome(sections: sections);
  }

  @override
  Future<NovelList> browse(NovelBrowse browse, {int page = 1}) async {
    final path = browse.kind == NovelBrowseKind.ranking
        ? rankPath(browse.key, page)
        : bunkoPath(browse.key, page);
    final html = await _get(path);
    final items = browse.kind == NovelBrowseKind.ranking
        ? parseRankRows(html)
        : parseBookList(html);
    return NovelList(items: items, page: page, hasMore: items.isNotEmpty && hasNextPage(html));
  }

  @override
  Future<List<Novel>> search(String keyword, {int page = 1}) =>
      throw UnimplementedError();

  @override
  Future<NovelDetail> detail(String id) => throw UnimplementedError();

  @override
  Future<NovelChapter> chapter(String novelId, String chapterId) =>
      throw UnimplementedError();
}
```

> 注意：`home()` 用 `/` 时，`Dio` 的 `baseUrl` 是 `https://www.linovelib.com`，`path` 用 `'/'`；若解析不到 `div.tab-lists`，先手动 `flutter run` 确认页面结构未变。

- [ ] **Step 4: 运行测试确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_source_test.dart`
Expected: PASS（3 tests）

- [ ] **Step 5: 提交**

```bash
git add lib/core/novel/linovelib_source.dart test/core/novel/linovelib_source_test.dart
git commit -m "feat(novel): add LinovelibSource with http + url building"
git push
```

---

### Task 5: providers

**Files:**
- Create: `lib/modules/novel/novel_providers.dart`

**Interfaces:**
- Consumes: Task 1/2/4。
- Produces:
  - `final novelSourceManagerProvider = Provider<NovelSourceManager>((ref) => NovelSourceManager(sources: [LinovelibSource()]));`
  - `final novelSourcesProvider = FutureProvider<List<NovelSource>>((ref) async => ref.watch(novelSourceManagerProvider).sources);`
  - `final novelHomeProvider = FutureProvider.family<NovelHome, String>((ref, sourceId) async { ... });`
  - `final novelBrowseProvider = FutureProvider.family<NovelList, (String, NovelBrowseKind, String, int)>((ref, key) async { ... });`
  - `List<Novel> flattenHome(NovelHome home)` — 合并去重（按 `id`）。

- [ ] **Step 1: 写失败测试（`flattenHome` 纯函数）**

`test/modules/novel/novel_providers_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/novel/models.dart';
import 'package:acgnhub/modules/novel/novel_providers.dart';

void main() {
  test('flattenHome merges sections and dedupes by id', () {
    const home = NovelHome(sections: [
      NovelSection(title: 'a', items: [Novel(id: '1', title: 'A'), Novel(id: '2', title: 'B')]),
      NovelSection(title: 'b', items: [Novel(id: '2', title: 'B'), Novel(id: '3', title: 'C')]),
    ]);
    final flat = flattenHome(home);
    expect(flat.map((n) => n.id), ['1', '2', '3']);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_providers_test.dart`
Expected: FAIL（文件不存在）

- [ ] **Step 3: 实现 `lib/modules/novel/novel_providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/novel/linovelib_source.dart';
import '../../core/novel/models.dart';
import '../../core/novel/novel_source.dart';

final novelSourceManagerProvider = Provider<NovelSourceManager>(
  (ref) => NovelSourceManager(sources: [LinovelibSource()]),
);

final novelSourcesProvider = FutureProvider<List<NovelSource>>(
  (ref) async => ref.watch(novelSourceManagerProvider).sources,
);

/// 合并首页各书单并按 id 去重。
List<Novel> flattenHome(NovelHome home) {
  final seen = <String>{};
  final out = <Novel>[];
  for (final section in home.sections) {
    for (final novel in section.items) {
      if (seen.add(novel.id)) out.add(novel);
    }
  }
  return out;
}

final novelHomeProvider =
    FutureProvider.family<NovelHome, String>((ref, sourceId) async {
  final source = ref.watch(novelSourceManagerProvider).byId(sourceId);
  if (source == null) throw StateError('novel source $sourceId not found');
  return source.home();
});

final novelBrowseProvider =
    FutureProvider.family<NovelList, (String, NovelBrowseKind, String, int)>(
        (ref, key) async {
  final (sourceId, kind, browseKey, page) = key;
  final source = ref.watch(novelSourceManagerProvider).byId(sourceId);
  if (source == null) throw StateError('novel source $sourceId not found');
  return source.browse(NovelBrowse(kind, browseKey), page: page);
});
```

- [ ] **Step 4: 运行测试确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_providers_test.dart`
Expected: PASS（1 test）

- [ ] **Step 5: 提交**

```bash
git add lib/modules/novel/novel_providers.dart test/modules/novel/novel_providers_test.dart
git commit -m "feat(novel): add novel providers"
git push
```

---

### Task 6: 首页 UI（`NovelCard` + `NovelHomePage`）并接入 shell

**Files:**
- Create: `lib/modules/novel/novel_home.dart`
- Modify: `lib/shell/main_shell.dart:5-9`（imports）、`:29-36`（`_pages` 第 3 项）
- Test: `test/modules/novel/novel_card_test.dart`

**Interfaces:**
- Consumes: Task 1/2/5。
- Produces:
  - `class NovelCard extends StatelessWidget { const NovelCard({required this.novel, this.onTap}); }`
  - `class NovelHomePage extends ConsumerStatefulWidget { const NovelHomePage({super.key}); }`

- [ ] **Step 1: 写失败测试（`NovelCard`）**

`test/modules/novel/novel_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/novel/models.dart';
import 'package:acgnhub/modules/novel/novel_home.dart';

void main() {
  testWidgets('NovelCard shows title and author', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 120,
          height: 200,
          child: NovelCard(novel: Novel(id: '1', title: '安达与岛村', author: '入间人间')),
        ),
      ),
    ));
    expect(find.text('安达与岛村'), findsOneWidget);
    expect(find.text('入间人间'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_card_test.dart`
Expected: FAIL（`novel_home.dart` 不存在）

- [ ] **Step 3: 实现 `lib/modules/novel/novel_home.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/novel/models.dart';
import '../../core/novel/novel_source.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_loader.dart';
import 'novel_providers.dart';

const _accent = Color(0xFF007AFF);
const _muted = Color(0xFF5A5A5F);
const _fg = Color(0xFF1C1C1E);

class NovelCard extends StatelessWidget {
  final Novel novel;
  final VoidCallback? onTap;
  const NovelCard({super.key, required this.novel, this.onTap});

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
              child: novel.coverUrl != null && novel.coverUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: novel.coverUrl!,
                      fit: BoxFit.cover,
                      memCacheWidth: 400,
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
              novel.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500, height: 1.45, color: _fg),
            ),
          ),
          if (novel.author != null && novel.author!.isNotEmpty)
            Text(
              novel.author!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: _muted),
            ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    final hash = novel.title.hashCode.abs();
    const bg = [Color(0xFFF3E5F5), Color(0xFFEDE7F6), Color(0xFFE8EAF6), Color(0xFFE0F2F1)];
    return Container(
      color: bg[hash % bg.length],
      child: Center(
        child: Text(
          novel.title.isEmpty ? '书' : novel.title.characters.first,
          style: TextStyle(
              color: _accent.withValues(alpha: 0.2), fontSize: 28, fontWeight: FontWeight.w400),
        ),
      ),
    );
  }
}

enum _NovelSection { recommend, ranking, bunko }

const _rankingOptions = <String, String>{
  'allvisit': '人气榜',
  'monthvisit': '月点击',
  'weekvisit': '周点击',
  'monthvote': '月推荐',
  'weekvote': '周推荐',
  'monthflower': '月鲜花',
  'weekflower': '周鲜花',
  'monthegg': '月鸡蛋',
  'weekegg': '周鸡蛋',
  'lastupdate': '最近更新',
  'postdate': '最新入库',
  'goodnum': '收藏榜',
  'newhot': '新书榜',
};

const _bunkoOptions = <String, String>{
  'dengekibunko': '电击',
  'fujimibunko': '富士见',
  'kadokawabunko': '角川',
  'emuefubunkojei': 'MF文库J',
  'famitsubunko': 'Fami通',
  'gagraphicbunko': 'GA',
  'hobbyjapanbunko': 'HJ',
  'ichijinsha': '一迅社',
  'shueisha': '集英社',
  'shogakukan': '小学馆',
  'kodansha': '讲谈社',
  'teenagebunko': '少女文库',
  'other': '其他文库',
  'chineselightnovel': '华文轻小说',
};

class NovelHomePage extends ConsumerStatefulWidget {
  const NovelHomePage({super.key});
  @override
  ConsumerState<NovelHomePage> createState() => _NovelHomePageState();
}

class _NovelHomePageState extends ConsumerState<NovelHomePage> {
  String _sourceId = 'linovelib';
  _NovelSection _section = _NovelSection.recommend;
  String _rankingKey = 'allvisit';
  String _bunkoKey = 'dengekibunko';
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(novelSourcesProvider);
    return Column(
      children: [
        const SizedBox(height: 8),
        _sourceChips(sources.valueOrNull ?? const []),
        _sectionChips(),
        if (_section == _NovelSection.ranking) _optionChips(_rankingOptions, _rankingKey, (k) => setState(() { _rankingKey = k; _page = 1; })),
        if (_section == _NovelSection.bunko) _optionChips(_bunkoOptions, _bunkoKey, (k) => setState(() { _bunkoKey = k; _page = 1; })),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _sourceChips(List<NovelSource> sources) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final s in sources)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _chip(s.name, s.id == _sourceId, () => setState(() {
                _sourceId = s.id;
                _page = 1;
              })),
            ),
        ],
      ),
    );
  }

  Widget _sectionChips() {
    const labels = {_NovelSection.recommend: '推荐', _NovelSection.ranking: '排行', _NovelSection.bunko: '文库'};
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final e in labels.entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _chip(e.value, e.key == _section, () => setState(() {
                _section = e.key;
                _page = 1;
              })),
            ),
        ],
      ),
    );
  }

  Widget _optionChips(Map<String, String> options, String selected, ValueChanged<String> onTap) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final e in options.entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _chip(e.value, e.key == selected, () => onTap(e.key)),
            ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      selectedColor: _accent,
      backgroundColor: const Color(0xFFF2F2F7),
      labelStyle: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w500, color: selected ? Colors.white : _muted),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _body() {
    if (_section == _NovelSection.recommend) {
      final async = ref.watch(novelHomeProvider(_sourceId));
      return async.when(
        loading: () => const ShimmerLoader(crossAxisCount: 6, itemCount: 12),
        error: (_, __) => EmptyState(
          icon: Icons.cloud_off_rounded,
          message: '加载失败',
          actionLabel: '重试',
          onAction: () => ref.invalidate(novelHomeProvider(_sourceId)),
        ),
        data: (home) => _grid(flattenHome(home), null),
      );
    }
    final kind = _section == _NovelSection.ranking ? NovelBrowseKind.ranking : NovelBrowseKind.bunko;
    final key = _section == _NovelSection.ranking ? _rankingKey : _bunkoKey;
    final async = ref.watch(novelBrowseProvider((_sourceId, kind, key, _page)));
    return async.when(
      loading: () => const ShimmerLoader(crossAxisCount: 6, itemCount: 12),
      error: (_, __) => EmptyState(
        icon: Icons.cloud_off_rounded,
        message: '加载失败',
        actionLabel: '重试',
        onAction: () => ref.invalidate(novelBrowseProvider((_sourceId, kind, key, _page))),
      ),
      data: (list) => _grid(list.items, list.hasMore ? () => setState(() => _page++) : null),
    );
  }

  Widget _grid(List<Novel> items, VoidCallback? onLoadMore) {
    if (items.isEmpty) {
      return const EmptyState(icon: Icons.menu_book_rounded, message: '暂无内容');
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (onLoadMore != null &&
            n.metrics.pixels >= n.metrics.maxScrollExtent - 400) {
          onLoadMore();
        }
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6, mainAxisSpacing: 20, crossAxisSpacing: 16, childAspectRatio: 0.58),
        itemCount: items.length,
        itemBuilder: (_, i) => NovelCard(novel: items[i]),
      ),
    );
  }
}
```

> 需要 `import 'package:characters/characters.dart';`？Flutter 的 `String.characters` 由 `package:flutter/widgets.dart` 导出，`material.dart` 已间接导出，无需额外 import（若 analyzer 报错，加 `import 'package:flutter/widgets.dart';`）。

- [ ] **Step 4: 运行测试确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_card_test.dart`
Expected: PASS（1 test）

- [ ] **Step 5: 接入 shell**

修改 `lib/shell/main_shell.dart`：
- imports 增加 `import '../modules/novel/novel_home.dart';`
- `_pages` 第 3 项把 `_buildModulePlaceholder('轻小说', ...)` 换成 `const NovelHomePage()`。

改后 `_pages` 为：

```dart
  final _pages = <Widget>[
    const AnimeHomePage(),
    const ComicHomePage(),
    const NovelHomePage(),
    _buildModulePlaceholder('游戏', Icons.games_rounded, '游戏模块',
        '浏览 Galgame 游戏资源与详细信息', const Color(0xFFAF52DE)),
  ];
```

- [ ] **Step 6: 全量校验**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: 全部通过

- [ ] **Step 7: 手动验证（构建并运行）**

```powershell
$env:Path = "C:\flutter\bin;$env:Path"
flutter build windows --debug
Start-Process -FilePath "D:\ACGNhub\build\windows\x64\runner\Debug\acgnhub.exe" -WorkingDirectory "D:\ACGNhub\build\windows\x64\runner\Debug"
```

打开「轻小说」标签，确认：源 chip 显示「哔哩轻小说」；「推荐」网格有封面/书名/作者；切「排行」出现子 chip 且列表可加载；切「文库」同理；滚动到底能加载下一页。

- [ ] **Step 8: 提交**

```bash
git add lib/modules/novel/novel_home.dart lib/shell/main_shell.dart test/modules/novel/novel_card_test.dart
git commit -m "feat(novel): add novel home page and wire into shell"
git push
```

---

## Self-Review

**Spec coverage:**
- 源接入（linovelib）→ Task 4；`NovelSource` 抽象 → Task 2；模型 `Novel` → Task 1。
- 首页「推荐/排行/文库」分区 chip + 网格 → Task 6；排行/文库子 chip → Task 6。
- providers（4 个）→ Task 5。
- 抓取选择器与 URL → Task 3/4。
- 错误处理（EmptyState + 重试）→ Task 6。
- 测试（解析 fixture 单测 + 模型单测 + 卡片 widget 测试）→ Task 1/3/6。
- 接入 `main_shell.dart` → Task 6。

**Placeholder scan:** 无 TBD/TODO；每个代码步骤含完整代码。

**Type consistency:** `NovelBrowseKind`（Task 1）在 Task 4/5/6 一致；`parseHome/parseBookList/parseRankRows/hasNextPage/novelIdFromHref`（Task 3）在 Task 4 使用；`flattenHome`（Task 5）在 Task 6 使用；`novelHomeProvider`/`novelBrowseProvider`（Task 5）签名与 Task 6 调用一致。

---

### Task 7: 最终审查修复（手动换页 + hasMore + 请求头 + 小项）

> 来自最终整支审查。用户决定：**去掉自动触底加载，改为底部手动「上一页/下一页」换页**；其余 Important/Minor 一并修。

**Files:**
- Modify: `lib/core/novel/linovelib_source.dart`
- Modify: `lib/modules/novel/novel_home.dart`
- Modify: `lib/modules/novel/novel_providers.dart`
- Test: `test/core/novel/linovelib_parser_test.dart`、`test/modules/novel/novel_card_test.dart`

**Interfaces:**
- Produces: `bool hasPaginationControl(String html)`（`div.pagination` 是否存在）；`hasNextPage(String html)` 改为只在 `div.pagination` 内找「下一页」。
- `novelSourcesProvider` 由 `FutureProvider<List<NovelSource>>` 改为 `Provider<List<NovelSource>>`（同步，无 loading 帧）。

- [ ] **Step 1: 写失败测试（hasPaginationControl / hasNextPage）**

在 `test/core/novel/linovelib_parser_test.dart` 末尾追加：

```dart
const _pagerNextHtml =
    '<div class="pagination"><a href="/top/monthvote/2.html">下一页</a></div>';
const _pagerNoNextHtml =
    '<div class="pagination"><a href="/top/monthvote/1.html">上一页</a></div>';
const _pagerLastHtml =
    '<div class="pagination"><span>下一页</span></div>';

void _paginationTests() {
  test('hasPaginationControl detects the container', () {
    expect(hasPaginationControl(_pagerNextHtml), isTrue);
    expect(hasPaginationControl(_bookListHtml), isFalse);
  });

  test('hasNextPage only trusts a next link inside div.pagination', () {
    expect(hasNextPage(_pagerNextHtml), isTrue);
    expect(hasNextPage(_pagerNoNextHtml), isFalse);
    expect(hasNextPage(_pagerLastHtml), isFalse); // <span>, not a link
    expect(hasNextPage(_bookListHtml), isFalse); // no pagination control
  });
}
```

并在 `main()` 末尾（最后一个 `});` 之后、`}` 之前）调用 `_paginationTests();`。

- [ ] **Step 2: 运行确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_parser_test.dart`
Expected: FAIL（`hasPaginationControl` 未定义）

- [ ] **Step 3: 改 `linovelib_source.dart`**

把 `hasNextPage` 替换为：

```dart
bool hasPaginationControl(String html) =>
    html_parser.parse(html).querySelector('div.pagination') != null;

bool hasNextPage(String html) {
  final container = html_parser.parse(html).querySelector('div.pagination');
  if (container == null) return false;
  for (final a in container.querySelectorAll('a')) {
    final t = a.text.trim();
    if (t.contains('下一页') || t.contains('下页')) return true;
  }
  return false;
}
```

`LinovelibSource` 的 headers 补 `Accept`/`Accept-Language`：

```dart
              headers: {
                'User-Agent': linovelibUserAgent,
                'Accept':
                    'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
                'Referer': '$linovelibBaseUrl/',
              },
```

`browse` 的返回改为按 spec 判定 `hasMore`：

```dart
    final items = browse.kind == NovelBrowseKind.ranking
        ? parseRankRows(html)
        : parseBookList(html);
    final hasMore = hasPaginationControl(html)
        ? hasNextPage(html)
        : items.length >= 10;
    return NovelList(items: items, page: page, hasMore: hasMore);
```

`parseRankRows` 补文库标签（与 `_novelFromBookLi` 一致）：

```dart
    final cate = _textOf(row.querySelector('a.rank_i_l_a_category'));
    final tags = <String>[];
    if (cate.isNotEmpty) {
      tags.add(cate.replaceAll('[', '').replaceAll(']', ''));
    }
    out.add(Novel(
      id: id,
      title: _textOf(bookA),
      author: author.isEmpty ? null : author,
      coverUrl: cover.isEmpty ? null : cover,
      tags: tags,
      extra: {
        'url': '$linovelibBaseUrl/novel/$id.html',
        if (rank != null) 'rank': rank,
      },
    ));
```

- [ ] **Step 4: 运行确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_parser_test.dart`
Expected: PASS（原 5 + 新 2）

- [ ] **Step 5: `novel_providers.dart` 把 `novelSourcesProvider` 改同步**

```dart
final novelSourcesProvider =
    Provider<List<NovelSource>>((ref) => ref.watch(novelSourceManagerProvider).sources);
```

- [ ] **Step 6: `novel_home.dart` 去掉自动触底，改手动换页**

- `build()` 里 `final sources = ref.watch(novelSourcesProvider);`（不再是 AsyncValue），`_sourceChips(sources)` 接收 `List<NovelSource>`。
- 删除 `_grid` 的 `onLoadMore` 参数与 `NotificationListener`。
- `_body()` 的 loading 分支改为与网格参数一致：
  `const ShimmerLoader(crossAxisCount: 6, itemCount: 12, aspectRatio: 0.58, padding: EdgeInsets.fromLTRB(16, 8, 16, 24))`
- `_body()` 的排行/文库 `data` 分支：

```dart
      data: (list) => Column(
        children: [
          Expanded(child: _grid(list.items)),
          _pager(list.hasMore),
        ],
      ),
```

- 新增 `_pager`：

```dart
  Widget _pager(bool hasMore) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton(
            onPressed: _page > 1 ? () => setState(() => _page--) : null,
            child: const Text('上一页'),
          ),
          const SizedBox(width: 16),
          Text('第 $_page 页',
              style: const TextStyle(fontSize: 13, color: _muted)),
          const SizedBox(width: 16),
          OutlinedButton(
            onPressed: hasMore ? () => setState(() => _page++) : null,
            child: const Text('下一页'),
          ),
        ],
      ),
    );
  }
```

- `_grid` 签名改为 `Widget _grid(List<Novel> items)`，去掉滚动监听：

```dart
  Widget _grid(List<Novel> items) {
    if (items.isEmpty) {
      return const EmptyState(icon: Icons.menu_book_rounded, message: '暂无内容');
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          mainAxisSpacing: 20,
          crossAxisSpacing: 16,
          childAspectRatio: 0.58),
      itemCount: items.length,
      itemBuilder: (_, i) => NovelCard(novel: items[i]),
    );
  }
```

- [ ] **Step 7: 补 `NovelCard` 占位测试**

在 `test/modules/novel/novel_card_test.dart` 追加：

```dart
  testWidgets('NovelCard shows a placeholder when there is no cover',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 120,
          height: 200,
          child: NovelCard(novel: Novel(id: '1', title: '安达与岛村')),
        ),
      ),
    ));
    expect(find.text('安'), findsOneWidget);
  });
```

- [ ] **Step 8: 全量校验**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: 全部通过

- [ ] **Step 9: 提交**

```bash
git add lib/core/novel/linovelib_source.dart lib/modules/novel/novel_home.dart lib/modules/novel/novel_providers.dart test/core/novel/linovelib_parser_test.dart test/modules/novel/novel_card_test.dart
git commit -m "fix(novel): manual paging, spec-compliant hasMore, browser headers, polish"
git push
```

---

### Task 8: 复审修复（人气榜单页 + 小项）

> 来自 Task 7 的复审。`人气榜`（`allvisit` → `/top.html`）是**单页**，但 `rankPath` 忽略 `page`、`hasMore` 又因 `items>=10` 回退恒为 true，导致默认排行 tab 的「下一页」无限循环重复。

**Files:**
- Modify: `lib/core/novel/linovelib_source.dart`
- Modify: `test/core/novel/linovelib_parser_test.dart`
- Modify: `docs/superpowers/specs/2026-09-14-novel-module-design.md`

**Interfaces:**
- Produces: `static bool LinovelibSource.isSinglePageRanking(NovelBrowse browse)` → `browse.kind == NovelBrowseKind.ranking && browse.key == 'allvisit'`。

- [ ] **Step 1: 写失败测试**

在 `test/core/novel/linovelib_source_test.dart` 追加：

```dart
  test('allvisit is a single-page ranking', () {
    expect(
        LinovelibSource.isSinglePageRanking(
            const NovelBrowse(NovelBrowseKind.ranking, 'allvisit')),
        isTrue);
    expect(
        LinovelibSource.isSinglePageRanking(
            const NovelBrowse(NovelBrowseKind.ranking, 'monthvote')),
        isFalse);
    expect(
        LinovelibSource.isSinglePageRanking(
            const NovelBrowse(NovelBrowseKind.bunko, 'dengekibunko')),
        isFalse);
  });
```

（该测试文件若没有 `import 'package:acgnhub/core/novel/models.dart';` 需补上。）

- [ ] **Step 2: 运行确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_source_test.dart`
Expected: FAIL（`isSinglePageRanking` 未定义）

- [ ] **Step 3: 实现 + 应用到 `browse`**

在 `LinovelibSource` 里加：

```dart
  static bool isSinglePageRanking(NovelBrowse browse) =>
      browse.kind == NovelBrowseKind.ranking && browse.key == 'allvisit';
```

`browse` 的 `hasMore` 改为：

```dart
    final hasMore = isSinglePageRanking(browse)
        ? false
        : (hasPaginationControl(html)
            ? hasNextPage(html)
            : items.length >= 10);
    return NovelList(items: items, page: page, hasMore: hasMore);
```

- [ ] **Step 4: 运行确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_source_test.dart`
Expected: PASS（原 3 + 新 1）

- [ ] **Step 5: 补 `parseRankRows` 标签断言**

在 `test/core/novel/linovelib_parser_test.dart` 的 `parseRankRows parses rank rows` 测试里，`expect(items.first.extra['rank'], 1);` 之后加：

```dart
    expect(items.first.tags, ['novelpia']);
```

- [ ] **Step 6: 修正 spec 文案**

在 `docs/superpowers/specs/2026-09-14-novel-module-design.md`：
- 把 `novelSourcesProvider                    // FutureProvider<List<NovelSource>>` 改为 `// Provider<List<NovelSource>>`。
- 在「排行」子 chip 说明后补一句：`人气榜`（`allvisit`，`/top.html`）为**单页**，不显示分页。

- [ ] **Step 7: 全量校验**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: 全部通过

- [ ] **Step 8: 提交**

```bash
git add lib/core/novel/linovelib_source.dart test/core/novel/linovelib_source_test.dart test/core/novel/linovelib_parser_test.dart docs/superpowers/specs/2026-09-14-novel-module-design.md
git commit -m "fix(novel): treat 人气榜 as a single page; test rank tags; sync spec"
git push
```
