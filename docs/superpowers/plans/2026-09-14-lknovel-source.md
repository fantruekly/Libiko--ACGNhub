# 轻之国度（lknovel）书源 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把轻小说模块的浏览分类改为「由书源声明」，并新增第二个书源「轻之国度（lknovel）」，覆盖首页书单、排行/分类浏览、详情目录与正文阅读。

**Architecture:** `NovelSource` 新增 `browseGroups` 声明式接口，`browse` 改为接收 option key；首页通用渲染「推荐 + 各分组 + 组内选项」。`LknovelSource` 走 lknovel 的 JSON API（`POST /api/pc-proxy/api/...`，游客可用），实现 `home`/`browse`/`detail`/`chapter`。HTTP 层通过可注入的 `LkPoster` 与纯解析函数解耦，便于单测。

**Tech Stack:** Flutter/Dart 3.6、Riverpod、Dio、html（`package:html`）。

## Global Constraints

- 运行环境：Flutter 在 `C:\flutter\bin`；命令前缀 `$env:Path = "C:\flutter\bin;$env:Path";`；工作目录 `D:\ACGNhub`。
- 每个任务结束必须：`flutter analyze lib test` 无问题 + `flutter test` 全绿。
- 每个任务结束提交并推送：`git add <精确文件>` → `git commit` → `git push origin dev`（分支 `dev` 跟踪 `origin/dev`）。
- 不新增任何依赖；不改 `pubspec.yaml`。
- 不加代码注释（除非必要且与现有风格一致）。
- 中文 UI 文案。
- lknovel 基址 `https://www.lightnovel.fun`；API 前缀 `/api/pc-proxy/api/`；响应 `{"code":0,"data":{...}}`，`code != 0` 视为失败。
- lknovel 封面/插图无防盗链，沿用现有 `novelImageHeaders`，不改图片逻辑。

---

### Task 1: 浏览分组通用化（模型 / 接口 / linovelib / 首页 UI）

把写死的 `NovelBrowseKind { ranking, bunko }` 替换为「书源声明的分组与选项」，首页按分组通用渲染；linovelib 的排行/文库选项搬进 `LinovelibSource.browseGroups`。

**Files:**
- Modify: `lib/core/novel/models.dart`
- Modify: `lib/core/novel/novel_source.dart`
- Modify: `lib/core/novel/linovelib_source.dart`
- Modify: `lib/modules/novel/novel_providers.dart`
- Modify: `lib/modules/novel/novel_home.dart`
- Test: `test/core/novel/models_test.dart`
- Test: `test/core/novel/novel_source_test.dart`
- Test: `test/modules/novel/novel_home_pager_test.dart`

**Interfaces:**
- Consumes: 无（首个任务）。
- Produces:
  - `class NovelBrowseOption { final String key; final String label; const NovelBrowseOption({required this.key, required this.label}); }`
  - `class NovelBrowseGroup { final String label; final List<NovelBrowseOption> options; const NovelBrowseGroup({required this.label, required this.options}); }`
  - `class NovelVolume { final String? id; final String title; final String? url; final List<NovelChapterRef> chapters; const NovelVolume({String? id, required String title, String? url, List<NovelChapterRef> chapters}); }`
  - `NovelSource.browseGroups` → `List<NovelBrowseGroup>`
  - `NovelSource.browse(String optionKey, {int page = 1})` → `Future<NovelList>`
  - `novelBrowseProvider` family key `(String sourceId, String optionKey, int page)`

- [ ] **Step 1: 替换模型类型**

编辑 `lib/core/novel/models.dart`。

(a) 把 `enum NovelBrowseKind { ranking, bunko }` 与 `class NovelBrowse { ... }`（第 66–72 行）整体替换为：

```dart
class NovelBrowseOption {
  final String key;
  final String label;
  const NovelBrowseOption({required this.key, required this.label});
}

class NovelBrowseGroup {
  final String label;
  final List<NovelBrowseOption> options;
  const NovelBrowseGroup({required this.label, required this.options});
}
```

(b) 给 `NovelVolume` 增加可选 `id`（供 lknovel 按卷拉取章节），把 `class NovelVolume { ... }` 替换为：

```dart
class NovelVolume {
  final String? id;
  final String title;
  final String? url;
  final List<NovelChapterRef> chapters;
  const NovelVolume({
    this.id,
    required this.title,
    this.url,
    this.chapters = const [],
  });
}
```

- [ ] **Step 2: 更新 `NovelSource` 接口**

编辑 `lib/core/novel/novel_source.dart`，把 `browse` 声明替换为 `browseGroups` + 新 `browse`：

```dart
  /// 该源声明的浏览分组（每个分组含若干选项）。
  List<NovelBrowseGroup> get browseGroups;

  /// 按浏览选项分页拉取书单。
  Future<NovelList> browse(String optionKey, {int page = 1});
```

（删除原 `Future<NovelList> browse(NovelBrowse browse, {int page = 1});`。`NovelSourceManager` 不变。）

- [ ] **Step 3: 更新 `LinovelibSource`**

编辑 `lib/core/novel/linovelib_source.dart`：在 `class LinovelibSource` 内、`static String rankPath(...)` 之前加入排行 key 集合，并把原 `browse` 方法替换为 `browseGroups` + 新 `browse`：

```dart
  static const Set<String> rankingKeys = {
    'allvisit', 'monthvisit', 'weekvisit', 'monthvote', 'weekvote',
    'monthflower', 'weekflower', 'monthegg', 'weekegg', 'lastupdate',
    'postdate', 'goodnum', 'newhot',
  };

  @override
  List<NovelBrowseGroup> get browseGroups => const [
        NovelBrowseGroup(label: '排行', options: [
          NovelBrowseOption(key: 'allvisit', label: '人气榜'),
          NovelBrowseOption(key: 'monthvisit', label: '月点击'),
          NovelBrowseOption(key: 'weekvisit', label: '周点击'),
          NovelBrowseOption(key: 'monthvote', label: '月推荐'),
          NovelBrowseOption(key: 'weekvote', label: '周推荐'),
          NovelBrowseOption(key: 'monthflower', label: '月鲜花'),
          NovelBrowseOption(key: 'weekflower', label: '周鲜花'),
          NovelBrowseOption(key: 'monthegg', label: '月鸡蛋'),
          NovelBrowseOption(key: 'weekegg', label: '周鸡蛋'),
          NovelBrowseOption(key: 'lastupdate', label: '最近更新'),
          NovelBrowseOption(key: 'postdate', label: '最新入库'),
          NovelBrowseOption(key: 'goodnum', label: '收藏榜'),
          NovelBrowseOption(key: 'newhot', label: '新书榜'),
        ]),
        NovelBrowseGroup(label: '文库', options: [
          NovelBrowseOption(key: 'dengekibunko', label: '电击'),
          NovelBrowseOption(key: 'fujimibunko', label: '富士见'),
          NovelBrowseOption(key: 'kadokawabunko', label: '角川'),
          NovelBrowseOption(key: 'emuefubunkojei', label: 'MF文库J'),
          NovelBrowseOption(key: 'famitsubunko', label: 'Fami通'),
          NovelBrowseOption(key: 'gagraphicbunko', label: 'GA'),
          NovelBrowseOption(key: 'hobbyjapanbunko', label: 'HJ'),
          NovelBrowseOption(key: 'ichijinsha', label: '一迅社'),
          NovelBrowseOption(key: 'shueisha', label: '集英社'),
          NovelBrowseOption(key: 'shogakukan', label: '小学馆'),
          NovelBrowseOption(key: 'kodansha', label: '讲谈社'),
          NovelBrowseOption(key: 'teenagebunko', label: '少女文库'),
          NovelBrowseOption(key: 'other', label: '其他文库'),
          NovelBrowseOption(key: 'chineselightnovel', label: '华文轻小说'),
        ]),
      ];

  @override
  Future<NovelList> browse(String optionKey, {int page = 1}) async {
    final isRanking = rankingKeys.contains(optionKey);
    final path =
        isRanking ? rankPath(optionKey, page) : bunkoPath(optionKey, page);
    final html = await _get(path);
    final items = isRanking ? parseRankRows(html) : parseBookList(html);
    final hasMore =
        hasPaginationControl(html) ? hasNextPage(html) : items.length >= 10;
    return NovelList(items: items, page: page, hasMore: hasMore);
  }
```

- [ ] **Step 4: 更新 `novelBrowseProvider`**

编辑 `lib/modules/novel/novel_providers.dart`，把 `novelBrowseProvider` 整段替换为：

```dart
final novelBrowseProvider =
    FutureProvider.family<NovelList, (String, String, int)>((ref, key) async {
  final (sourceId, optionKey, page) = key;
  final source = ref.watch(novelSourceManagerProvider).byId(sourceId);
  if (source == null) throw StateError('novel source $sourceId not found');
  return source.browse(optionKey, page: page);
});
```

- [ ] **Step 5: 重写首页 `novel_home.dart`**

用下面完整内容替换 `lib/modules/novel/novel_home.dart`（`NovelCard`、`_pager`、`_grid`、`_chip` 保持不变，删除 `_NovelSection`/`_rankingOptions`/`_bunkoOptions`）：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/novel/linovelib_source.dart';
import '../../core/novel/models.dart';
import '../../core/novel/novel_source.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../core/widgets/smooth_route.dart';
import 'novel_detail_page.dart';
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
                      httpHeaders: novelImageHeaders,
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

class NovelHomePage extends ConsumerStatefulWidget {
  const NovelHomePage({super.key});
  @override
  ConsumerState<NovelHomePage> createState() => _NovelHomePageState();
}

class _NovelHomePageState extends ConsumerState<NovelHomePage> {
  String _sourceId = 'linovelib';
  int _groupIndex = -1;
  int _optionIndex = 0;
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(novelSourcesProvider);
    final source = ref.watch(novelSourceManagerProvider).byId(_sourceId);
    final groups = source?.browseGroups ?? const <NovelBrowseGroup>[];
    return Column(
      children: [
        const SizedBox(height: 8),
        _sourceChips(sources),
        _sectionChips(groups),
        if (_groupIndex >= 0 && _groupIndex < groups.length)
          _optionChips(groups[_groupIndex]),
        Expanded(child: _body(groups)),
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
                _groupIndex = -1;
                _optionIndex = 0;
                _page = 1;
              })),
            ),
        ],
      ),
    );
  }

  Widget _sectionChips(List<NovelBrowseGroup> groups) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _chip('推荐', _groupIndex < 0, () => setState(() {
              _groupIndex = -1;
              _page = 1;
            })),
          ),
          for (var i = 0; i < groups.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _chip(groups[i].label, _groupIndex == i, () => setState(() {
                _groupIndex = i;
                _optionIndex = 0;
                _page = 1;
              })),
            ),
        ],
      ),
    );
  }

  Widget _optionChips(NovelBrowseGroup group) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (var i = 0; i < group.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _chip(group.options[i].label, _optionIndex == i, () => setState(() {
                _optionIndex = i;
                _page = 1;
              })),
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

  Widget _body(List<NovelBrowseGroup> groups) {
    if (_groupIndex < 0 || _groupIndex >= groups.length) {
      final async = ref.watch(novelHomeProvider(_sourceId));
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
          onAction: () => ref.invalidate(novelHomeProvider(_sourceId)),
        ),
        data: (home) => _grid(flattenHome(home)),
      );
    }
    final group = groups[_groupIndex];
    if (group.options.isEmpty) {
      return const EmptyState(icon: Icons.menu_book_rounded, message: '暂无内容');
    }
    final option = group.options[_optionIndex.clamp(0, group.options.length - 1)];
    final async = ref.watch(novelBrowseProvider((_sourceId, option.key, _page)));
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
        onAction: () =>
            ref.invalidate(novelBrowseProvider((_sourceId, option.key, _page))),
      ),
      data: (list) => Column(
        children: [
          Expanded(child: _grid(list.items)),
          _pager(list.hasMore),
        ],
      ),
    );
  }

  static final _pagerButtonStyle = OutlinedButton.styleFrom(
    minimumSize: const Size(84, 40),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  );

  Widget _pager(bool hasMore) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton(
            style: _pagerButtonStyle,
            onPressed: _page > 1 ? () => setState(() => _page--) : null,
            child: const Text('上一页'),
          ),
          const SizedBox(width: 16),
          Text('第 $_page 页',
              style: const TextStyle(fontSize: 13, color: _muted)),
          const SizedBox(width: 16),
          OutlinedButton(
            style: _pagerButtonStyle,
            onPressed: hasMore ? () => setState(() => _page++) : null,
            child: const Text('下一页'),
          ),
        ],
      ),
    );
  }

  Widget _grid(List<Novel> items) {
    if (items.isEmpty) {
      return const EmptyState(icon: Icons.menu_book_rounded, message: '暂无内容');
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6, mainAxisSpacing: 20, crossAxisSpacing: 16, childAspectRatio: 0.58),
      itemCount: items.length,
      itemBuilder: (_, i) => NovelCard(
        novel: items[i],
        onTap: () => Navigator.push(
          context,
          noTransitionRoute(NovelDetailPage(
            sourceKey: _sourceId,
            novelId: items[i].id,
            title: items[i].title,
            cover: items[i].coverUrl,
          )),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: 更新测试以适配新接口**

`test/core/novel/models_test.dart`：把 `test('NovelBrowse holds kind and key', ...)` 整个替换为：

```dart
  test('NovelBrowseGroup holds labeled options', () {
    const g = NovelBrowseGroup(label: '文库', options: [
      NovelBrowseOption(key: 'dengekibunko', label: '电击'),
    ]);
    expect(g.label, '文库');
    expect(g.options.single.key, 'dengekibunko');
    expect(g.options.single.label, '电击');
  });
```

`test/core/novel/novel_source_test.dart`：把 `_FakeSource` 里的 `browse` 覆写替换为：

```dart
  @override
  List<NovelBrowseGroup> get browseGroups => const [];
  @override
  Future<NovelList> browse(String optionKey, {int page = 1}) async =>
      NovelList(items: const [], page: page, hasMore: false);
```

`test/modules/novel/novel_home_pager_test.dart`：把 `_FakeSource` 里的 `browse` 覆写替换为：

```dart
  @override
  List<NovelBrowseGroup> get browseGroups => const [
        NovelBrowseGroup(label: '排行', options: [
          NovelBrowseOption(key: 'allvisit', label: '人气榜'),
        ]),
      ];
  @override
  Future<NovelList> browse(String optionKey, {int page = 1}) async =>
      NovelList(
        items: [for (var i = 0; i < 30; i++) Novel(id: '$i', title: 'Book$i')],
        page: page,
        hasMore: true,
      );
```

- [ ] **Step 7: 运行静态检查与测试**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: 全部通过（含 `novel_home_pager_test`、`novel_source_test`、`models_test`）。

- [ ] **Step 8: 提交**

```bash
git add lib/core/novel/models.dart lib/core/novel/novel_source.dart lib/core/novel/linovelib_source.dart lib/modules/novel/novel_providers.dart lib/modules/novel/novel_home.dart test/core/novel/models_test.dart test/core/novel/novel_source_test.dart test/modules/novel/novel_home_pager_test.dart
git commit -m "refactor(novel): source-declared browse groups"
git push origin dev
```

---

### Task 2: `LknovelSource` 客户端 + 解析器 + 首页/浏览 + 注册

新增 lknovel 书源的 JSON 客户端、纯解析函数、`home`/`browse`/`browseGroups`，并注册到 `NovelSourceManager`。`detail`/`chapter` 本任务先用 `UnimplementedError` 占位（Task 3 实现）。

**Files:**
- Create: `lib/core/novel/lknovel_source.dart`
- Modify: `lib/modules/novel/novel_providers.dart`
- Test: `test/core/novel/lknovel_source_test.dart`

**Interfaces:**
- Consumes: `NovelBrowseOption`、`NovelBrowseGroup`、`NovelSource`、`NovelHome`、`NovelList`、`Novel`、`NovelSection`（Task 1）。
- Produces:
  - `const String lknovelBaseUrl`
  - `typedef LkPoster = Future<Map<String, dynamic>> Function(String endpoint, Map<String, dynamic> body);`
  - `Map<String, dynamic> lkData(Map<String, dynamic> json)`
  - `Novel parseLkBook(Map<String, dynamic> json)`
  - `List<Novel> parseLkList(Map<String, dynamic> data)`
  - `bool lkHasMore(Map<String, dynamic> data, int page)`
  - `List<NovelVolume> parseLkVolumes(Map<String, dynamic> data)`
  - `List<NovelChapterRef> parseLkVolumeChapters(Map<String, dynamic> data)`
  - `NovelChapter parseLkChapter(Map<String, dynamic> data, String fallbackTitle)`
  - `class LknovelSource implements NovelSource`，构造 `LknovelSource({Dio? dio, LkPoster? poster})`，`id: 'lknovel'`，`name: '轻之国度'`
  - `LknovelSource.rankingKeys`、`LknovelSource.feedEndpoints`

- [ ] **Step 1: 写解析器与源的失败测试**

创建 `test/core/novel/lknovel_source_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/novel/lknovel_source.dart';
import 'package:acgnhub/core/novel/models.dart';

const _bookJson = {
  'book_id': 1338,
  'title': '败犬女主太多了！',
  'author_name': '雨森たきび',
  'cover_url': 'https://api.lightnovel.fun/x.jpg',
  'summary': '简介',
  'tags': ['轻小说', '校园'],
  'visible_tags': ['轻小说', '校园', '恋爱'],
  'chapter_count': 91,
  'volume_count': 13,
  'rank_position': 1,
};

const _feedData = {
  'scene': 'lightnovel_books',
  'list': [_bookJson],
  'pagination': {'page': 1, 'page_size': 30, 'total': 560, 'page_count': 19},
};

const _rankData = {
  'scene': 'weekly_hot',
  'list': [_bookJson],
  'pagination': {'page': 1, 'page_size': 30, 'total': 30, 'page_count': 2},
};

const _detailData = {
  'book_id': 1338,
  'title': '败犬女主太多了！',
  'author_name': '雨森たきび',
  'cover_url': 'https://api.lightnovel.fun/x.jpg',
  'summary': '简介',
  'tags': ['轻小说'],
  'volumes': [
    {'volume_id': 36754, 'title': '1卷', 'chapter_count': 2},
    {'volume_id': 36746, 'title': '1卷特典', 'chapter_count': 1},
  ],
};

const _chapterData = {
  'title': '一败目 专业青梅竹马',
  'body_snapshot': {
    'body_html':
        '<p class="ln-paragraph">第一段</p><img src="https://api.lightnovel.fun/a.jpg" /><p>第二段</p>',
  },
};

void main() {
  test('parseLkBook maps fields and dedupes tags', () {
    final n = parseLkBook(_bookJson);
    expect(n.id, '1338');
    expect(n.title, '败犬女主太多了！');
    expect(n.author, '雨森たきび');
    expect(n.coverUrl, 'https://api.lightnovel.fun/x.jpg');
    expect(n.tags, ['轻小说', '校园', '恋爱']);
    expect(n.summary, '简介');
    expect(n.extra['rank'], 1);
  });

  test('parseLkList reads data.list and data.cards', () {
    expect(parseLkList(_feedData).single.id, '1338');
    expect(parseLkList(const {'cards': [_bookJson]}).single.title, '败犬女主太多了！');
  });

  test('lkHasMore uses pagination.page_count', () {
    expect(lkHasMore(_feedData, 1), isTrue);
    expect(lkHasMore(_feedData, 19), isFalse);
  });

  test('parseLkVolumes reads volume ids and titles', () {
    final vols = parseLkVolumes(_detailData);
    expect(vols.map((v) => v.id), ['36754', '36746']);
    expect(vols.map((v) => v.title), ['1卷', '1卷特典']);
  });

  test('parseLkVolumeChapters reads chapter refs', () {
    final refs = parseLkVolumeChapters(const {
      'list': [
        {'chapter_id': 276838, 'title': '一败目'},
        {'chapter_id': 276839, 'title': '间章'},
      ],
    });
    expect(refs.map((c) => c.id), ['276838', '276839']);
    expect(refs.last.title, '间章');
  });

  test('parseLkChapter parses paragraphs and illustrations', () {
    final chapter = parseLkChapter(_chapterData, '');
    expect(chapter.title, '一败目 专业青梅竹马');
    expect(chapter.blocks.whereType<NovelText>().map((b) => b.text),
        ['第一段', '第二段']);
    expect(chapter.blocks.whereType<NovelImage>().single.url,
        'https://api.lightnovel.fun/a.jpg');
  });

  test('home builds sections from feeds', () async {
    final source = LknovelSource(poster: (endpoint, body) async {
      if (endpoint.contains('feed')) {
        return {'code': 0, 'data': _feedData};
      }
      throw Exception('unexpected endpoint: $endpoint');
    });
    final home = await source.home();
    expect(home.sections, isNotEmpty);
    expect(home.sections.first.items.single.title, '败犬女主太多了！');
  });

  test('browse ranking sends rank_scene', () async {
    Map<String, dynamic>? seen;
    final source = LknovelSource(poster: (endpoint, body) async {
      expect(endpoint, 'bff/book-rank-list-v1');
      seen = body;
      return {'code': 0, 'data': _rankData};
    });
    final list = await source.browse('weekly_hot', page: 1);
    expect(seen!['rank_scene'], 'weekly_hot');
    expect(list.items.single.id, '1338');
    expect(list.hasMore, isTrue);
  });

  test('browse category sends feed endpoint', () async {
    String? seenEndpoint;
    final source = LknovelSource(poster: (endpoint, body) async {
      seenEndpoint = endpoint;
      return {'code': 0, 'data': _feedData};
    });
    await source.browse('lightnovel', page: 2);
    expect(seenEndpoint, 'bff/home-lightnovel-feed-v1');
  });

  test('source identity and browse groups', () {
    final s = LknovelSource();
    expect(s.id, 'lknovel');
    expect(s.name, '轻之国度');
    expect(s.baseUrl, lknovelBaseUrl);
    expect(s.browseGroups.map((g) => g.label), ['排行', '分类']);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/lknovel_source_test.dart`
Expected: 编译失败（`lknovel_source.dart` 不存在 / `parseLkBook` 未定义）。

- [ ] **Step 3: 实现 `lib/core/novel/lknovel_source.dart`**

创建文件，内容如下（`detail`/`chapter` 暂为占位）：

```dart
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import 'models.dart';
import 'novel_source.dart';

const String lknovelBaseUrl = 'https://www.lightnovel.fun';
const String lknovelUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

typedef LkPoster = Future<Map<String, dynamic>> Function(
    String endpoint, Map<String, dynamic> body);

Map<String, dynamic> lkData(Map<String, dynamic> json) =>
    (json['data'] as Map?)?.cast<String, dynamic>() ?? const {};

int? _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

bool _asBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final t = v.toLowerCase();
    return t == '1' || t == 'true';
  }
  return false;
}

String? _nonEmpty(dynamic v) {
  final s = v?.toString();
  return (s == null || s.isEmpty) ? null : s;
}

List<String> _stringList(dynamic raw) {
  if (raw is List) {
    return [
      for (final e in raw)
        if (e != null && e.toString().isNotEmpty) e.toString(),
    ];
  }
  return const [];
}

Novel parseLkBook(Map<String, dynamic> json) {
  final tags = <String>[
    ..._stringList(json['visible_tags']),
    ..._stringList(json['tags']),
  ];
  final seen = <String>{};
  final uniq = [for (final t in tags) if (seen.add(t)) t];
  final rank = _asInt(json['rank_position']);
  return Novel(
    id: (json['book_id'] ?? json['id'])?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    author: _nonEmpty(json['author_name']),
    coverUrl: _nonEmpty(json['cover_url']),
    tags: uniq,
    summary: _nonEmpty(json['summary_short']) ?? _nonEmpty(json['summary']),
    extra: {
      if (rank != null && rank > 0) 'rank': rank,
    },
  );
}

List<Novel> parseLkList(Map<String, dynamic> data) {
  final raw = data['list'] ?? data['cards'];
  if (raw is! List) return const [];
  return [
    for (final e in raw)
      if (e is Map) parseLkBook(e.cast<String, dynamic>()),
  ];
}

bool lkHasMore(Map<String, dynamic> data, int page) {
  final p = data['pagination'];
  if (p is Map) {
    final pageCount = _asInt(p['page_count']);
    if (pageCount != null) return page < pageCount;
    final flag = p['has_more'] ?? p['hasMore'];
    if (flag != null) return _asBool(flag);
  }
  final info = data['page_info'];
  if (info is Map) {
    final next = _asInt(info['next']);
    if (next != null) return next > 0;
    final flag = info['has_next'] ?? info['hasNext'];
    if (flag != null) return _asBool(flag);
  }
  return parseLkList(data).length >= 30;
}

List<NovelVolume> parseLkVolumes(Map<String, dynamic> data) {
  final raw = data['volumes'] ?? data['list'];
  if (raw is! List) return const [];
  final out = <NovelVolume>[];
  for (final e in raw) {
    if (e is! Map) continue;
    final v = e.cast<String, dynamic>();
    out.add(NovelVolume(
      id: (v['volume_id'] ?? v['id'])?.toString(),
      title: v['title']?.toString() ?? '',
    ));
  }
  return out;
}

List<NovelChapterRef> parseLkVolumeChapters(Map<String, dynamic> data) {
  final raw = data['list'];
  if (raw is! List) return const [];
  final out = <NovelChapterRef>[];
  for (final e in raw) {
    if (e is! Map) continue;
    final c = e.cast<String, dynamic>();
    final id = (c['chapter_id'] ?? c['id'])?.toString() ?? '';
    if (id.isEmpty) continue;
    out.add(NovelChapterRef(id: id, title: c['title']?.toString() ?? ''));
  }
  return out;
}

NovelChapter parseLkChapter(Map<String, dynamic> data, String fallbackTitle) {
  final title = _nonEmpty(data['title']) ?? fallbackTitle;
  final snapshot = data['body_snapshot'];
  final html =
      (snapshot is Map ? snapshot['body_html'] : null)?.toString() ?? '';
  final blocks = <NovelBlock>[];
  if (html.isNotEmpty) {
    final doc = html_parser.parse(html);
    for (final el in doc.querySelectorAll('p, img')) {
      if (el.localName == 'p') {
        final t = el.text.trim();
        if (t.isNotEmpty) blocks.add(NovelText(t));
      } else {
        final src = el.attributes['src'] ?? el.attributes['data-src'];
        if (src != null && src.isNotEmpty) blocks.add(NovelImage(src));
      }
    }
  }
  return NovelChapter(title: title, blocks: blocks);
}

class LknovelSource implements NovelSource {
  LknovelSource({Dio? dio, LkPoster? poster})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: lknovelBaseUrl,
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 20),
              headers: {
                'User-Agent': lknovelUserAgent,
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                'Referer': '$lknovelBaseUrl/',
              },
            )),
        _poster = poster;

  final Dio _dio;
  final LkPoster? _poster;

  @override
  String get id => 'lknovel';

  @override
  String get name => '轻之国度';

  @override
  String get baseUrl => lknovelBaseUrl;

  static const List<String> rankingKeys = [
    'weekly_hot',
    'daily_hot',
    'daily_fresh',
    'weekly_fresh',
  ];

  static const Map<String, String> feedEndpoints = {
    'lightnovel': 'bff/home-lightnovel-feed-v1',
    'original': 'bff/home-original-feed-v1',
    'fanfic': 'bff/home-fanfic-feed-v1',
    'recent_updates': 'bff/home-recent-updates-feed-v1',
    'new_books': 'bff/home-feed-v1',
  };

  @override
  List<NovelBrowseGroup> get browseGroups => const [
        NovelBrowseGroup(label: '排行', options: [
          NovelBrowseOption(key: 'weekly_hot', label: '综合热度'),
          NovelBrowseOption(key: 'daily_hot', label: '日热度'),
          NovelBrowseOption(key: 'daily_fresh', label: '日新书'),
          NovelBrowseOption(key: 'weekly_fresh', label: '周新书'),
        ]),
        NovelBrowseGroup(label: '分类', options: [
          NovelBrowseOption(key: 'lightnovel', label: '轻小说'),
          NovelBrowseOption(key: 'original', label: '原创'),
          NovelBrowseOption(key: 'fanfic', label: '同人'),
          NovelBrowseOption(key: 'recent_updates', label: '最近更新'),
          NovelBrowseOption(key: 'new_books', label: '新书'),
        ]),
      ];

  Future<Map<String, dynamic>> _post(
      String endpoint, Map<String, dynamic> body) {
    final poster = _poster;
    if (poster != null) return poster(endpoint, body);
    return _httpPost(endpoint, body);
  }

  Future<Map<String, dynamic>> _httpPost(
      String endpoint, Map<String, dynamic> body) async {
    final res =
        await _dio.post<dynamic>('/api/pc-proxy/api/$endpoint', data: body);
    final raw = res.data;
    if (raw is! Map) throw Exception('lknovel 响应格式错误：$endpoint');
    final map = raw.cast<String, dynamic>();
    if (map['code'] != 0) {
      throw Exception('lknovel 请求失败：$endpoint (code=${map['code']})');
    }
    return map;
  }

  @override
  Future<NovelHome> home() async {
    const feeds = [
      ('轻小说', 'bff/home-lightnovel-feed-v1'),
      ('原创', 'bff/home-original-feed-v1'),
      ('同人', 'bff/home-fanfic-feed-v1'),
      ('最近更新', 'bff/home-recent-updates-feed-v1'),
    ];
    final sections = await Future.wait(feeds.map((f) async {
      try {
        final json =
            await _post(f.$2, {'page': 1, 'page_size': 20, 'pageSize': 20});
        return NovelSection(title: f.$1, items: parseLkList(lkData(json)));
      } catch (_) {
        return NovelSection(title: f.$1, items: const []);
      }
    }));
    final nonEmpty = [for (final s in sections) if (s.items.isNotEmpty) s];
    if (nonEmpty.isEmpty) throw Exception('lknovel 首页解析为空');
    return NovelHome(sections: nonEmpty);
  }

  @override
  Future<NovelList> browse(String optionKey, {int page = 1}) async {
    final Map<String, dynamic> json;
    if (rankingKeys.contains(optionKey)) {
      json = await _post('bff/book-rank-list-v1', {
        'rank_scene': optionKey,
        'page': page,
        'page_size': 30,
        'pageSize': 30,
      });
    } else {
      final endpoint = feedEndpoints[optionKey];
      if (endpoint == null) {
        throw ArgumentError('unknown browse option: $optionKey');
      }
      json = await _post(
          endpoint, {'page': page, 'page_size': 30, 'pageSize': 30});
    }
    final data = lkData(json);
    return NovelList(
      items: parseLkList(data),
      page: page,
      hasMore: lkHasMore(data, page),
    );
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

- [ ] **Step 4: 注册书源**

编辑 `lib/modules/novel/novel_providers.dart`：加入 import

```dart
import '../../core/novel/lknovel_source.dart';
```

并把 `novelSourceManagerProvider` 改为：

```dart
final novelSourceManagerProvider = Provider<NovelSourceManager>(
  (ref) => NovelSourceManager(sources: [LinovelibSource(), LknovelSource()]),
);
```

- [ ] **Step 5: 运行静态检查与测试**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/lknovel_source_test.dart`
Expected: 全部通过。

- [ ] **Step 6: 提交**

```bash
git add lib/core/novel/lknovel_source.dart lib/modules/novel/novel_providers.dart test/core/novel/lknovel_source_test.dart
git commit -m "feat(novel): add lknovel source with home and browse"
git push origin dev
```

---

### Task 3: lknovel 详情目录与章节正文

给 `LknovelSource` 实现 `detail`（书信息 + 各卷章节，限并发拉取）与 `chapter`（正文 HTML → 文字/插图块）。

**Files:**
- Modify: `lib/core/novel/lknovel_source.dart`
- Test: `test/core/novel/lknovel_source_test.dart`

**Interfaces:**
- Consumes: `parseLkVolumes`、`parseLkVolumeChapters`、`parseLkChapter`、`lkData`、`lkHasMore`、`LknovelSource._post`（Task 2）；`NovelVolume.id`（Task 1）。
- Produces:
  - `LknovelSource.detail(String id)` → `Future<NovelDetail>`（书信息 + 全部卷章节）
  - `LknovelSource.chapter(String novelId, String chapterId)` → `Future<NovelChapter>`

- [ ] **Step 1: 写 `detail`/`chapter` 的失败测试**

在 `test/core/novel/lknovel_source_test.dart` 的 `main()` 末尾（最后一个 `test` 之后）追加：

```dart
  test('detail loads every volume and its chapters', () async {
    final source = LknovelSource(poster: (endpoint, body) async {
      switch (endpoint) {
        case 'new-content-read/get-book-detail':
          return {'code': 0, 'data': _detailData};
        case 'new-content-read/get-volume-chapters':
          final vid = body['volume_id'].toString();
          return {
            'code': 0,
            'data': {
              'volume_id': vid,
              'list': vid == '36754'
                  ? [
                      {'chapter_id': 276838, 'title': '一败目'},
                      {'chapter_id': 276839, 'title': '间章'},
                    ]
                  : [
                      {'chapter_id': 276788, 'title': '特典'},
                    ],
            },
          };
      }
      throw Exception('unexpected endpoint: $endpoint');
    });
    final detail = await source.detail('1338');
    expect(detail.novel.title, '败犬女主太多了！');
    expect(detail.volumes.map((v) => v.title), ['1卷', '1卷特典']);
    expect(detail.volumes.first.chapters.map((c) => c.id), ['276838', '276839']);
    expect(detail.volumes.last.chapters.single.title, '特典');
  });

  test('chapter fetches and parses chapter detail', () async {
    final source = LknovelSource(poster: (endpoint, body) async {
      expect(endpoint, 'new-content-read/get-chapter-detail');
      expect(body['book_id'], '1338');
      expect(body['chapter_id'], '276838');
      return {'code': 0, 'data': _chapterData};
    });
    final chapter = await source.chapter('1338', '276838');
    expect(chapter.title, '一败目 专业青梅竹马');
    expect(chapter.blocks.whereType<NovelText>().length, 2);
    expect(chapter.blocks.whereType<NovelImage>().single.url,
        'https://api.lightnovel.fun/a.jpg');
  });
```

- [ ] **Step 2: 运行测试确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/lknovel_source_test.dart`
Expected: `detail`/`chapter` 抛 `UnimplementedError` → 用例失败。

- [ ] **Step 3: 实现 `detail` 与 `chapter`**

编辑 `lib/core/novel/lknovel_source.dart`，把末尾两个占位方法：

```dart
  @override
  Future<NovelDetail> detail(String id) => throw UnimplementedError();

  @override
  Future<NovelChapter> chapter(String novelId, String chapterId) =>
      throw UnimplementedError();
```

替换为：

```dart
  @override
  Future<NovelDetail> detail(String id) async {
    final json = await _post(
        'new-content-read/get-book-detail', {'book_id': id, 'with_volumes': 1});
    final data = lkData(json);
    final novel = parseLkBook(data);
    final metas = parseLkVolumes(data);
    const batchSize = 6;
    final volumes = <NovelVolume>[];
    for (var i = 0; i < metas.length; i += batchSize) {
      final end = (i + batchSize).clamp(0, metas.length);
      final batch = metas.sublist(i, end);
      final loaded = await Future.wait(batch.map((v) async {
        try {
          final chapters = await _volumeChapters(id, v.id ?? '');
          return NovelVolume(id: v.id, title: v.title, chapters: chapters);
        } catch (_) {
          return NovelVolume(id: v.id, title: v.title, chapters: const []);
        }
      }));
      volumes.addAll(loaded);
    }
    return NovelDetail(novel: novel, volumes: volumes);
  }

  Future<List<NovelChapterRef>> _volumeChapters(
      String bookId, String volumeId) async {
    final out = <NovelChapterRef>[];
    var page = 1;
    while (true) {
      final json = await _post('new-content-read/get-volume-chapters', {
        'book_id': bookId,
        'volume_id': volumeId,
        'page': page,
        'page_size': 50,
        'pageSize': 50,
      });
      final data = lkData(json);
      out.addAll(parseLkVolumeChapters(data));
      if (!lkHasMore(data, page) || page >= 100) break;
      page++;
    }
    return out;
  }

  @override
  Future<NovelChapter> chapter(String novelId, String chapterId) async {
    final json = await _post('new-content-read/get-chapter-detail',
        {'book_id': novelId, 'chapter_id': chapterId});
    return parseLkChapter(lkData(json), '');
  }
```

- [ ] **Step 4: 运行静态检查与测试**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: 全部通过（含新增 `detail`/`chapter` 用例）。

- [ ] **Step 5: 提交**

```bash
git add lib/core/novel/lknovel_source.dart test/core/novel/lknovel_source_test.dart
git commit -m "feat(novel): lknovel detail catalog and chapter reader"
git push origin dev
```

---

## 验证（任务全部完成后）

1. `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` 全绿。
2. 构建并启动应用，切到轻小说模块：
   - 源 chips 出现「哔哩轻小说」「轻之国度」。
   - 选「轻之国度」→「推荐」显示 4 个书单区块（轻小说/原创/同人/最近更新）。
   - 切「排行」→ 综合热度/日热度/日新书/周新书；切「分类」→ 轻小说/原创/同人/最近更新/新书；分页可翻页。
   - 点开一本书 → 详情显示封面/简介/分卷目录；点章节进入阅读器，正文与插图正常，上一/下一章与目录可用。
   - 切回「哔哩轻小说」→ 排行/文库与之前一致（回归）。

## 已知取舍

- lknovel 目录为懒加载接口，`detail` 需按卷并发请求（限并发 6），大型系列书首次进入详情会略慢；单卷失败仅该卷留空。
- 搜索未实现（界面无搜索框）。
