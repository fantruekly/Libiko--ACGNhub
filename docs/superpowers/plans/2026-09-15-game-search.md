# 游戏搜索 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为游戏模块加入跨源搜索页，并在主壳游戏 Tab 启用搜索按钮。

**Architecture:** `GameSource` 新增 `search(keyword)`（两源都用 `GET /?s=<encoded>` 复用各自列表解析）；新增 `GameSearchResult` 与 per-source/聚合 provider；新增 `GameSearchPage`（4 列 3:2 结果网格）；把游戏首页的网格度量抽到 `game_grid.dart` 供首页与搜索页共用。

**Tech Stack:** Flutter (Dart 3.6)、flutter_riverpod（均已有，无新增依赖）。

## Global Constraints

- 仅改动游戏模块 + 主壳搜索入口；不改其它模块的搜索。
- 无新增依赖。不添加代码注释（除非下方给定代码已含）。
- 搜索仅取每个源的第一页（不分页）。
- 结果网格与游戏首页一致：4 列、3:2。
- 在 `dev` 分支开发；每个任务结束提交一次。
- 测试命令：`C:\flutter\bin\flutter.bat test <path>`；静态检查：`C:\flutter\bin\flutter.bat analyze`。

---

## Task 1: GameSource.search

**Files:**
- Modify: `lib/core/game/game_source.dart`
- Modify: `lib/core/game/galgamezywz_source.dart`
- Modify: `lib/core/game/nekogal_source.dart`
- Modify: `test/core/game/game_source_test.dart`（假源补 search）
- Modify: `test/modules/game/game_home_test.dart`（两个假源补 search）
- Modify: `test/modules/game/game_providers_test.dart`（假源补 search）
- Test: `test/core/game/galgamezywz_source_test.dart`
- Test: `test/core/game/nekogal_source_test.dart`

**Interfaces:**
- Produces: `Future<List<Game>> GameSource.search(String keyword)`。

### Step 1: 写源搜索测试（先失败）

在 `test/core/game/galgamezywz_source_test.dart` 的 `main()` 内追加：

```dart
  test('search requests the keyword and parses results', () async {
    final dio = Dio(BaseOptions(baseUrl: galgameZywzBaseUrl));
    final adapter = _FakeAdapter({
      '/?s=%E9%AD%94%E5%A5%B3': _listHtmlWith(2, idBase: 100),
    });
    dio.httpClientAdapter = adapter;
    final source = GalgameZywzSource(dio: dio);

    final results = await source.search('魔女');
    expect(adapter.requested, ['/?s=%E9%AD%94%E5%A5%B3']);
    expect(results.map((g) => g.id), ['100', '101']);
  });

  test('search returns empty without a request for a blank keyword', () async {
    final dio = Dio(BaseOptions(baseUrl: galgameZywzBaseUrl));
    final adapter = _FakeAdapter({});
    dio.httpClientAdapter = adapter;
    final source = GalgameZywzSource(dio: dio);

    expect(await source.search('   '), isEmpty);
    expect(adapter.requested, isEmpty);
  });
```

在 `test/core/game/nekogal_source_test.dart` 的 `main()` 内追加：

```dart
  test('search requests the keyword and parses results', () async {
    final dio = Dio(BaseOptions(baseUrl: nekogalBaseUrl));
    final adapter = _FakeAdapter({
      '/?s=%E9%AD%94%E5%A5%B3': _listPageHtml(2, base: 100),
    });
    dio.httpClientAdapter = adapter;
    final source = NekogalSource(dio: dio);

    final results = await source.search('魔女');
    expect(adapter.requested, ['/?s=%E9%AD%94%E5%A5%B3']);
    expect(results.map((g) => g.id), ['100', '101']);
  });
```

Run:
- `C:\flutter\bin\flutter.bat test test/core/game/galgamezywz_source_test.dart`
- `C:\flutter\bin\flutter.bat test test/core/game/nekogal_source_test.dart`
Expected: FAIL（`search` 未定义 / 编译错误）。

### Step 2: 接口 + 两源实现

`lib/core/game/game_source.dart`：在 `detail` 之后加入：

```dart
  /// 关键词搜索（仅第一页）。
  Future<List<Game>> search(String keyword);
```

`lib/core/game/galgamezywz_source.dart`：在 `GalgameZywzSource` 内（`detail` 之前或之后）加入：

```dart
  @override
  Future<List<Game>> search(String keyword) async {
    final k = keyword.trim();
    if (k.isEmpty) return const [];
    final html = await _get('/?s=${Uri.encodeQueryComponent(k)}');
    return parseGameList(html);
  }
```

`lib/core/game/nekogal_source.dart`：在 `NekogalSource` 内加入：

```dart
  @override
  Future<List<Game>> search(String keyword) async {
    final k = keyword.trim();
    if (k.isEmpty) return const [];
    final html = await _get('/?s=${Uri.encodeQueryComponent(k)}');
    return parseNekogalList(html);
  }
```

### Step 3: 给所有假源补 search

在这三处 `_FakeSource`（`test/core/game/game_source_test.dart`、`test/modules/game/game_home_test.dart`、`test/modules/game/game_providers_test.dart`）以及 `test/modules/game/game_home_test.dart` 的 `_NekoFakeSource` 中，各加入：

```dart
  @override
  Future<List<Game>> search(String keyword) async => const [];
```

（`game_providers_test.dart` 的假源后续在 Task 3 会改成返回结果；此处先补 `const []` 让其编译。）

### Step 4: 运行测试

Run:
- `C:\flutter\bin\flutter.bat test test/core/game/galgamezywz_source_test.dart`
- `C:\flutter\bin\flutter.bat test test/core/game/nekogal_source_test.dart`
- `C:\flutter\bin\flutter.bat test test/core/game/game_source_test.dart`
- `C:\flutter\bin\flutter.bat test test/modules/game/game_home_test.dart`
- `C:\flutter\bin\flutter.bat test test/modules/game/game_providers_test.dart`
- `C:\flutter\bin\flutter.bat analyze`
Expected: 均 PASS；analyze `No issues found!`。

### Step 5: 提交

```bash
git add lib/core/game/game_source.dart lib/core/game/galgamezywz_source.dart lib/core/game/nekogal_source.dart test/core/game/galgamezywz_source_test.dart test/core/game/nekogal_source_test.dart test/core/game/game_source_test.dart test/modules/game/game_home_test.dart test/modules/game/game_providers_test.dart
git commit -m "feat(game): add keyword search to both game sources"
```

---

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

## Task 3: 搜索 Providers

**Files:**
- Modify: `lib/modules/game/game_providers.dart`
- Test: `test/modules/game/game_providers_test.dart`

**Interfaces:**
- Consumes: `GameSource.search`（Task 1）。
- Produces: `class GameSearchResult { Game game; String sourceKey; }`；`const Duration gameSearchTimeout`；`gameSearchSourceProvider((sourceId, keyword))`；`gameSearchProvider(keyword)`。

### Step 1: 写测试（先失败）

在 `test/modules/game/game_providers_test.dart` 中：

1) 把 `_FakeSource` 的 `search`（Task 1 补的 `const []`）替换为：

```dart
  @override
  Future<List<Game>> search(String keyword) async =>
      [Game(id: 's-$keyword', title: '搜索结果$keyword')];
```

2) 在文件顶部（`_FakeSource` 之后）加入两个辅助假源：

```dart
class _TitleSource implements GameSource {
  _TitleSource(this._id, this._title);
  final String _id;
  final String _title;
  @override
  String get id => _id;
  @override
  String get name => _id;
  @override
  String get baseUrl => 'https://fake';
  @override
  List<GameBrowseOption> get browseOptions => const [];
  @override
  Future<GameList> browse(String optionKey, {int page = 1}) async =>
      GameList(items: const [], page: page, hasMore: false);
  @override
  Future<GameDetail> detail(String id) async =>
      GameDetail(game: Game(id: id, title: id), sourceUrl: 'https://fake/$id');
  @override
  Future<List<Game>> search(String keyword) async =>
      [Game(id: _id, title: _title)];
}

class _FailingSource implements GameSource {
  @override
  String get id => 'failing';
  @override
  String get name => 'failing';
  @override
  String get baseUrl => 'https://fake';
  @override
  List<GameBrowseOption> get browseOptions => const [];
  @override
  Future<GameList> browse(String optionKey, {int page = 1}) async =>
      GameList(items: const [], page: page, hasMore: false);
  @override
  Future<GameDetail> detail(String id) async =>
      GameDetail(game: Game(id: id, title: id), sourceUrl: 'https://fake/$id');
  @override
  Future<List<Game>> search(String keyword) async => throw Exception('boom');
}
```

3) 在 `main()` 内追加：

```dart
  test('gameSearchSourceProvider delegates to the source', () async {
    final container = _container();
    addTearDown(container.dispose);
    final results =
        await container.read(gameSearchSourceProvider(('fake', '魔女')).future);
    expect(results.single.game.title, '搜索结果魔女');
    expect(results.single.sourceKey, 'fake');
  });

  test('gameSearchSourceProvider is empty for a blank keyword', () async {
    final container = _container();
    addTearDown(container.dispose);
    expect(
        await container.read(gameSearchSourceProvider(('fake', '  ')).future),
        isEmpty);
  });

  test('gameSearchProvider merges and dedupes by title', () async {
    final container = ProviderContainer(overrides: [
      gameSourceManagerProvider.overrideWithValue(GameSourceManager(
          sources: [_TitleSource('a', '同名游戏'), _TitleSource('b', '同名游戏')])),
    ]);
    addTearDown(container.dispose);
    final results = await container.read(gameSearchProvider('x').future);
    expect(results, hasLength(1));
  });

  test('gameSearchProvider isolates a failing source', () async {
    final container = ProviderContainer(overrides: [
      gameSourceManagerProvider.overrideWithValue(GameSourceManager(
          sources: [_TitleSource('a', '好结果'), _FailingSource()])),
    ]);
    addTearDown(container.dispose);
    final results = await container.read(gameSearchProvider('x').future);
    expect(results.single.game.title, '好结果');
  });

  test('gameSearchProvider throws when all sources fail', () async {
    final container = ProviderContainer(overrides: [
      gameSourceManagerProvider.overrideWithValue(
          GameSourceManager(sources: [_FailingSource()])),
    ]);
    addTearDown(container.dispose);
    expect(container.read(gameSearchProvider('x').future), throwsStateError);
  });
```

Run: `C:\flutter\bin\flutter.bat test test/modules/game/game_providers_test.dart`
Expected: FAIL（`gameSearchSourceProvider` / `gameSearchProvider` 未定义）。

### Step 2: 实现

在 `lib/modules/game/game_providers.dart` 末尾追加：

```dart
class GameSearchResult {
  final Game game;
  final String sourceKey;
  const GameSearchResult({required this.game, required this.sourceKey});
}

const Duration gameSearchTimeout = Duration(seconds: 10);

final gameSearchSourceProvider =
    FutureProvider.family<List<GameSearchResult>, (String, String)>(
        (ref, key) async {
  final (sourceId, keyword) = key;
  final k = keyword.trim();
  if (k.isEmpty) return const [];
  final source = ref.watch(gameSourceManagerProvider).byId(sourceId);
  if (source == null) return const [];
  final games = await source.search(k).timeout(gameSearchTimeout);
  return [
    for (final game in games)
      GameSearchResult(game: game, sourceKey: sourceId),
  ];
});

final gameSearchProvider =
    FutureProvider.family<List<GameSearchResult>, String>((ref, keyword) async {
  final k = keyword.trim();
  if (k.isEmpty) return const [];
  final sources = ref.watch(gameSourceManagerProvider).sources;
  if (sources.isEmpty) return const [];
  final perSource = await Future.wait(sources.map((source) async {
    try {
      final games = await source.search(k).timeout(gameSearchTimeout);
      return (source.id, games, null);
    } catch (e) {
      return (source.id, const <Game>[], e);
    }
  }));
  final out = <GameSearchResult>[];
  final seen = <String>{};
  Object? lastError;
  var succeeded = 0;
  for (final (sourceId, games, error) in perSource) {
    if (error != null) {
      lastError = error;
      continue;
    }
    succeeded++;
    for (final game in games) {
      if (seen.add(game.title.trim())) {
        out.add(GameSearchResult(game: game, sourceKey: sourceId));
      }
    }
  }
  if (succeeded == 0) {
    throw StateError('所有游戏源搜索失败：$lastError');
  }
  return out;
});
```

Run: `C:\flutter\bin\flutter.bat test test/modules/game/game_providers_test.dart`
Expected: PASS。

### Step 3: 静态检查 + 提交

Run: `C:\flutter\bin\flutter.bat analyze`
Expected: `No issues found!`

```bash
git add lib/modules/game/game_providers.dart test/modules/game/game_providers_test.dart
git commit -m "feat(game): add game search providers"
```

---

## Task 4: GameSearchPage

**Files:**
- Create: `lib/modules/game/game_search.dart`
- Test: `test/modules/game/game_search_page_test.dart`

**Interfaces:**
- Consumes: `gameSearchSourceProvider` / `gameSourcesProvider`（Task 3）、`GameCard`（`game_home.dart`）、`gameGridColumns`/`gameGridSpacing`/`gameGridCellWidth`/`gameGridCellExtent`（Task 2）、`smoothRoute` / `EmptyState` / `ShimmerLoader`。

### Step 1: 写测试（先失败）

Create `test/modules/game/game_search_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/game/game_source.dart';
import 'package:acgnhub/core/game/models.dart';
import 'package:acgnhub/modules/game/game_providers.dart';
import 'package:acgnhub/modules/game/game_search.dart';

class _FakeSource implements GameSource {
  _FakeSource(this.results, {this.delay = Duration.zero, String id = 'fake'})
      : _id = id;
  final List<Game> results;
  final Duration delay;
  final String _id;
  @override
  String get id => _id;
  @override
  String get name => _id;
  @override
  String get baseUrl => 'https://x';
  @override
  List<GameBrowseOption> get browseOptions => const [];
  @override
  Future<GameList> browse(String optionKey, {int page = 1}) async =>
      GameList(items: const [], page: page, hasMore: false);
  @override
  Future<GameDetail> detail(String id) async =>
      GameDetail(game: Game(id: id, title: id), sourceUrl: 'https://x/$id');
  @override
  Future<List<Game>> search(String keyword) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return results;
  }
}

Widget _app(List<Game> results) => ProviderScope(
      overrides: [
        gameSourceManagerProvider.overrideWithValue(
            GameSourceManager(sources: [_FakeSource(results)])),
      ],
      child: const MaterialApp(home: GameSearchPage(initialKeyword: '关键词')),
    );

void main() {
  testWidgets('renders results from the sources', (tester) async {
    await tester.pumpWidget(_app(const [Game(id: '1', title: '结果游戏')]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('结果游戏'), findsOneWidget);
  });

  testWidgets('shows a prompt before searching', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: GameSearchPage()),
    ));
    expect(find.text('输入关键词搜索游戏'), findsOneWidget);
  });

  testWidgets('shows empty message when there are no results', (tester) async {
    await tester.pumpWidget(_app(const []));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('没有找到游戏'), findsOneWidget);
  });
}
```

Run: `C:\flutter\bin\flutter.bat test test/modules/game/game_search_page_test.dart`
Expected: FAIL（找不到 `game_search.dart`）。

### Step 2: 实现 `game_search.dart`

Create `lib/modules/game/game_search.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../core/widgets/smooth_route.dart';
import 'game_detail_page.dart';
import 'game_grid.dart';
import 'game_home.dart';
import 'game_providers.dart';

const _muted = Color(0xFF5A5A5F);

class GameSearchPage extends ConsumerStatefulWidget {
  final String? initialKeyword;
  const GameSearchPage({super.key, this.initialKeyword});

  @override
  ConsumerState<GameSearchPage> createState() => _GameSearchPageState();
}

class _GameSearchPageState extends ConsumerState<GameSearchPage> {
  final _ctrl = TextEditingController();
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialKeyword?.trim() ?? '';
    if (initial.isNotEmpty) {
      _ctrl.text = initial;
      _keyword = initial;
    }
  }

  void _search() {
    final k = _ctrl.text.trim();
    if (k.isEmpty) return;
    setState(() => _keyword = k);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          children: [
            _searchBar(cs),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _searchBar(ColorScheme cs) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        border:
            Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
            splashRadius: 20,
          ),
          Expanded(
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded,
                      size: 18, color: cs.onSurface.withValues(alpha: 0.3)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: widget.initialKeyword == null,
                      style: TextStyle(fontSize: 15, color: cs.onSurface),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '搜索游戏...',
                        hintStyle: TextStyle(color: _muted, fontSize: 15),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => _search(),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (_ctrl.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _ctrl.clear();
                        setState(() {});
                      },
                      child: Icon(Icons.close_rounded,
                          size: 16, color: cs.onSurface.withValues(alpha: 0.3)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
              onPressed: _search,
              child: const Text('搜索', style: TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _body() {
    if (_keyword.isEmpty) {
      return const EmptyState(
          icon: Icons.search_rounded, message: '输入关键词搜索游戏');
    }
    final sources = ref.watch(gameSourcesProvider);
    final results = <GameSearchResult>[];
    final seen = <String>{};
    var pending = 0;
    var failed = 0;
    Object? lastError;
    for (final source in sources) {
      final async =
          ref.watch(gameSearchSourceProvider((source.id, _keyword)));
      async.when(
        data: (list) {
          for (final r in list) {
            if (seen.add(r.game.title.trim())) results.add(r);
          }
        },
        loading: () {
          pending++;
        },
        error: (error, __) {
          failed++;
          lastError = error;
        },
      );
    }
    if (results.isEmpty && pending > 0) {
      return LayoutBuilder(builder: (context, constraints) {
        final cellW = gameGridCellWidth(constraints.maxWidth);
        return ShimmerLoader(
            crossAxisCount: gameGridColumns,
            itemCount: 8,
            aspectRatio: cellW / gameGridCellExtent(constraints.maxWidth),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24));
      });
    }
    if (results.isEmpty) {
      if (sources.isNotEmpty && failed == sources.length) {
        return EmptyState(
          icon: Icons.error_outline_rounded,
          message: lastError?.toString() ?? '搜索失败',
          actionLabel: '重试',
          onAction: () {
            for (final source in sources) {
              ref.invalidate(gameSearchSourceProvider((source.id, _keyword)));
            }
          },
        );
      }
      return const EmptyState(
          icon: Icons.search_off_rounded, message: '没有找到游戏');
    }
    return Column(
      children: [
        if (pending > 0)
          const LinearProgressIndicator(
            minHeight: 2,
            color: Color(0xFF007AFF),
            backgroundColor: Color(0xFFE5E5EA),
          ),
        Expanded(child: _grid(results)),
      ],
    );
  }

  Widget _grid(List<GameSearchResult> results) {
    return LayoutBuilder(builder: (context, constraints) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gameGridColumns,
            mainAxisSpacing: 20,
            crossAxisSpacing: gameGridSpacing,
            mainAxisExtent: gameGridCellExtent(constraints.maxWidth)),
        itemCount: results.length,
        itemBuilder: (_, i) {
          final r = results[i];
          return GameCard(
            game: r.game,
            heroTag: 'game_${r.sourceKey}_${r.game.id}',
            onTap: () => Navigator.push(
              context,
              smoothRoute(GameDetailPage(
                sourceKey: r.sourceKey,
                gameId: r.game.id,
                title: r.game.title,
                cover: r.game.coverUrl,
              )),
            ),
          );
        },
      );
    });
  }
}
```

Run: `C:\flutter\bin\flutter.bat test test/modules/game/game_search_page_test.dart`
Expected: PASS（3 tests）。

### Step 3: 静态检查 + 提交

Run: `C:\flutter\bin\flutter.bat analyze`
Expected: `No issues found!`

```bash
git add lib/modules/game/game_search.dart test/modules/game/game_search_page_test.dart
git commit -m "feat(game): add the game search page"
```

---

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
