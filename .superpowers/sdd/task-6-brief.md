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