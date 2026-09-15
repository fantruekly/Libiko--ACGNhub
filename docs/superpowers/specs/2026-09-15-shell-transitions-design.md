# 侧栏与板块切换过渡设计

日期：2026-09-15
状态：已与用户确认
前置：`docs/superpowers/specs/2026-09-15-chip-bar-transition-design.md`（同类过渡先例）

## 背景与目标

侧栏（`lib/shell/app_sidebar.dart`）目前的按钮文字偏小（11px）且未选中的字重偏轻（`w400`），与界面其它文字不统一；选中态的左侧蓝线（`Border(left: 3px)`）是瞬间出现，没有过渡；切换板块时 `IndexedStack`（`lib/shell/main_shell.dart`）直接换页，没有整体过渡。

本增量：

1. 侧栏按钮文字与界面统一并稍微调大。
2. 左侧选中线条加入动效（展开 + 淡入）。
3. 板块切换加入整体交叉淡入淡出过渡。

## 非目标

- 不改侧栏图标大小、项间距、折叠动画（`AnimatedContainer` 300ms）。
- 不给板块切换加滑动/缩放。
- 不改各模块内部的 Tab/内容过渡。

## 1. 侧栏文字

`lib/shell/app_sidebar.dart` 的 `_SidebarItem` 内 `Text` 样式：

| 属性 | 现在 | 改为 |
|---|---|---|
| `fontSize` | 11 | **13** |
| `fontWeight` | 选中 `w600` / 未选中 `w400` | 选中 `w600` / 未选中 **`w500`** |
| `height` | 1.5 | **1.4** |
| `letterSpacing` | 0.02 | **移除** |

字体族不变（`TextStyle` 不设 `fontFamily`，继承主题 `NotoSansSC`）。

## 2. 左侧线条动效

- 去掉 `_SidebarItem` 的 `decoration.border`，改为在项内用 `Stack` 叠加一条 3px 宽、通高的强调色线条（`Color(0xFF007AFF)`）：
  `Positioned(left: 0, top: 0, bottom: 0, child: Opacity(... Transform.scale(... Container(width: 3, color: _accent))))`（`top`/`bottom` 约束给它通高）。
- 用 `TweenAnimationBuilder<double>` 驱动一个 0↔1 的进度 `t`：
  - `tween: Tween(begin: selected ? 1.0 : 0.0, end: selected ? 1.0 : 0.0)`（首帧不播放动画，之后 `end` 变化时从当前值过渡）
  - `duration: 200ms`，`curve: Curves.easeInOutCubic`
- `builder` 中：
  - 线条：`Opacity(opacity: t, child: Transform.scale(scaleY: t, alignment: Alignment.center, child: 线条))` —— 从中间向上下展开 + 淡入。
  - 图标与文字颜色：`Color.lerp(未选中灰, 选中蓝, t)`，让颜色与线条同步过渡。
- 未选中色保持现状语义：图标 `_fg.withValues(alpha: 0.35)`、文字 `_fg.withValues(alpha: 0.45)`；选中色 `_accent`。
- **不要**用 `AnimatedDefaultTextStyle`（它会替换继承的字体样式，导致丢字体；文字颜色用 `Text(style: TextStyle(color: ...))` 即可，`Text` 会与上层 `DefaultTextStyle` 合并）。

## 3. 板块切换过渡

`lib/shell/main_shell.dart` 把：

```dart
Expanded(
  child: IndexedStack(index: _currentIndex, children: _pages),
),
```

替换为：

```dart
Expanded(
  child: Stack(
    fit: StackFit.expand,
    children: [
      for (var i = 0; i < _pages.length; i++)
        IgnorePointer(
          ignoring: i != _currentIndex,
          child: AnimatedOpacity(
            opacity: i == _currentIndex ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _pages[i],
          ),
        ),
    ],
  ),
),
```

- 所有板块始终挂载（与 `IndexedStack` 一致），滚动位置与各 Tab 状态不丢。
- 切换时旧的 `opacity` 1→0、新的 0→1 同时进行（交叉淡入淡出）。
- 非当前页 `Opacity == 0` 时 Flutter 跳过绘制，开销可接受。

## 测试

- `test/shell/app_sidebar_test.dart`（新建）：
  - 渲染 `动漫/漫画/轻小说/游戏/设置` 五个标签；
  - 选中项的标签字号为 13；
  - 未选中项没有选中线条（`Opacity`/`Transform` 目标为 0），选中项有（目标为 1）。
- `test/shell/main_shell_test.dart`（新建）：
  - `SharedPreferences.setMockInitialValues({})` 后 pump `MainShell`（`ProviderScope` + `MaterialApp`）；
  - 断言初始时 index 0 板块的 `AnimatedOpacity.opacity == 1`、其余为 0；
  - 点侧栏「漫画」后，index 1 板块的目标 `opacity == 1`、index 0 为 0（验证接线与过渡，且所有板块仍在树中）。

## 后续迭代

1. 若板块切换想更明显，可在此 `Stack` 上叠加轻微位移。
2. 侧栏图标在选中/未选中间做尺寸或颜色动画。
