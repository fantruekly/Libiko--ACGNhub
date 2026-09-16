## Task 2: 游戏首页接入

**Files:**
- Modify: `lib/modules/game/game_home.dart`
- Test: `test/modules/game/game_home_test.dart`（回归）

### Step 1: 接入

1) import 加入 `import '../../core/widgets/slide_switcher.dart';`

2) 在 `_body`（第 160 行起）中，`final option = ...` 之后加入：

```dart
    final sourceIndex =
        ref.watch(gameSourcesProvider).indexWhere((s) => s.id == _sourceId);
```

3) 把 `data:` 分支（第 173–178 行）替换为：

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

### Step 2: 运行回归

Run:
- `C:\flutter\bin\flutter.bat test test/modules/game/game_home_test.dart`
- `C:\flutter\bin\flutter.bat analyze`
Expected: PASS；analyze 无问题。

### Step 3: 提交

```bash
git add lib/modules/game/game_home.dart
git commit -m "feat(game): slide the grid when switching sections or pages"
```

---

