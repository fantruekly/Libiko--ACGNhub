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