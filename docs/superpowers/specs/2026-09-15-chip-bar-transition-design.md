# 副选择栏滑动高亮过渡设计

日期：2026-09-15
状态：已与用户确认
前置：`docs/superpowers/specs/2026-09-14-novel-ui-fixes-design.md`（`TabStrip` 指示条）、`2026-09-14-novel-search-design.md`

## 背景与目标

轻小说页（`lib/modules/novel/novel_home.dart`）和漫画页（`lib/modules/comic/comic_home.dart`）的**副选择栏**（源 / 分区 / 选项 / 分卷）目前用一排 `PillChip`：选中项直接切换蓝底白字，没有过渡。

本增量给这些副选择栏加入**滑动高亮过渡**：未选中的 chip 变为纯文字，一个蓝色高亮药丸在 chip 之间平滑滑动，视觉与顶部 `TabStrip` 的指示条一致。

## 非目标

- 不改内容区（网格 / 骨架屏）的加载过渡。
- 不做选中项自动滚动入视（点击的 chip 必然可见）。
- 不改顶部 `TabStrip` 本身。
- 不改 chip 的宽度/字号/间距规则。

## 组件：新增 `lib/core/widgets/chip_bar.dart`

```dart
class ChipBar extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final EdgeInsetsGeometry padding; // 默认 EdgeInsets.symmetric(horizontal: 16)
  const ChipBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });
}
```

### 布局

```
SizedBox(height: 48)
└─ ScrollConfiguration(dragDevices: touch/mouse/trackpad/stylus)
   └─ SingleChildScrollView(scrollDirection: horizontal, padding: padding)
      └─ Stack(alignment: centerLeft)
         ├─ AnimatedPositioned(left: 选中 chip 的 x, top: 6, width: 选中 chip 的宽, height: 36)
         │  └─ 蓝色药丸（Color(0xFF007AFF)，圆角 16）
         └─ Row(children: [每个 chip])
```

- chip 宽度：`TextPainter` 量 `TextStyle(fontSize: 15, fontWeight: w500)` 的文字宽度 + 左右各 15，向上取整（沿用 `PillChip` 现有算法，保证宽度不随选中态变化）。
- chip 间距：每个 chip 右侧 `Padding(right: 10)`（最后一个也保留，与原实现一致）。
- 每个 chip：`GestureDetector(behavior: opaque)` → `SizedBox(width, height: 48)` → `Center(AnimatedDefaultTextStyle(...))`。
- 文字样式：`fontSize: 15, fontWeight: w500`，选中 `Colors.white`，未选中 `Color(0xFF5A5A5F)`。

### 动画

- 药丸位置与宽度：`AnimatedPositioned`，`duration: 220ms`，`curve: Curves.easeInOutCubic`。
- 文字颜色：每个 chip 的 `AnimatedDefaultTextStyle`，`duration: 220ms`。
- **选择切换 → 滑动；整行切换 → 跳变**：父级用 `key: ValueKey(labels.join('|'))` 实例化 `ChipBar`。标签列表变化时 key 变化 → 重建，药丸直接出现在新位置（不横跨两行滑动）；标签不变、仅 `selectedIndex` 变化时复用同一 state → 播放滑动动画。

### 边界

- `labels` 为空 → 返回 `SizedBox.shrink()`。
- 只有一个 label → 正常渲染药丸（不特殊处理）。
- `selectedIndex` 越界时按 `clamp(0, labels.length - 1)` 处理。

## 替换点

### 漫画页 `lib/modules/comic/comic_home.dart`

- `_sourceHeader`：`Expanded` 内的源 chips（`_sourceChip`/`_chip`）→ `ChipBar(labels: [源名...], selectedIndex: 选中源下标, onSelected: ...)`；右侧"源管理"`IconButton` 保持不变。
- `_sectionChips` → `ChipBar`（`source.sections` 的标题，空标题回退 `'分区 N'`）。
- `_partChips` → `ChipBar`（`parts` 的标题，空标题回退 `'分区 N'`）。
- 删除 `_chip` 辅助方法与对 `PillChip` 的引用。

### 轻小说页 `lib/modules/novel/novel_home.dart`

- `_sourceChips` → `ChipBar`（`sources` 的 `name`）。
- `_sectionChips` → `ChipBar`（`['推荐', ...groups.map((g) => g.label)]`，`selectedIndex = _groupIndex + 1`）。
- `_optionChips` → `ChipBar`（`group.options` 的 `label`）。
- 删除 `_chip` 辅助方法与对 `PillChip` 的引用。

### 清理

- `lib/core/widgets/pill_chip.dart` 在替换后不再被任何代码引用 → 删除。

## 错误处理

无网络/错误路径不变（本次仅改选择栏的渲染与动画）。

## 测试

- 新增 `test/core/widgets/chip_bar_test.dart`：
  - 渲染全部 `labels`；
  - 点击第 i 个 chip 触发 `onSelected(i)`；
  - 药丸存在（`AnimatedPositioned`）；
  - 改变 `selectedIndex` 后，`AnimatedPositioned` 的 `left`/`width` 指向新 chip 的几何（`pump` 到动画结束后断言）。
- 现有测试（265 个）保持通过；`novel_home` / `comic_home` 相关的现有 widget 测试若引用了 `PillChip` 需相应更新（当前无）。

## 后续迭代

1. 内容区切换时的淡入/滑动过渡。
2. 选中项自动滚动入视（当副选择栏项很多时）。
