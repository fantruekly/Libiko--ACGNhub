# 侧栏与板块切换过渡 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 侧栏按钮文字统一为 13px；选中项左侧线条做「展开 + 淡入」动效；板块切换做整体交叉淡入淡出，且各板块状态不丢。

**Architecture:** `_SidebarItem` 内用 `TweenAnimationBuilder<double>`（0↔1）同时驱动左侧线条的 `scaleY`/`Opacity` 与图标/文字颜色；`MainShell` 把 `IndexedStack` 换成 `Stack` + 每页 `IgnorePointer` + `AnimatedOpacity`，所有页面常驻、只做透明度过渡。

**Tech Stack:** Flutter/Dart 3.6、Material 3。

## Global Constraints

- 运行环境：Flutter 在 `C:\flutter\bin`；命令前缀 `$env:Path = "C:\flutter\bin;$env:Path";`；工作目录 `D:\ACGNhub`。
- 每个任务结束必须：`flutter analyze lib test` 无问题 + `flutter test` 全绿。
- 每个任务结束提交并推送：`git add <精确文件>` → `git commit` → `git push origin dev`。
- 不新增依赖；不改 `pubspec.yaml`。
- 不加代码注释（与现有风格一致者除外）。中文 UI 文案。
- 侧栏文字：`fontSize: 13`、`height: 1.4`、选中 `FontWeight.w600` / 未选中 `FontWeight.w500`、不设 `letterSpacing`；不设 `fontFamily`（继承主题）。
- 线条：宽 3、色 `Color(0xFF007AFF)`、`Positioned(left: 0, top: 0, bottom: 0)`、`TweenAnimationBuilder<double>` 0↔1、200ms、`Curves.easeInOutCubic`、`Opacity(opacity: t)` + `Transform.scale(scaleY: t, alignment: Alignment.center)`。
- **禁止**用 `AnimatedDefaultTextStyle` 做侧栏文字颜色（会替换继承的字体样式导致丢字体）。
- 板块过渡：`Stack(fit: StackFit.expand)` + 每页 `IgnorePointer` + `AnimatedOpacity(opacity: 当前?1:0, 250ms, Curves.easeInOut)`；所有页面必须始终挂载。

---

### Task 1: 侧栏文字与线条动效

**Files:**
- Modify: `lib/shell/app_sidebar.dart`
- Test: `test/shell/app_sidebar_test.dart`

**Interfaces:**
- Consumes: 现有 `AppSidebar({required int selectedIndex, required ValueChanged<int> onChanged, required VoidCallback onSettingsTap})`。
- Produces: 无新公共接口；`_SidebarItem` 内部改为动画实现，线条 `Opacity` 带 `key: ValueKey('sidebar-line')`。

- [ ] **Step 1: 写失败测试**

创建 `test/shell/app_sidebar_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/shell/app_sidebar.dart';

void main() {
  testWidgets('sidebar labels are 13px and the selected line animates',
      (tester) async {
    var selected = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => AppSidebar(
            selectedIndex: selected,
            onChanged: (i) => setState(() => selected = i),
            onSettingsTap: () {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    for (final label in ['动漫', '漫画', '轻小说', '游戏', '设置']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.widget<Text>(find.text('动漫')).style!.fontSize, 13);

    List<double> lineOpacity() => tester
        .widgetList<Opacity>(find.byKey(const ValueKey('sidebar-line')))
        .map((w) => w.opacity)
        .toList();

    expect(lineOpacity(), [1.0, 0.0, 0.0, 0.0, 0.0]);

    await tester.tap(find.text('漫画'));
    await tester.pumpAndSettle();
    expect(lineOpacity(), [0.0, 1.0, 0.0, 0.0, 0.0]);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/shell/app_sidebar_test.dart`
Expected: 失败——`find.byKey(ValueKey('sidebar-line'))` 找不到（当前没有该 `Opacity`），且字号断言为 11 而非 13。

- [ ] **Step 3: 实现**

把 `lib/shell/app_sidebar.dart` 里整个 `_SidebarItem` 类：

```dart
class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const _accent = Color(0xFF007AFF);
  static const _fg = Color(0xFF1C1C1E);

  @override
  Widget build(BuildContext context) {
    final iconColor = selected ? _accent : _fg.withValues(alpha: 0.35);
    final textColor = selected ? _accent : _fg.withValues(alpha: 0.45);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: selected
              ? const Border(left: BorderSide(color: _accent, width: 3))
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: iconColor),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: textColor,
                letterSpacing: 0.02,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

替换为：

```dart
class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const _accent = Color(0xFF007AFF);
  static const _fg = Color(0xFF1C1C1E);

  @override
  Widget build(BuildContext context) {
    final idleIcon = _fg.withValues(alpha: 0.35);
    final idleText = _fg.withValues(alpha: 0.45);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(
            begin: selected ? 1.0 : 0.0, end: selected ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOutCubic,
        builder: (context, t, _) {
          final iconColor = Color.lerp(idleIcon, _accent, t)!;
          final textColor = Color.lerp(idleText, _accent, t)!;
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                width: 72,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 24, color: iconColor),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Opacity(
                  key: const ValueKey('sidebar-line'),
                  opacity: t,
                  child: Transform.scale(
                    scaleY: t,
                    alignment: Alignment.center,
                    child: Container(width: 3, color: _accent),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/shell/app_sidebar_test.dart`
Expected: 通过。

- [ ] **Step 5: 静态检查与全量测试**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: 全绿。

- [ ] **Step 6: 提交**

```bash
git add lib/shell/app_sidebar.dart test/shell/app_sidebar_test.dart
git commit -m "feat(shell): unify sidebar label size; animate the selected line"
git push origin dev
```

---

### Task 2: 板块切换交叉淡入淡出

**Files:**
- Modify: `lib/shell/main_shell.dart`
- Test: `test/shell/main_shell_test.dart`

**Interfaces:**
- Consumes: 现有 `MainShell`（`lib/shell/main_shell.dart`，`_pages` 为 4 个模块页）。
- Produces: 无新公共接口；每个板块包一层带 `key: ValueKey('module-page-$i')` 的 `AnimatedOpacity`。

- [ ] **Step 1: 写失败测试**

创建 `test/shell/main_shell_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acgnhub/shell/main_shell.dart';

void main() {
  testWidgets('switching modules cross-fades while keeping every page mounted',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: MainShell()),
    ));
    await tester.pump();

    List<double> pageOpacity() => [
          for (var i = 0; i < 4; i++)
            tester
                .widget<AnimatedOpacity>(find.byKey(ValueKey('module-page-$i')))
                .opacity,
        ];

    expect(pageOpacity(), [1.0, 0.0, 0.0, 0.0]);

    await tester.tap(find.text('漫画'));
    await tester.pump();
    expect(pageOpacity(), [0.0, 1.0, 0.0, 0.0]);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/shell/main_shell_test.dart`
Expected: 失败——`find.byKey(ValueKey('module-page-0'))` 找不到（当前是 `IndexedStack`，没有这些 key）。

- [ ] **Step 3: 实现**

编辑 `lib/shell/main_shell.dart`，把 `build` 中的：

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
                            key: ValueKey('module-page-$i'),
                            opacity: i == _currentIndex ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            child: _pages[i],
                          ),
                        ),
                    ],
                  ),
                ),
```

- [ ] **Step 4: 运行测试确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/shell/main_shell_test.dart`
Expected: 通过。

- [ ] **Step 5: 静态检查与全量测试**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: 全绿。

- [ ] **Step 6: 提交**

```bash
git add lib/shell/main_shell.dart test/shell/main_shell_test.dart
git commit -m "feat(shell): cross-fade module switching"
git push origin dev
```

---

## 验证（任务完成后）

1. `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` 全绿。
2. `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug` 成功。
3. 启动应用：
   - 侧栏文字变大（13px）、未选中不再过细；
   - 点侧栏项时左侧蓝线从中间向上下展开并淡入，图标/文字颜色同步过渡；
   - 切换动漫/漫画/轻小说/游戏时内容交叉淡入淡出（~250ms），切回原板块时滚动位置与 Tab 状态保留。

## 已知取舍

- 板块切换只有透明度过渡（无滑动/缩放）。
- 所有板块常驻（与 `IndexedStack` 一致），未额外用 `TickerMode` 停掉非当前页的动画。
