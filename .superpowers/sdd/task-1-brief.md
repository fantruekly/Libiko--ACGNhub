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
