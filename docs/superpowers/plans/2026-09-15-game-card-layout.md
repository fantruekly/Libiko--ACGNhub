# 游戏首页卡片布局（4 列 3:2，24/页）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 游戏首页改为 4 列、3:2 横图卡片（与源站一致，不裁切），每页 24 个（4 列 × 6 行）。

**Architecture:** 把 `galgameZywzPageSize` 从 48 改回 24（`browse` 逻辑不变，每页抓 2 个源站页）；把游戏首页网格从固定 `childAspectRatio: 0.58` 改为 `LayoutBuilder` + `mainAxisExtent`，使封面精确为 3:2。UI 其余部分与详情页不变。

**Tech Stack:** Flutter (Dart 3.6)、flutter_riverpod（均已有，无新增依赖）。

## Global Constraints

- 仅改动游戏模块；不改详情页、分区 chip、解析函数、其它模块。
- 无新增依赖。
- 不添加代码注释（除非下方给定代码已含）。
- 在 `dev` 分支开发；完成后提交。
- 测试命令：`C:\flutter\bin\flutter.bat test <path>`；静态检查：`C:\flutter\bin\flutter.bat analyze`。
- 本改动取代 `docs/superpowers/specs/2026-09-15-game-page-size-design.md` 的 48/页决定（该文件已标注作废）。

---

## Task 1: 4 列 3:2 卡片 + 24/页

**Files:**
- Modify: `lib/core/game/galgamezywz_source.dart`
- Modify: `lib/modules/game/game_home.dart`
- Test: `test/core/game/galgamezywz_source_test.dart`
- Test: `test/modules/game/game_home_test.dart`

**Interfaces:**
- Consumes: 现有 `GalgameZywzSource.browse`、`GameCard`、`ShimmerLoader`。
- Produces: `galgameZywzPageSize == 24`；游戏首页 4 列、封面 3:2 的网格。

### Step 1: 更新分页测试（先失败）

在 `test/core/game/galgamezywz_source_test.dart` 中：

1) 把第一个测试（第 63–90 行）整体替换为：

```dart
  test('browse page 1 requests two source pages and returns 24', () async {
    final dio = Dio(BaseOptions(baseUrl: galgameZywzBaseUrl));
    final adapter = _FakeAdapter({
      '/lm/galgame':
          _listHtmlWith(12, next: '/lm/galgame/page/2', idBase: 100),
      '/lm/galgame/page/2':
          _listHtmlWith(12, next: '/lm/galgame/page/3', idBase: 200),
    });
    dio.httpClientAdapter = adapter;
    final source = GalgameZywzSource(dio: dio);

    final list = await source.browse('galgame', page: 1);
    expect(adapter.requested, ['/lm/galgame', '/lm/galgame/page/2']);
    expect(list.items, hasLength(24));
    expect(list.items.first.id, '100');
    expect(list.items.last.id, '211');
    expect(list.page, 1);
    expect(list.hasMore, isTrue);
  });
```

2) 把第二个测试（第 92–118 行）整体替换为：

```dart
  test('browse page 2 requests the next two source pages', () async {
    final dio = Dio(BaseOptions(baseUrl: galgameZywzBaseUrl));
    final adapter = _FakeAdapter({
      '/lm/galgame/page/3':
          _listHtmlWith(12, next: '/lm/galgame/page/4', idBase: 300),
      '/lm/galgame/page/4':
          _listHtmlWith(12, next: '/lm/galgame/page/5', idBase: 400),
    });
    dio.httpClientAdapter = adapter;
    final source = GalgameZywzSource(dio: dio);

    final list = await source.browse('galgame', page: 2);
    expect(adapter.requested, ['/lm/galgame/page/3', '/lm/galgame/page/4']);
    expect(list.items, hasLength(24));
    expect(list.items.first.id, '300');
    expect(list.page, 2);
    expect(list.hasMore, isTrue);
  });
```

3) 把裁剪测试（第 136–153 行）整体替换为：

```dart
  test('browse trims a 28-item page to 24', () async {
    final dio = Dio(BaseOptions(baseUrl: galgameZywzBaseUrl));
    final adapter = _FakeAdapter({
      '/': _listHtmlWith(16, next: '/page/2', idBase: 100),
      '/page/2': _listHtmlWith(12, next: '/page/3', idBase: 200),
    });
    dio.httpClientAdapter = adapter;
    final source = GalgameZywzSource(dio: dio);

    final list = await source.browse('latest', page: 1);
    expect(adapter.requested, ['/', '/page/2']);
    expect(list.items, hasLength(24));
    expect(list.items.first.id, '100');
    expect(list.items.last.id, '207');
    expect(list.hasMore, isTrue);
  });
```

4) 把「later source page fails」测试（第 173–192 行）整体替换为：

```dart
  test('browse ends the list when a later source page fails', () async {
    final dio = Dio(BaseOptions(baseUrl: galgameZywzBaseUrl));
    final adapter = _FakeAdapter(
      {
        '/lm/galgame':
            _listHtmlWith(12, next: '/lm/galgame/page/2', idBase: 100),
      },
      failPaths: {'/lm/galgame/page/2'},
    );
    dio.httpClientAdapter = adapter;
    final source = GalgameZywzSource(dio: dio);

    final list = await source.browse('galgame', page: 1);
    expect(adapter.requested, ['/lm/galgame', '/lm/galgame/page/2']);
    expect(list.items, hasLength(12));
    expect(list.hasMore, isFalse);
  });
```

其余测试（early stop、first-page rethrow、detail、identity）保持不变。

### Step 2: 运行测试确认失败

Run: `C:\flutter\bin\flutter.bat test test/core/game/galgamezywz_source_test.dart`
Expected: FAIL —— 当前 `galgameZywzPageSize = 48`，`browse` 会抓 4 个源页、返回 48 个，与新的 2 页 / 24 个断言不符。

### Step 3: 改分页常量

在 `lib/core/game/galgamezywz_source.dart` 中把：

```dart
const int galgameZywzPageSize = 48;
```

改为：

```dart
const int galgameZywzPageSize = 24;
```

`galgameZywzSourcePageSize` 保持 12；`browse` 实现不改。

### Step 4: 运行分页测试确认通过

Run: `C:\flutter\bin\flutter.bat test test/core/game/galgamezywz_source_test.dart`
Expected: PASS（8 tests）。

### Step 5: 新增布局测试（先失败）

在 `test/modules/game/game_home_test.dart` 的 `main()` 内、现有测试之后追加：

```dart
  testWidgets('grid uses 4 columns with 3:2 covers', (tester) async {
    final container = ProviderContainer(overrides: [
      gameSourceManagerProvider
          .overrideWithValue(GameSourceManager(sources: [_FakeSource()])),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: GameHomePage())),
    ));
    await tester.pumpAndSettle();

    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 4);

    final size = tester.getSize(find.byType(GameCard).first);
    const titleExtent = 44.0;
    final coverHeight = size.height - titleExtent;
    expect(size.width / coverHeight, closeTo(1.5, 0.02));
  });
```

Run: `C:\flutter\bin\flutter.bat test test/modules/game/game_home_test.dart`
Expected: FAIL —— 当前网格是 6 列、`childAspectRatio: 0.58`。

### Step 6: 实现 4 列 3:2 网格

在 `lib/modules/game/game_home.dart` 中：

1) 在文件顶部常量区（`const _fg = Color(0xFF1C1C1E);` 之后）加入：

```dart
const int _gridColumns = 4;
const double _gridSpacing = 16;
const double _gridTitleExtent = 44;

double _gridCellWidth(double maxWidth) =>
    (maxWidth - 32 - _gridSpacing * (_gridColumns - 1)) / _gridColumns;

double _gridCellExtent(double maxWidth) =>
    _gridCellWidth(maxWidth) * 2 / 3 + _gridTitleExtent;
```

2) 把 `_body` 的 `loading:` 分支（第 153–157 行）替换为：

```dart
      loading: () => LayoutBuilder(builder: (context, constraints) {
        final cellW = _gridCellWidth(constraints.maxWidth);
        return ShimmerLoader(
            crossAxisCount: _gridColumns,
            itemCount: 8,
            aspectRatio: cellW / _gridCellExtent(constraints.maxWidth),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24));
      }),
```

3) 把 `_grid`（第 202–227 行）整体替换为：

```dart
  Widget _grid(List<Game> items) {
    if (items.isEmpty) {
      return const EmptyState(icon: Icons.games_rounded, message: '暂无内容');
    }
    return LayoutBuilder(builder: (context, constraints) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _gridColumns,
            mainAxisSpacing: 20,
            crossAxisSpacing: _gridSpacing,
            mainAxisExtent: _gridCellExtent(constraints.maxWidth)),
        itemCount: items.length,
        itemBuilder: (_, i) => GameCard(
          game: items[i],
          onTap: () => Navigator.push(
            context,
            noTransitionRoute(GameDetailPage(
              sourceKey: _sourceId,
              gameId: items[i].id,
              title: items[i].title,
              cover: items[i].coverUrl,
            )),
          ),
        ),
      );
    });
  }
```

`GameCard` 结构不变（`Expanded` 封面 + 6 + 38 标题）。因行高 = `cellW*2/3 + 44`，封面高 = `cellW*2/3`，宽高比正好 3:2。

### Step 7: 运行测试确认通过

Run: `C:\flutter\bin\flutter.bat test test/modules/game/game_home_test.dart`
Expected: PASS（2 tests）。

### Step 8: 回归 + 静态检查 + 提交

Run:
- `C:\flutter\bin\flutter.bat test test/core/game/galgamezywz_parser_test.dart`
- `C:\flutter\bin\flutter.bat test test/modules/game/game_detail_page_test.dart`
- `C:\flutter\bin\flutter.bat analyze`
Expected: 均 PASS；analyze `No issues found!`。

```bash
git add lib/core/game/galgamezywz_source.dart lib/modules/game/game_home.dart test/core/game/galgamezywz_source_test.dart test/modules/game/game_home_test.dart
git commit -m "feat(game): 4-column 3:2 cards, 24 games per page"
```

---

## 手动验证（合并前，由用户执行）

在 Windows 上运行应用，进入「游戏」Tab：
1. 卡片为 4 列、3:2 横图，图片不再被竖着裁切。
2. 每页 24 个（6 行），非末页无空行。
3. 翻页正常，最后一页「下一页」禁用。

## 自查记录（Self-Review）

- **Spec 覆盖**：分页密度（24）→ Step 3；卡片布局（4 列 3:2）→ Step 6；测试 → Step 1/5。
- **类型一致性**：`_gridColumns` 为 `int`、`_gridSpacing`/`_gridTitleExtent` 为 `double`；`_gridCellWidth/Extent` 接收 `double` 返回 `double`；`SliverGridDelegateWithFixedCrossAxisCount` 的 `mainAxisExtent` 为 `double`。
- **占位符**：无 TBD/TODO；所有步骤给出完整代码与命令。
- **注意**：`galgameZywzPageSize` 由 48 改回 24，旧分页测试会失效，Step 1 已明确替换。
