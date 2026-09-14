# 轻小说搜索 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 给轻小说模块加跨书源搜索：顶栏入口 + 聚合 lknovel/linovelib 结果 + 点结果进详情。

**Architecture:** 实现两个源的 `search()`（lknovel 走 JSON API，linovelib 走 `/S6/` 表单 POST + 新解析函数）；`novelSearchProvider` 聚合所有源并按书名去重；新增 `NovelSearchPage`（镜像 `ComicSearchPage`）；`main_shell` 顶栏搜索图标对轻小说也显示。

**Tech Stack:** Flutter/Dart 3.6、Riverpod、Dio、`package:html`。

## Global Constraints

- 运行环境：Flutter 在 `C:\flutter\bin`；命令前缀 `$env:Path = "C:\flutter\bin;$env:Path";`；工作目录 `D:\ACGNhub`。
- 每个任务结束必须：`flutter analyze lib test` 无问题 + `flutter test` 全绿。
- 每个任务结束提交并推送：`git add <精确文件>` → `git commit` → `git push origin dev`。
- 不新增依赖；不改 `pubspec.yaml`。
- 不加代码注释（与现有风格一致者除外）。中文 UI 文案。
- lknovel API 前缀 `/api/pc-proxy/api/`；linovelib 搜索 `POST https://www.linovelib.com/S6/`。
- 结果聚合展示、不标来源、按书名去重；单页无分页。

---

### Task 1: linovelib 搜索

**Files:**
- Modify: `lib/core/novel/linovelib_source.dart`
- Test: `test/core/novel/linovelib_search_parser_test.dart`

**Interfaces:**
- Consumes: 文件内已有的 `_absUrl`、`_textOf`、`novelIdFromHref`、`_dio`、`linovelibBaseUrl`。
- Produces: `List<Novel> parseSearchResults(String html)`；`LinovelibSource.search(String keyword, {int page = 1})`。

- [ ] **Step 1: 写解析器的失败测试**

创建 `test/core/novel/linovelib_search_parser_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/novel/linovelib_source.dart';

const _searchHtml = '''
<div class="search-result-list clearfix">
  <div class="imgbox fl se-result-book"><a href="/novel/3676.html"><img src="x.svg" data-original="https://www.linovelib.com/files/article/image/3/3676/3676s.jpg"></a></div>
  <div class="fl se-result-infos">
    <h2 class="tit"><a href="/novel/3676.html">败犬女主太多了</a></h2>
    <div class="bookinfo"><a href="/authorarticle/x.html">雨森</a><em>|</em><a href="/wenku/famitsubunko/1.html">Fami通</a><em>|</em><span>连载</span></div>
    <p>简介文字</p>
  </div>
</div>
''';

void main() {
  test('parseSearchResults reads search result cards', () {
    final items = parseSearchResults(_searchHtml);
    expect(items, hasLength(1));
    final n = items.single;
    expect(n.id, '3676');
    expect(n.title, '败犬女主太多了');
    expect(n.author, '雨森');
    expect(n.coverUrl,
        'https://www.linovelib.com/files/article/image/3/3676/3676s.jpg');
    expect(n.summary, '简介文字');
  });

  test('parseSearchResults returns empty when no results', () {
    expect(parseSearchResults('<div></div>'), isEmpty);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_search_parser_test.dart`
Expected: 编译失败（`parseSearchResults` 未定义）。

- [ ] **Step 3: 实现解析器**

编辑 `lib/core/novel/linovelib_source.dart`，在 `parseMobileBookList` 之后新增：

```dart
List<Novel> parseSearchResults(String html) {
  final doc = html_parser.parse(html);
  final out = <Novel>[];
  for (final row in doc.querySelectorAll('div.search-result-list')) {
    final titleA = row.querySelector('h2.tit a');
    final id = novelIdFromHref(titleA?.attributes['href']);
    if (titleA == null || id == null) continue;
    final img = row.querySelector('div.imgbox img');
    final cover =
        _absUrl(img?.attributes['data-original'] ?? img?.attributes['src']);
    final author = _textOf(row.querySelector('div.bookinfo a'));
    final summary = _textOf(row.querySelector('p'));
    out.add(Novel(
      id: id,
      title: _textOf(titleA),
      author: author.isEmpty ? null : author,
      coverUrl: cover.isEmpty ? null : cover,
      summary: summary.isEmpty ? null : summary,
      extra: {'url': '$linovelibBaseUrl/novel/$id.html'},
    ));
  }
  return out;
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_search_parser_test.dart`
Expected: 全部通过。

- [ ] **Step 5: 实现 `search`**

编辑 `lib/core/novel/linovelib_source.dart`，把：

```dart
  @override
  Future<List<Novel>> search(String keyword, {int page = 1}) =>
      throw UnimplementedError();
```

替换为：

```dart
  @override
  Future<List<Novel>> search(String keyword, {int page = 1}) async {
    final k = keyword.trim();
    if (k.isEmpty) return const [];
    final res = await _dio.post<String>(
      '/S6/',
      data: {'searchkey': k},
      options: Options(
        responseType: ResponseType.plain,
        contentType: Headers.formUrlEncodedContentType,
      ),
    );
    final html = res.data;
    if (res.statusCode != 200 || html == null) {
      throw Exception('linovelib 搜索失败：$k (${res.statusCode})');
    }
    return parseSearchResults(html);
  }
```

- [ ] **Step 6: 运行静态检查与全量测试**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: 全绿。

- [ ] **Step 7: 提交**

```bash
git add lib/core/novel/linovelib_source.dart test/core/novel/linovelib_search_parser_test.dart
git commit -m "feat(novel): linovelib search"
git push origin dev
```

---

### Task 2: lknovel 搜索

**Files:**
- Modify: `lib/core/novel/lknovel_source.dart`
- Test: `test/core/novel/lknovel_source_test.dart`

**Interfaces:**
- Consumes: `LknovelSource._post`、`lkData`、`parseLkList`；`test/core/novel/lknovel_source_test.dart` 里已有的 `_feedData` fixture。
- Produces: `LknovelSource.search(String keyword, {int page = 1})`。

- [ ] **Step 1: 写失败测试**

在 `test/core/novel/lknovel_source_test.dart` 的 `main()` 末尾（最后一个 `test` 之后）追加：

```dart
  test('search posts to apk-search-result-v1', () async {
    Map<String, dynamic>? seen;
    final source = LknovelSource(poster: (endpoint, body) async {
      expect(endpoint, 'bff/apk-search-result-v1');
      seen = body;
      return {'code': 0, 'data': _feedData};
    });
    final list = await source.search('败犬', page: 2);
    expect(seen!['q'], '败犬');
    expect(seen!['page'], 2);
    expect(list.single.id, '1338');
  });
```

- [ ] **Step 2: 运行测试确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/lknovel_source_test.dart`
Expected: 失败（`search` 抛 `UnimplementedError`）。

- [ ] **Step 3: 实现 `search`**

编辑 `lib/core/novel/lknovel_source.dart`，把：

```dart
  @override
  Future<List<Novel>> search(String keyword, {int page = 1}) =>
      throw UnimplementedError();
```

替换为：

```dart
  @override
  Future<List<Novel>> search(String keyword, {int page = 1}) async {
    final k = keyword.trim();
    if (k.isEmpty) return const [];
    final json = await _post('bff/apk-search-result-v1', {
      'q': k,
      'page': page,
      'page_size': 20,
      'pageSize': 20,
    });
    return parseLkList(lkData(json));
  }
```

- [ ] **Step 4: 运行测试确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/lknovel_source_test.dart`
Expected: 全部通过。

- [ ] **Step 5: 静态检查与全量测试**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: 全绿。

- [ ] **Step 6: 提交**

```bash
git add lib/core/novel/lknovel_source.dart test/core/novel/lknovel_source_test.dart
git commit -m "feat(novel): lknovel search"
git push origin dev
```

---

### Task 3: 聚合搜索 Provider

**Files:**
- Modify: `lib/modules/novel/novel_providers.dart`
- Test: `test/modules/novel/novel_search_provider_test.dart`

**Interfaces:**
- Consumes: `NovelSource.search`（Task 1/2）、`novelSourceManagerProvider`、`Novel`。
- Produces:
  - `class NovelSearchResult { final Novel novel; final String sourceKey; const NovelSearchResult({required this.novel, required this.sourceKey}); }`
  - `final novelSearchProvider = FutureProvider.family<List<NovelSearchResult>, String>((ref, keyword) async {...});`

- [ ] **Step 1: 写失败测试**

创建 `test/modules/novel/novel_search_provider_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:acgnhub/core/novel/models.dart';
import 'package:acgnhub/core/novel/novel_source.dart';
import 'package:acgnhub/modules/novel/novel_providers.dart';

class _SearchSource extends NovelSource {
  _SearchSource(this.id, this.results, {this.throws = false});
  @override
  final String id;
  final List<Novel> results;
  final bool throws;
  @override
  String get name => id;
  @override
  String get baseUrl => 'https://x';
  @override
  List<NovelBrowseGroup> get browseGroups => const [];
  @override
  Future<NovelHome> home() async => const NovelHome(sections: []);
  @override
  Future<NovelList> browse(String optionKey, {int page = 1}) async =>
      NovelList(items: const [], page: page, hasMore: false);
  @override
  Future<List<Novel>> search(String keyword, {int page = 1}) async {
    if (throws) throw Exception('boom');
    return results;
  }

  @override
  Future<NovelDetail> detail(String id) async =>
      const NovelDetail(novel: Novel(id: 'x', title: 'x'), volumes: []);
  @override
  Future<NovelChapter> chapter(String novelId, String chapterId) async =>
      const NovelChapter(title: 't', blocks: []);
}

ProviderContainer _container(List<NovelSource> sources) {
  final c = ProviderContainer(overrides: [
    novelSourceManagerProvider
        .overrideWithValue(NovelSourceManager(sources: sources)),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('aggregates across sources and dedupes by title', () async {
    final c = _container([
      _SearchSource('a', const [Novel(id: '1', title: 'X'), Novel(id: '2', title: 'Y')]),
      _SearchSource('b', const [Novel(id: '3', title: 'X'), Novel(id: '4', title: 'Z')]),
    ]);
    final results = await c.read(novelSearchProvider('k').future);
    expect(results.map((r) => r.novel.title), ['X', 'Y', 'Z']);
    expect(results.first.sourceKey, 'a');
    expect(results.last.sourceKey, 'b');
  });

  test('skips a failing source', () async {
    final c = _container([
      _SearchSource('a', const [], throws: true),
      _SearchSource('b', const [Novel(id: '4', title: 'Z')]),
    ]);
    final results = await c.read(novelSearchProvider('k').future);
    expect(results.single.novel.title, 'Z');
  });

  test('throws when every source fails', () async {
    final c = _container([_SearchSource('a', const [], throws: true)]);
    await expectLater(c.read(novelSearchProvider('k').future), throwsA(isA<StateError>()));
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_search_provider_test.dart`
Expected: 编译失败（`NovelSearchResult` / `novelSearchProvider` 未定义）。

- [ ] **Step 3: 实现**

在 `lib/modules/novel/novel_providers.dart` 末尾新增：

```dart
class NovelSearchResult {
  final Novel novel;
  final String sourceKey;
  const NovelSearchResult({required this.novel, required this.sourceKey});
}

final novelSearchProvider =
    FutureProvider.family<List<NovelSearchResult>, String>((ref, keyword) async {
  final k = keyword.trim();
  if (k.isEmpty) return const [];
  final sources = ref.watch(novelSourceManagerProvider).sources;
  final out = <NovelSearchResult>[];
  final seen = <String>{};
  Object? lastError;
  var succeeded = 0;
  for (final source in sources) {
    try {
      for (final novel in await source.search(k)) {
        if (seen.add(novel.title.trim())) {
          out.add(NovelSearchResult(novel: novel, sourceKey: source.id));
        }
      }
      succeeded++;
    } catch (e) {
      lastError = e;
    }
  }
  if (succeeded == 0) {
    throw StateError('所有轻小说源搜索失败：$lastError');
  }
  return out;
});
```

- [ ] **Step 4: 运行测试确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_search_provider_test.dart`
Expected: 全部通过。

- [ ] **Step 5: 静态检查与全量测试**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: 全绿。

- [ ] **Step 6: 提交**

```bash
git add lib/modules/novel/novel_providers.dart test/modules/novel/novel_search_provider_test.dart
git commit -m "feat(novel): aggregate search provider"
git push origin dev
```

---

### Task 4: 搜索页与入口

**Files:**
- Create: `lib/modules/novel/novel_search.dart`
- Modify: `lib/shell/main_shell.dart`
- Test: `test/modules/novel/novel_search_page_test.dart`

**Interfaces:**
- Consumes: `novelSearchProvider` / `NovelSearchResult`（Task 3）、`NovelCard`（`lib/modules/novel/novel_home.dart`）、`NovelDetailPage`、`noTransitionRoute`、`EmptyState`、`ShimmerLoader`。
- Produces: `class NovelSearchPage extends ConsumerStatefulWidget { final String? initialKeyword; const NovelSearchPage({super.key, this.initialKeyword}); }`

- [ ] **Step 1: 写失败测试**

创建 `test/modules/novel/novel_search_page_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/novel/models.dart';
import 'package:acgnhub/modules/novel/novel_providers.dart';
import 'package:acgnhub/modules/novel/novel_search.dart';

void main() {
  testWidgets('renders results from the provider', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        novelSearchProvider('关键词').overrideWith((ref) async => const [
              NovelSearchResult(
                  novel: Novel(id: '1', title: '结果书'), sourceKey: 'lknovel'),
            ]),
      ],
      child: const MaterialApp(home: NovelSearchPage(initialKeyword: '关键词')),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('结果书'), findsOneWidget);
  });

  testWidgets('shows a prompt before searching', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: NovelSearchPage()),
    ));
    expect(find.text('输入关键词搜索轻小说'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_search_page_test.dart`
Expected: 编译失败（`novel_search.dart` 不存在）。

- [ ] **Step 3: 实现搜索页**

创建 `lib/modules/novel/novel_search.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../core/widgets/smooth_route.dart';
import 'novel_detail_page.dart';
import 'novel_home.dart';
import 'novel_providers.dart';

const _muted = Color(0xFF5A5A5F);

class NovelSearchPage extends ConsumerStatefulWidget {
  final String? initialKeyword;
  const NovelSearchPage({super.key, this.initialKeyword});

  @override
  ConsumerState<NovelSearchPage> createState() => _NovelSearchPageState();
}

class _NovelSearchPageState extends ConsumerState<NovelSearchPage> {
  final _ctrl = TextEditingController();
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialKeyword?.trim() ?? '';
    if (initial.isNotEmpty) {
      _ctrl.text = initial;
      _keyword = initial;
    }
  }

  void _search() {
    final k = _ctrl.text.trim();
    if (k.isEmpty) return;
    setState(() => _keyword = k);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          children: [
            _searchBar(cs),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _searchBar(ColorScheme cs) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        border:
            Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
            splashRadius: 20,
          ),
          Expanded(
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded,
                      size: 18, color: cs.onSurface.withValues(alpha: 0.3)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: widget.initialKeyword == null,
                      style: TextStyle(fontSize: 15, color: cs.onSurface),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '搜索轻小说...',
                        hintStyle: TextStyle(color: _muted, fontSize: 15),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => _search(),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (_ctrl.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _ctrl.clear();
                        setState(() {});
                      },
                      child: Icon(Icons.close_rounded,
                          size: 16, color: cs.onSurface.withValues(alpha: 0.3)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
              onPressed: _search,
              child: const Text('搜索', style: TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _body() {
    if (_keyword.isEmpty) {
      return const EmptyState(
          icon: Icons.search_rounded, message: '输入关键词搜索轻小说');
    }
    final async = ref.watch(novelSearchProvider(_keyword));
    return async.when(
      loading: () => const ShimmerLoader(
        crossAxisCount: 6,
        itemCount: 12,
        aspectRatio: 0.58,
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
      ),
      error: (error, __) => EmptyState(
        icon: Icons.error_outline_rounded,
        message: error.toString(),
        actionLabel: '重试',
        onAction: () => ref.invalidate(novelSearchProvider(_keyword)),
      ),
      data: (results) {
        if (results.isEmpty) {
          return const EmptyState(
              icon: Icons.search_off_rounded, message: '没有找到轻小说');
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 20,
              crossAxisSpacing: 16,
              childAspectRatio: 0.58),
          itemCount: results.length,
          itemBuilder: (_, i) {
            final r = results[i];
            return NovelCard(
              novel: r.novel,
              onTap: () => Navigator.push(
                context,
                noTransitionRoute(NovelDetailPage(
                  sourceKey: r.sourceKey,
                  novelId: r.novel.id,
                  title: r.novel.title,
                  cover: r.novel.coverUrl,
                )),
              ),
            );
          },
        );
      },
    );
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_search_page_test.dart`
Expected: 全部通过。

- [ ] **Step 5: 接入顶栏入口**

编辑 `lib/shell/main_shell.dart`：

(a) 加 import：

```dart
import '../modules/novel/novel_search.dart';
```

(b) 把顶栏搜索图标的条件与跳转：

```dart
              if (_currentIndex == 0 || _currentIndex == 1)
                IconButton(
                  icon: const Icon(Icons.search_rounded, size: 20),
                  color: _muted,
                  splashRadius: 20,
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => _currentIndex == 0
                              ? const AnimeSearchPage()
                              : const ComicSearchPage())),
                ),
```

替换为：

```dart
              if (_currentIndex >= 0 && _currentIndex <= 2)
                IconButton(
                  icon: const Icon(Icons.search_rounded, size: 20),
                  color: _muted,
                  splashRadius: 20,
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => _currentIndex == 0
                              ? const AnimeSearchPage()
                              : _currentIndex == 1
                                  ? const ComicSearchPage()
                                  : const NovelSearchPage())),
                ),
```

- [ ] **Step 6: 运行静态检查与全量测试**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: 全绿。

- [ ] **Step 7: 提交**

```bash
git add lib/modules/novel/novel_search.dart lib/shell/main_shell.dart test/modules/novel/novel_search_page_test.dart
git commit -m "feat(novel): search page and top-bar entry"
git push origin dev
```

---

## 验证（任务全部完成后）

1. `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` 全绿。
2. 构建并启动应用，切到轻小说模块：
   - 顶栏出现搜索图标；点击打开搜索页。
   - 输入关键词（如「败犬」）回车/点「搜索」→ 出现结果网格（合并两个源、按书名去重）。
   - 点结果进入详情页。
   - 空关键词显示「输入关键词搜索轻小说」；无结果显示「没有找到轻小说」。

## 已知取舍

- 单页、无分页/加载更多；不做搜索历史与按源筛选。
- 结果不标来源；同名书只保留第一个。
