## Task 5: 主壳搜索入口

**Files:**
- Modify: `lib/shell/main_shell.dart`
- Test: `test/shell/main_shell_test.dart`

### Step 1: 写测试（先失败）

在 `test/shell/main_shell_test.dart` 的 `main()` 内追加（import 加入 `package:acgnhub/modules/game/game_search.dart`）：

```dart
  testWidgets('game tab exposes the search entry', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: MainShell()),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.descendant(
      of: find.byType(AppSidebar),
      matching: find.text('游戏'),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final searchButton = find.byWidgetPredicate((w) =>
        w is IconButton &&
        w.icon is Icon &&
        (w.icon as Icon).icon == Icons.search_rounded);
    expect(searchButton, findsOneWidget);

    await tester.tap(searchButton);
    await tester.pump();
    expect(find.byType(GameSearchPage), findsOneWidget);
  });
```

Run: `C:\flutter\bin\flutter.bat test test/shell/main_shell_test.dart`
Expected: FAIL（index 3 无搜索按钮 / 找不到 `GameSearchPage`）。

### Step 2: 改主壳

`lib/shell/main_shell.dart`：

1) import 加入 `import '../modules/game/game_search.dart';`
2) 把搜索按钮（第 148–161 行）替换为：

```dart
              if (_currentIndex >= 0 && _currentIndex <= 3)
                IconButton(
                  icon: const Icon(Icons.search_rounded, size: 20),
                  color: _muted,
                  splashRadius: 20,
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => _currentIndex == 0
                              ? const AnimeSearchPage()
                              : _currentIndex == 1
                                  ? const ComicSearchPage()
                                  : _currentIndex == 2
                                      ? const NovelSearchPage()
                                      : const GameSearchPage())),
                ),
```

Run: `C:\flutter\bin\flutter.bat test test/shell/main_shell_test.dart`
Expected: PASS。

### Step 3: 全量回归 + 提交

Run: `C:\flutter\bin\flutter.bat test`；`C:\flutter\bin\flutter.bat analyze`
Expected: 全部 PASS；analyze `No issues found!`。

```bash
git add lib/shell/main_shell.dart test/shell/main_shell_test.dart
git commit -m "feat(shell): open game search from the title bar"
```

---

## 手动验证（合并前，由用户执行）

在 Windows 上运行应用：
1. 游戏 Tab 顶部出现搜索按钮；点击打开游戏搜索页。
2. 输入关键词（如「魔女」）→ 两个源的结果渐进出现、按标题去重。
3. 点结果进详情（封面 `Hero` 飞行、详情字段正确）。
4. 输入无结果关键词 → 显示「没有找到游戏」。
5. 断网后搜索 → 显示失败 + 重试。

## 自查记录（Self-Review）

- **Spec 覆盖**：`search` 接口与两源实现 → Task 1；共享网格 → Task 2；providers → Task 3；搜索页 → Task 4；主壳入口 → Task 5。
- **类型一致性**：`GameSource.search` 返回 `List<Game>`；`GameSearchResult` 在 Task 3 定义、Task 4 消费；`gameSearchSourceProvider` 键 `(String,String)` 在 Task 3/4 一致；`GameCard` 的 `heroTag`/`onTap` 与现有签名一致。
- **占位符**：无 TBD/TODO；每步给出完整代码与命令。
- **注意**：Task 1 给接口加方法会使所有假源编译失败，Step 3 已列出需补 `search` 的假源文件。
