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
          ...previousChildren,
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

### 游戏（`lib/modules/game/game_home.dart`）

`_body` 的 `data` 分支：

```dart
      data: (list) => Column(
        children: [
          Expanded(
            child: SlideSwitcher(
              id: (_sourceId, option.key, _page),
              index: sourceIndex * 10000 + _optionIndex * 100 + _page,
              child: _grid(list.items),
            ),
          ),
          _pager(list.hasMore),
        ],
      ),
```

- `sourceIndex` = `ref.watch(gameSourcesProvider).indexWhere((s) => s.id == _sourceId)`（在 `_body` 内计算）。
- `_pager` 在 `SlideSwitcher` 之外 → 固定不动。

### 轻小说（`lib/modules/novel/novel_home.dart` 的 `_ExploreTabState._body`）

分组/选项数据分支：

```dart
      data: (list) => Column(
        children: [
          Expanded(
            child: SlideSwitcher(
              id: (_sourceId, option.key, _page),
              index: sourceIndex * 1000000 +
                  (_groupIndex + 1) * 10000 +
                  _optionIndex * 100 +
                  _page,
              child: _grid(list.items),
            ),
          ),
          _pager(list.hasMore),
        ],
      ),
```

- `sourceIndex` = `ref.watch(novelSourcesProvider).indexWhere((s) => s.id == _sourceId)`。
- 「推荐」分组（`_groupIndex == -1`，走 `novelHomeProvider`）也包一层 `SlideSwitcher`：`id: (_sourceId, '__home__')`，`index: sourceIndex * 1000000`。
- `_pager` 固定不动。

### 漫画（`lib/modules/comic/comic_home.dart` 的 `_DiscoverTabState._explore`）

```dart
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

- `_explore` 增加 `int sourceIndex` 参数，由 `_DiscoverTabState.build` 用 `sources.indexOf(selected)` 传入（`sources` 在该处已取得）。
- `_paginationBar` 在 `SlideSwitcher` 之外 → 固定不动。

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
