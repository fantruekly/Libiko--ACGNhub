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

