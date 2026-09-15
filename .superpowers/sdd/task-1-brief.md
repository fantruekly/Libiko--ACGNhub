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
