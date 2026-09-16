# 漫画/轻小说/游戏 内容切换左右滑动过渡设计

日期：2026-09-15
状态：已与用户确认

## 背景

动漫首页切换顶部 Tab 时，内容左右滑动。漫画/轻小说/游戏的**源/分区/子分类 chip 切换**以及**翻页**时，下方网格是瞬间替换、无过渡。用户希望这些内容切换也有左右滑动过渡（参考动漫 Tab 切换的效果），且**底部分页栏固定不动，只滑网格**。

## 目标

- 新增可复用组件 `SlideSwitcher`：内容标识变化时，旧内容向一侧滑出、新内容从另一侧滑入。
- 接入漫画发现页、轻小说探索页、游戏首页：切源/分区/子分类/**翻页**都触发过渡。
- 过渡期间**分页栏不参与**（保持在原位）。

## 非目标

- 不改顶部 Tab（发现/收藏/历史、探索/收藏/历史）——它们已是 `TabBarView` 左右滑动。
- 不改动漫/漫画详情页的 Tab。
- 不引入拖拽跟手（仅点击 chip/分页按钮触发）。

## 组件（`lib/core/widgets/slide_switcher.dart`）

```dart
class SlideSwitcher extends StatefulWidget {
  final Object id;      // 内容标识；变化触发过渡
  final int index;      // 方向：变大=从右进、向左出；变小=从左进、向右出
  final Widget child;
  final Duration duration; // 默认 250ms
  const SlideSwitcher({
    super.key,
    required this.id,
    required this.index,
    required this.child,
    this.duration = const Duration(milliseconds: 250),
  });
  @override
  State<SlideSwitcher> createState() => _SlideSwitcherState();
}

class _SlideSwitcherState extends State<SlideSwitcher> {
  bool _forward = true;

  @override
  void didUpdateWidget(SlideSwitcher old) {
    super.didUpdateWidget(old);
    if (widget.index != old.index) {
      _forward = widget.index > old.index;
    } else if (widget.id != old.id) {
      _forward = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: widget.duration,
      switchInCurve: Curves.easeInOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        fit: StackFit.expand,
        children: [
          for (final child in previousChildren)
            HeroMode(enabled: false, child: child),
          if (currentChild != null) currentChild,
        ],
      ),
      transitionBuilder: (child, animation) {
        final incoming = child.key == ValueKey(widget.id);
        final dir = incoming
            ? (_forward ? 1.0 : -1.0)
            : (_forward ? -1.0 : 1.0);
        return SlideTransition(
          position: Tween<Offset>(begin: Offset(dir, 0), end: Offset.zero)
              .animate(animation),
          child: child,
        );
      },
      child: KeyedSubtree(key: ValueKey(widget.id), child: widget.child),
    );
  }
}
```

- 入场元素从 `dir` 滑到 0；出场元素（`animation` 反向 1→0）从 0 滑到相反的 `dir`。
- `id` 相同而仅内容重建（如加载中→数据到达）不触发过渡。

## 接入

> **关键**：`SlideSwitcher` 必须包住**整个 `async.when`**（loading/error/data），这样切换时它保持挂载、`didUpdateWidget` 才能触发滑动；数据到达后 `id` 不变、原地替换。分页栏作为同级兄弟放在 `SlideSwitcher` 之外，保持固定。（若只包 `data:` 分支，切换时 provider 变 loading、`data:` 分支被骨架屏替换 → `SlideSwitcher` 被卸载 → 不播放动画。）

### 游戏（`lib/modules/game/game_home.dart`）

`_body`：

```dart
    final sourceIndex =
        ref.watch(gameSourcesProvider).indexWhere((s) => s.id == _sourceId);
    final option = options[_optionIndex.clamp(0, options.length - 1)];
    final key = (_sourceId, option.key, _page);
    final async = ref.watch(gameBrowseProvider(key));
    final pageData = async.valueOrNull;
    return Column(
      children: [
        Expanded(
          child: SlideSwitcher(
            id: key,
            index: sourceIndex * 10000 + _optionIndex * 100 + _page,
            child: async.when(
              loading: () => ...现有骨架屏...,
              error: (_, __) => ...现有 EmptyState...,
              data: (list) => _grid(list.items),
            ),
          ),
        ),
        if (pageData != null) _pager(pageData.hasMore),
      ],
    );
```

- `_pager` 在 `SlideSwitcher` 之外 → 固定不动。

### 轻小说（`lib/modules/novel/novel_home.dart` 的 `_ExploreTabState._body`）

- 顶部：`final sourceIndex = ref.watch(novelSourcesProvider).indexWhere((s) => s.id == _sourceId);`
- **两个分支必须返回相同形状**（`Column` 的首个子元素是 `Expanded(child: SlideSwitcher(...))`），否则 `_groupIndex` 在 `-1` 与 `>=0` 间切换时子元素 runtimeType 变化 → `SlideSwitcher` 被重建 → 不滑动。
- 「推荐」分支（`_groupIndex < 0`）：

```dart
      final async = ref.watch(novelHomeProvider(_sourceId));
      return Column(
        children: [
          Expanded(
            child: SlideSwitcher(
              id: (_sourceId, '__home__'),
              index: sourceIndex * 1000000,
              child: async.when(
                loading: () => ...骨架屏...,
                error: (_, __) => ...失败...,
                data: (home) => _grid(flattenHome(home)),
              ),
            ),
          ),
        ],
      );
```

- 分组分支：

```dart
      final option = group.options[_optionIndex.clamp(0, group.options.length - 1)];
      final async = ref.watch(novelBrowseProvider((_sourceId, option.key, _page)));
      final pageData = async.valueOrNull;
      return Column(
        children: [
          Expanded(
            child: SlideSwitcher(
              id: (_sourceId, option.key, _page),
              index: sourceIndex * 1000000 +
                  (_groupIndex + 1) * 10000 +
                  _optionIndex * 100 +
                  _page,
              child: async.when(
                loading: () => ...骨架屏...,
                error: (_, __) => ...失败...,
                data: (list) => _grid(list.items),
              ),
            ),
          ),
          if (pageData != null) _pager(pageData.hasMore),
        ],
      );
```

- `_pager` 在 `SlideSwitcher` 之外 → 固定不动。

### 漫画（`lib/modules/comic/comic_home.dart` 的 `_DiscoverTabState._explore`）

- `_explore` 增加 `int sourceIndex` 参数，由 `_DiscoverTabState.build` 用 `sources.indexOf(selected)` 传入。
- 结构：

```dart
    final pageData = async.valueOrNull;
    return Column(
      children: [
        Expanded(
          child: SlideSwitcher(
            id: (source.key, section, part, _page),
            index: sourceIndex * 1000000 +
                section * 10000 +
                part * 100 +
                _page,
            child: async.when(
              loading: () => const ShimmerLoader(...),
              error: (_, __) => EmptyState(...),
              data: (data) { ... },
            ),
          ),
        ),
        if (pageData != null && (pageData.hasNext || pageData.page > 1))
          _paginationBar(pageData),
      ],
    );
```

- `_paginationBar` 在 `SlideSwitcher` 之外 → 固定不动（显示条件与现状一致）。

## 方向规则

- 切换到大索引（更靠右的 chip、下一页）→ 新内容从右滑入、旧内容向左滑出。
- 切换到小索引（更靠左的 chip、上一页）→ 新内容从左滑入、旧内容向右滑出。

## 错误处理 / 边界

- 新内容未缓存 → 先滑入 `ShimmerLoader`/`EmptyState`，数据到达后原地替换（`id` 不变，不重复过渡）。
- `id` 不含页码以外的临时状态；加载→数据不算切换。

## 测试

- 新增 `test/core/widgets/slide_switcher_test.dart`：
  - index 增大时出现 `SlideTransition` 且新内容从右侧进入（起始 `Offset` 的 dx > 0）；
  - index 减小时从左侧进入（dx < 0）；
  - 动画结束后只剩新内容（旧 child 被移除）；
  - `id` 相同、内容重建不触发过渡。
- 回归：`comic`/`novel`/`game` 首页现有 widget 测试（切 chip、翻页仍工作）。

## 后续迭代（不在本版）

- 支持拖拽跟手（PageView 式）切换。
- 顶部 Tab 与 chip 过渡的统一。
