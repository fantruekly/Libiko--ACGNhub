## Task 2: 抽取共享网格度量

**Files:**
- Create: `lib/modules/game/game_grid.dart`
- Modify: `lib/modules/game/game_home.dart`

**Interfaces:**
- Produces: `gameGridColumns` / `gameGridSpacing` / `gameGridTitleExtent` / `gameGridCellWidth(maxWidth)` / `gameGridCellExtent(maxWidth)`。

### Step 1: 新建 `game_grid.dart`

Create `lib/modules/game/game_grid.dart`:

```dart
const int gameGridColumns = 4;
const double gameGridSpacing = 16;
const double gameGridTitleExtent = 44;

double gameGridCellWidth(double maxWidth) =>
    (maxWidth - 32 - gameGridSpacing * (gameGridColumns - 1)) / gameGridColumns;

double gameGridCellExtent(double maxWidth) =>
    gameGridCellWidth(maxWidth) * 2 / 3 + gameGridTitleExtent;
```

### Step 2: `game_home.dart` 改用共享度量

1) import 加入 `import 'game_grid.dart';`。
2) 删除第 19–27 行的私有常量与函数（`_gridColumns`/`_gridSpacing`/`_gridTitleExtent`/`_gridCellWidth`/`_gridCellExtent`）。
3) 在 `_body` 与 `_grid` 中把引用替换为共享名：
   - `_gridColumns` → `gameGridColumns`
   - `_gridSpacing` → `gameGridSpacing`
   - `_gridCellWidth(` → `gameGridCellWidth(`
   - `_gridCellExtent(` → `gameGridCellExtent(`

### Step 3: 运行回归

Run:
- `C:\flutter\bin\flutter.bat test test/modules/game/game_home_test.dart`
- `C:\flutter\bin\flutter.bat analyze`
Expected: PASS；analyze 无问题。

### Step 4: 提交

```bash
git add lib/modules/game/game_grid.dart lib/modules/game/game_home.dart
git commit -m "refactor(game): share the game grid metrics"
```

---

