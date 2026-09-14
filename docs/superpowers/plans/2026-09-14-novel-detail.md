# 轻小说详情 + 分卷目录 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 点首页卡片进入轻小说详情页：展示封面/书名/作者/标签/简介 + 分卷目录（分卷 + 章节列表）。

**Architecture:** 在现有 `lib/core/novel/` 加模型与纯解析函数（`parseNovelDetailHeader`/`parseCatalog`/`chapterIdFromHref`），`LinovelibSource.detail()` 抓详情页 + 目录页并合并；`lib/modules/novel/` 加 `novelDetailProvider` 与 `NovelDetailPage`，并把首页 `NovelCard.onTap` 接上。

**Tech Stack:** Flutter（Windows）、Riverpod 2.6、`dio`、`html`、`cached_network_image`；**不引入新依赖**。

## Global Constraints

- `environment.sdk >=3.6.0`；`flutter_riverpod ^2.6.1`；`dio ^5.7.0`；`html ^0.15.5`；`cached_network_image ^3.4.1`。**不新增依赖。**
- 平台：Windows 桌面。
- 源：`https://www.linovelib.com`，UTF-8；`LinovelibSource._get` 已带 UA/`Accept`/`Accept-Language`/`Referer`，超时 20s。
- 设计色：accent `0xFF007AFF`、fg `0xFF1C1C1E`、muted `0xFF5A5A5F`、bg `0xFFF2F2F7`。
- 复用共享组件：`EmptyState`、`ShimmerLoader`、`PillButton`（`lib/core/widgets/pill_button.dart`）、`smoothRoute`。
- `TextStyle` 里**不要**设 `fontFamily`（全局 `NotoSansSC`）。
- 每个 task 收尾：`flutter analyze lib test` 无问题、`flutter test` 全绿，然后 `git add` 指定文件 + `git commit` + `git push`。
- 命令前缀（PowerShell）：`$env:Path = "C:\flutter\bin;$env:Path";`
- 交流用中文。

## File Structure

- Modify `lib/core/novel/models.dart` — 加 `NovelChapterRef`/`NovelVolume`；改 `NovelDetail`。
- Modify `lib/core/novel/linovelib_source.dart` — 加 `chapterIdFromHref`/`parseNovelDetailHeader`/`parseCatalog`；实现 `LinovelibSource.detail`。
- Modify `lib/modules/novel/novel_providers.dart` — 加 `novelDetailProvider`。
- Create `lib/modules/novel/novel_detail_page.dart` — `NovelDetailPage`。
- Modify `lib/modules/novel/novel_home.dart` — `NovelCard.onTap` 接详情页。
- Modify `test/core/novel/novel_source_test.dart` — `_FakeSource.detail` 适配新 `NovelDetail`。
- Test: `test/core/novel/linovelib_detail_parser_test.dart`、`test/modules/novel/novel_detail_page_test.dart`。

---

### Task 1: 模型（`NovelChapterRef` / `NovelVolume` / `NovelDetail`）

**Files:**
- Modify: `lib/core/novel/models.dart`
- Modify: `test/core/novel/novel_source_test.dart`
- Test: `test/core/novel/models_test.dart`

**Interfaces:**
- Produces:
  - `NovelChapterRef { String id; String title; }`，`const NovelChapterRef({required id, required title})`。
  - `NovelVolume { String title; String? url; List<NovelChapterRef> chapters; }`，`const NovelVolume({required title, url, chapters = const []})`。
  - `NovelDetail { Novel novel; List<NovelVolume> volumes; }`，`const NovelDetail({required novel, required volumes})`（**替换**原来的 `chapters` 字段）。

- [ ] **Step 1: 写失败测试**

在 `test/core/novel/models_test.dart` 的 `main()` 末尾追加：

```dart
  test('NovelDetail holds volumes with chapter refs', () {
    const detail = NovelDetail(
      novel: Novel(id: '5340', title: 'T'),
      volumes: [
        NovelVolume(title: '正文', url: 'https://x/vol_1.html', chapters: [
          NovelChapterRef(id: '333607', title: '封面'),
        ]),
      ],
    );
    expect(detail.volumes.single.title, '正文');
    expect(detail.volumes.single.chapters.single.id, '333607');
    expect(detail.volumes.single.chapters.single.title, '封面');
  });
```

- [ ] **Step 2: 运行确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/models_test.dart`
Expected: FAIL（`NovelVolume`/`NovelChapterRef` 未定义，或 `NovelDetail` 无 `volumes`）

- [ ] **Step 3: 改 `lib/core/novel/models.dart`**

把 `NovelDetail` 替换为下面三个类（放在 `NovelChapter` 之前）：

```dart
class NovelChapterRef {
  final String id;
  final String title;
  const NovelChapterRef({required this.id, required this.title});
}

class NovelVolume {
  final String title;
  final String? url;
  final List<NovelChapterRef> chapters;
  const NovelVolume({required this.title, this.url, this.chapters = const []});
}

class NovelDetail {
  final Novel novel;
  final List<NovelVolume> volumes;
  const NovelDetail({required this.novel, required this.volumes});
}
```

- [ ] **Step 4: 适配 `test/core/novel/novel_source_test.dart`**

把 `_FakeSource.detail` 里的 `const NovelDetail(novel: Novel(id: 'x', title: 'x'), chapters: {})` 改为：

```dart
  Future<NovelDetail> detail(String id) async =>
      const NovelDetail(novel: Novel(id: 'x', title: 'x'), volumes: []);
```

- [ ] **Step 5: 运行确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/models_test.dart test/core/novel/novel_source_test.dart`
Expected: PASS

- [ ] **Step 6: 提交**

```bash
git add lib/core/novel/models.dart test/core/novel/models_test.dart test/core/novel/novel_source_test.dart
git commit -m "feat(novel): add volume/chapter models for detail"
git push
```

---

### Task 2: 解析函数（详情页头 + 目录页）

**Files:**
- Modify: `lib/core/novel/linovelib_source.dart`
- Test: `test/core/novel/linovelib_detail_parser_test.dart`

**Interfaces:**
- Consumes: Task 1 的 `Novel`/`NovelVolume`/`NovelChapterRef`；本文件已有的 `_absUrl`/`_textOf`（私有）。
- Produces:
  - `String? chapterIdFromHref(String? href)` — 从 `/novel/<bookId>/<chapterId>.html` 取**第二段** `<chapterId>`；不匹配返回 `null`。
  - `Novel parseNovelDetailHeader(String html, String id)` — 书名/封面/作者/标签/简介；状态入 `extra['status']`。
  - `List<NovelVolume> parseCatalog(String html, String novelId)` — 分卷 + 章节。

- [ ] **Step 1: 写失败测试（含真实精简 fixture）**

`test/core/novel/linovelib_detail_parser_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/novel/linovelib_source.dart';

const _detailHtml = '''
<html><head>
<meta property="og:novel:author" content="이만두" />
<meta property="og:novel:tags" content="病娇 后宫 恋爱 " />
<meta property="og:novel:status" content="连载" />
</head><body>
<div class="book-html-box">
  <div class="book-main">
    <div class="book-detail clearfix">
      <div class="book-img fl"><img src="https://www.linovelib.com/files/article/image/5/5340/5340s.jpg" alt="x"></div>
      <div class="book-info">
        <h1 class="book-name">不相容的異種族妻子們</h1>
        <div class="book-dec">一夫多妻制已經遭到廢除。我們不必再勉強彼此共同生活了……</div>
      </div>
    </div>
  </div>
</div>
</body></html>
''';

const _catalogHtml = '''
<div class="volume-list" id="volume-list">
  <div class="volume clearfix">
    <div class="volume-info"><h2 class="v-line"><a href="/novel/5340/vol_333606.html">不相容的異種族妻子們 插圖</a></h2></div>
    <ul class="chapter-list clearfix">
      <li class="col-4"><a href="/novel/5340/333607.html">封面</a></li>
      <li class="col-4"><a href="/novel/5340/333608.html">粉絲同人圖</a></li>
    </ul>
  </div>
  <div class="volume clearfix">
    <div class="volume-info"><h2 class="v-line"><a href="/novel/5340/vol_333597.html">不相容的異種族妻子們 正文</a></h2></div>
    <ul class="chapter-list clearfix">
      <li class="col-4"><a href="/novel/5340/334356.html">第60話 規則（2）</a></li>
    </ul>
  </div>
</div>
''';

void main() {
  test('chapterIdFromHref takes the second number', () {
    expect(chapterIdFromHref('/novel/5340/333607.html'), '333607');
    expect(chapterIdFromHref('https://www.linovelib.com/novel/5340/334356.html'), '334356');
    expect(chapterIdFromHref('/novel/5340.html'), isNull);
    expect(chapterIdFromHref(null), isNull);
  });

  test('parseNovelDetailHeader parses header fields', () {
    final novel = parseNovelDetailHeader(_detailHtml, '5340');
    expect(novel.id, '5340');
    expect(novel.title, '不相容的異種族妻子們');
    expect(novel.author, '이만두');
    expect(novel.coverUrl,
        'https://www.linovelib.com/files/article/image/5/5340/5340s.jpg');
    expect(novel.tags, ['病娇', '后宫', '恋爱']);
    expect(novel.summary, contains('一夫多妻制'));
    expect(novel.extra['status'], '连载');
  });

  test('parseCatalog parses volumes and chapters', () {
    final volumes = parseCatalog(_catalogHtml, '5340');
    expect(volumes, hasLength(2));
    expect(volumes.first.title, '不相容的異種族妻子們 插圖');
    expect(volumes.first.chapters.map((c) => c.id), ['333607', '333608']);
    expect(volumes.first.chapters.first.title, '封面');
    expect(volumes.last.chapters.single.id, '334356');
    expect(volumes.last.url, 'https://www.linovelib.com/novel/5340/vol_333597.html');
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_detail_parser_test.dart`
Expected: FAIL（`chapterIdFromHref` 等未定义）

- [ ] **Step 3: 在 `linovelib_source.dart` 实现解析函数**

在 `hasNextPage` 之后追加：

```dart
final RegExp _chapterHref = RegExp(r'/novel/\d+/(\d+)\.html');

String? chapterIdFromHref(String? href) {
  if (href == null) return null;
  return _chapterHref.firstMatch(href)?.group(1);
}

String _metaContent(dom.Document doc, String property) {
  final el = doc.querySelector('meta[property="$property"]') ??
      doc.querySelector('meta[name="$property"]');
  return el?.attributes['content']?.trim() ?? '';
}

Novel parseNovelDetailHeader(String html, String id) {
  final doc = html_parser.parse(html);
  final title = _textOf(doc.querySelector('h1.book-name'));
  final img = doc.querySelector('div.book-img img');
  final cover = _absUrl(img?.attributes['src'] ?? img?.attributes['data-original']);
  final author = _metaContent(doc, 'og:novel:author');
  final tags = _metaContent(doc, 'og:novel:tags')
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .toList();
  final status = _metaContent(doc, 'og:novel:status');
  final summary = _textOf(doc.querySelector('div.book-dec'));
  return Novel(
    id: id,
    title: title,
    author: author.isEmpty ? null : author,
    coverUrl: cover.isEmpty ? null : cover,
    tags: tags,
    summary: summary.isEmpty ? null : summary,
    extra: {
      'url': '$linovelibBaseUrl/novel/$id.html',
      if (status.isNotEmpty) 'status': status,
    },
  );
}

List<NovelVolume> parseCatalog(String html, String novelId) {
  final doc = html_parser.parse(html);
  final volumes = <NovelVolume>[];
  for (final vol in doc.querySelectorAll('div.volume-list div.volume')) {
    final titleA = vol.querySelector('h2.v-line a');
    final chapters = <NovelChapterRef>[];
    for (final a in vol.querySelectorAll('ul.chapter-list li a')) {
      final cid = chapterIdFromHref(a.attributes['href']);
      if (cid == null) continue;
      chapters.add(NovelChapterRef(id: cid, title: _textOf(a)));
    }
    volumes.add(NovelVolume(
      title: _textOf(titleA),
      url: titleA == null ? null : _absUrl(titleA.attributes['href']),
      chapters: chapters,
    ));
  }
  return volumes;
}
```

- [ ] **Step 4: 运行确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_detail_parser_test.dart`
Expected: PASS（3 tests）

- [ ] **Step 5: 提交**

```bash
git add lib/core/novel/linovelib_source.dart test/core/novel/linovelib_detail_parser_test.dart
git commit -m "feat(novel): add detail/catalog parsers"
git push
```

---

### Task 3: `LinovelibSource.detail`

**Files:**
- Modify: `lib/core/novel/linovelib_source.dart`
- Test: `test/core/novel/linovelib_source_test.dart`

**Interfaces:**
- Consumes: Task 2 的解析函数；已有 `_get`。
- Produces:
  - `static String LinovelibSource.detailPath(String id)` → `/novel/<id>.html`。
  - `static String LinovelibSource.catalogPath(String id)` → `/novel/<id>/catalog`。
  - `Future<NovelDetail> LinovelibSource.detail(String id)`：抓两页并合并。

- [ ] **Step 1: 写失败测试**

在 `test/core/novel/linovelib_source_test.dart` 追加：

```dart
  test('detail/catalog paths', () {
    expect(LinovelibSource.detailPath('5340'), '/novel/5340.html');
    expect(LinovelibSource.catalogPath('5340'), '/novel/5340/catalog');
  });
```

- [ ] **Step 2: 运行确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_source_test.dart`
Expected: FAIL（`detailPath` 未定义）

- [ ] **Step 3: 实现**

在 `LinovelibSource` 里，把 `detail` 的 `throw UnimplementedError()` 替换为：

```dart
  static String detailPath(String id) => '/novel/$id.html';

  static String catalogPath(String id) => '/novel/$id/catalog';

  @override
  Future<NovelDetail> detail(String id) async {
    final detailHtml = await _get(detailPath(id));
    final catalogHtml = await _get(catalogPath(id));
    return NovelDetail(
      novel: parseNovelDetailHeader(detailHtml, id),
      volumes: parseCatalog(catalogHtml, id),
    );
  }
```

- [ ] **Step 4: 运行确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_source_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/core/novel/linovelib_source.dart test/core/novel/linovelib_source_test.dart
git commit -m "feat(novel): implement LinovelibSource.detail"
git push
```

---

### Task 4: `novelDetailProvider`

**Files:**
- Modify: `lib/modules/novel/novel_providers.dart`

**Interfaces:**
- Consumes: `novelSourceManagerProvider`；`NovelSource.detail`。
- Produces: `final novelDetailProvider = FutureProvider.family<NovelDetail, (String, String)>((ref, key) async { ... });`，key = `(sourceId, novelId)`；source 不存在抛 `StateError`。

- [ ] **Step 1: 实现（无独立测试，随 Task 5 一起在 widget 层覆盖）**

在 `novel_providers.dart` 末尾追加（`models.dart` 已 import）：

```dart
final novelDetailProvider =
    FutureProvider.family<NovelDetail, (String, String)>((ref, key) async {
  final (sourceId, novelId) = key;
  final source = ref.watch(novelSourceManagerProvider).byId(sourceId);
  if (source == null) throw StateError('novel source $sourceId not found');
  return source.detail(novelId);
});
```

- [ ] **Step 2: 校验**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib`
Expected: `No issues found!`

- [ ] **Step 3: 提交**

```bash
git add lib/modules/novel/novel_providers.dart
git commit -m "feat(novel): add novelDetailProvider"
git push
```

---

### Task 5: 详情页 UI + 接首页卡片

**Files:**
- Create: `lib/modules/novel/novel_detail_page.dart`
- Modify: `lib/modules/novel/novel_home.dart`
- Test: `test/modules/novel/novel_detail_page_test.dart`

**Interfaces:**
- Consumes: Task 4 的 `novelDetailProvider`；`EmptyState`/`ShimmerLoader`/`PillButton`/`smoothRoute`。
- Produces:
  - `class NovelDetailPage extends ConsumerStatefulWidget { final String sourceKey; final String novelId; final String title; final String? cover; }`
  - 首页 `NovelCard.onTap` 打开 `NovelDetailPage`。

- [ ] **Step 1: 写失败测试（provider override 渲染）**

`test/modules/novel/novel_detail_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/novel/models.dart';
import 'package:acgnhub/modules/novel/novel_detail_page.dart';
import 'package:acgnhub/modules/novel/novel_providers.dart';

void main() {
  testWidgets('NovelDetailPage renders title, author and chapters',
      (tester) async {
    const detail = NovelDetail(
      novel: Novel(id: '5340', title: '不相容的異種族妻子們', author: '이만두'),
      volumes: [
        NovelVolume(title: '正文', chapters: [
          NovelChapterRef(id: '334356', title: '第60話 規則（2）'),
        ]),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        novelDetailProvider(('linovelib', '5340'))
            .overrideWith((ref) async => detail),
      ],
      child: const MaterialApp(
        home: NovelDetailPage(
            sourceKey: 'linovelib', novelId: '5340', title: '不相容的異種族妻子們'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('이만두'), findsOneWidget);
    expect(find.text('正文'), findsOneWidget);
    expect(find.text('第60話 規則（2）'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_detail_page_test.dart`
Expected: FAIL（`novel_detail_page.dart` 不存在）

- [ ] **Step 3: 实现 `lib/modules/novel/novel_detail_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/novel/models.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/pill_button.dart';
import '../../core/widgets/shimmer_loader.dart';
import 'novel_providers.dart';

const _accent = Color(0xFF007AFF);
const _muted = Color(0xFF5A5A5F);
const _fg = Color(0xFF1C1C1E);

class NovelDetailPage extends ConsumerStatefulWidget {
  final String sourceKey;
  final String novelId;
  final String title;
  final String? cover;
  const NovelDetailPage({
    super.key,
    required this.sourceKey,
    required this.novelId,
    required this.title,
    this.cover,
  });

  @override
  ConsumerState<NovelDetailPage> createState() => _NovelDetailPageState();
}

class _NovelDetailPageState extends ConsumerState<NovelDetailPage> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final key = (widget.sourceKey, widget.novelId);
    final async = ref.watch(novelDetailProvider(key));
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: async.when(
        loading: () => const ShimmerLoader(
            crossAxisCount: 6,
            itemCount: 12,
            aspectRatio: 0.58,
            padding: EdgeInsets.fromLTRB(16, 8, 16, 24)),
        error: (_, __) => EmptyState(
          icon: Icons.cloud_off_rounded,
          message: '加载失败',
          actionLabel: '重试',
          onAction: () => ref.invalidate(novelDetailProvider(key)),
        ),
        data: (detail) => _content(detail),
      ),
    );
  }

  Widget _content(NovelDetail detail) {
    final novel = detail.novel;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _header(novel),
        const SizedBox(height: 16),
        if (detail.volumes.isEmpty)
          const SizedBox(
            height: 200,
            child: EmptyState(
                icon: Icons.menu_book_rounded, message: '暂无章节'),
          )
        else
          for (final vol in detail.volumes) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Text(vol.title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600, color: _fg)),
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final ch in vol.chapters)
                  PillButton(label: ch.title, onTap: () => _openChapter()),
              ],
            ),
          ],
      ],
    );
  }

  Widget _header(Novel novel) {
    final summary = novel.summary ?? '';
    final cover = (novel.coverUrl?.isNotEmpty ?? false)
        ? novel.coverUrl
        : (widget.cover?.isNotEmpty ?? false ? widget.cover : null);
    final status = novel.extra['status']?.toString();
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
                child: SizedBox(
                  width: 100,
                  height: 132,
                  child: cover != null
                      ? CachedNetworkImage(imageUrl: cover, fit: BoxFit.cover)
                      : Container(color: const Color(0xFFE8EAF6)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(novel.title,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: _fg)),
                    const SizedBox(height: 6),
                    if (novel.author != null && novel.author!.isNotEmpty)
                      Text(novel.author!,
                          style: const TextStyle(fontSize: 13, color: _muted)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (status != null && status.isNotEmpty) _tag(status),
                        for (final t in novel.tags) _tag(t),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              summary,
              maxLines: _expanded ? null : 3,
              overflow: _expanded ? null : TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, height: 1.5, color: _fg),
            ),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_expanded ? '收起' : '展开',
                    style: const TextStyle(fontSize: 13, color: _accent)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: const Color(0xFFE8F0FE),
            borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11, color: _accent, fontWeight: FontWeight.w500)),
      );

  void _openChapter() {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('阅读器开发中')));
  }
}
```

- [ ] **Step 4: 运行确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_detail_page_test.dart`
Expected: PASS

- [ ] **Step 5: 首页卡片接详情页**

在 `lib/modules/novel/novel_home.dart`：
- 顶部加 `import '../../core/widgets/smooth_route.dart';` 与 `import 'novel_detail_page.dart';`。
- `_grid` 的 `itemBuilder` 改为：

```dart
      itemBuilder: (_, i) => NovelCard(
        novel: items[i],
        onTap: () => Navigator.push(
          context,
          smoothRoute(NovelDetailPage(
            sourceKey: _sourceId,
            novelId: items[i].id,
            title: items[i].title,
            cover: items[i].coverUrl,
          )),
        ),
      ),
```

- [ ] **Step 6: 全量校验 + 手动验证**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: 全部通过

```powershell
$env:Path = "C:\flutter\bin;$env:Path"
flutter build windows --debug
Start-Process -FilePath "D:\ACGNhub\build\windows\x64\runner\Debug\acgnhub.exe" -WorkingDirectory "D:\ACGNhub\build\windows\x64\runner\Debug"
```

打开「轻小说」→ 点任一卡片 → 确认详情页显示封面/书名/作者/标签/简介 + 分卷目录；点章节弹「阅读器开发中」。

- [ ] **Step 7: 提交**

```bash
git add lib/modules/novel/novel_detail_page.dart lib/modules/novel/novel_home.dart test/modules/novel/novel_detail_page_test.dart
git commit -m "feat(novel): add detail page and wire home cards"
git push
```

---

### Task 6: 最终审查修复（封面/简介回退/占位/展开）

> 来自最终整支审查。

**Files:**
- Modify: `lib/core/novel/linovelib_source.dart`
- Modify: `lib/modules/novel/novel_detail_page.dart`
- Modify: `test/core/novel/linovelib_detail_parser_test.dart`
- Modify: `docs/superpowers/specs/2026-09-14-novel-detail-design.md`

- [ ] **Step 1: 写失败测试（封面优先级 + 简介回退）**

在 `test/core/novel/linovelib_detail_parser_test.dart` 追加：

```dart
  test('parseNovelDetailHeader prefers data-original cover and meta summary',
      () {
    const html = '''
<meta property="og:novel:author" content="A" />
<meta name="description" content="META简介" />
<div class="book-img"><img src="x.svg" data-original="https://x/real.jpg"></div>
<h1 class="book-name">书名</h1>''';
    final novel = parseNovelDetailHeader(html, '1');
    expect(novel.coverUrl, 'https://x/real.jpg');
    expect(novel.summary, 'META简介');
  });
```

- [ ] **Step 2: 运行确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_detail_parser_test.dart`
Expected: FAIL（封面得到 `x.svg` / 简介为 null）

- [ ] **Step 3: 改 `linovelib_source.dart`**

`parseNovelDetailHeader` 里：
- 封面改为优先 `data-original`（与列表解析器一致）：
```dart
  final cover =
      _absUrl(img?.attributes['data-original'] ?? img?.attributes['src']);
```
- 简介加 `meta[name=description]` 回退：
```dart
  var summary = _textOf(doc.querySelector('div.book-dec'));
  if (summary.isEmpty) summary = _metaContent(doc, 'description');
```
- `detail` 两页并发：
```dart
  @override
  Future<NovelDetail> detail(String id) async {
    final pages =
        await Future.wait([_get(detailPath(id)), _get(catalogPath(id))]);
    return NovelDetail(
      novel: parseNovelDetailHeader(pages[0], id),
      volumes: parseCatalog(pages[1], id),
    );
  }
```

- [ ] **Step 4: 运行确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_detail_parser_test.dart`
Expected: PASS

- [ ] **Step 5: 详情页封面加占位 + 展开仅在有溢出时显示**

在 `lib/modules/novel/novel_detail_page.dart`：
- 封面加 `placeholder`/`errorWidget`：
```dart
                  child: cover != null
                      ? CachedNetworkImage(
                          imageUrl: cover,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _coverPlaceholder(),
                          errorWidget: (_, __, ___) => _coverPlaceholder(),
                        )
                      : _coverPlaceholder(),
```
并加方法：
```dart
  Widget _coverPlaceholder() => Container(color: const Color(0xFFE8EAF6));
```
- 简介区改为「仅在溢出 3 行时显示展开/收起」：
```dart
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 14),
            LayoutBuilder(builder: (context, constraints) {
              const style = TextStyle(fontSize: 13, height: 1.5, color: _fg);
              final overflows =
                  _summaryOverflows(summary, style, constraints.maxWidth);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(summary,
                      maxLines: _expanded ? null : 3,
                      overflow: _expanded ? null : TextOverflow.ellipsis,
                      style: style),
                  if (overflows)
                    GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(_expanded ? '收起' : '展开',
                            style: const TextStyle(fontSize: 13, color: _accent)),
                      ),
                    ),
                ],
              );
            }),
          ],
```
并加方法：
```dart
  bool _summaryOverflows(String text, TextStyle style, double maxWidth) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 3,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    return tp.didExceedMaxLines;
  }
```

- [ ] **Step 6: 修正 spec 文案**

`docs/superpowers/specs/2026-09-14-novel-detail-design.md`：把封面那行改为
`封面：div.book-img img 的 data-original（回退 src）`。

- [ ] **Step 7: 全量校验**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: 全部通过

- [ ] **Step 8: 提交**

```bash
git add lib/core/novel/linovelib_source.dart lib/modules/novel/novel_detail_page.dart test/core/novel/linovelib_detail_parser_test.dart docs/superpowers/specs/2026-09-14-novel-detail-design.md
git commit -m "fix(novel): robust cover precedence, summary fallback, cover placeholder, overflow-gated expand"
git push
```

---

## Self-Review

**Spec coverage:**
- 模型 `NovelChapterRef`/`NovelVolume`/`NovelDetail` → Task 1。
- 解析 `parseNovelDetailHeader`/`parseCatalog`/`chapterIdFromHref` → Task 2。
- `LinovelibSource.detail`（详情页 + 目录页）→ Task 3。
- `novelDetailProvider` → Task 4。
- `NovelDetailPage` + 卡片接线 → Task 5。
- 错误处理（EmptyState + 重试）→ Task 5。
- 测试（解析 fixture + 详情页 widget）→ Task 2/5。

**Placeholder scan:** 无 TBD/TODO；每个代码步骤含完整代码。

**Type consistency:** `NovelVolume`/`NovelChapterRef`（Task 1）在 Task 2/3/5 一致；`parseNovelDetailHeader`/`parseCatalog`（Task 2）在 Task 3 使用；`novelDetailProvider`（Task 4）在 Task 5 使用；`NovelDetail` 新签名在 Task 1 全量替换（含 `novel_source_test.dart` 的 `_FakeSource`）。
