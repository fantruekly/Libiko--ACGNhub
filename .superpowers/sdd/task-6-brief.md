## Task 6: Riverpod Providers

**Files:**
- Create: `lib/modules/game/game_providers.dart`
- Test: `test/modules/game/game_providers_test.dart`

**Interfaces:**
- Consumes: `GalgameZywzSource`（Task 5）、`GameSourceManager`（Task 2）、模型（Task 1）。
- Produces: `gameSourceManagerProvider`、`gameSourcesProvider`、`gameBrowseProvider((String,String,int))`、`gameDetailProvider((String,String))`。

- [ ] **Step 1: Write the failing test**

Create `test/modules/game/game_providers_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/game/game_source.dart';
import 'package:acgnhub/core/game/models.dart';
import 'package:acgnhub/modules/game/game_providers.dart';

class _FakeSource implements GameSource {
  @override
  String get id => 'fake';
  @override
  String get name => 'Fake';
  @override
  String get baseUrl => 'https://fake';
  @override
  List<GameBrowseOption> get browseOptions =>
      const [GameBrowseOption(key: 'latest', label: '最近更新')];
  @override
  Future<GameList> browse(String optionKey, {int page = 1}) async =>
      GameList(
        items: [Game(id: '$optionKey-$page', title: '游戏$optionKey')],
        page: page,
        hasMore: false,
      );
  @override
  Future<GameDetail> detail(String id) async => GameDetail(
        game: Game(id: id, title: '游戏$id'),
        sourceUrl: 'https://fake/game/$id',
      );
}

ProviderContainer _container() => ProviderContainer(overrides: [
      gameSourceManagerProvider
          .overrideWithValue(GameSourceManager(sources: [_FakeSource()])),
    ]);

void main() {
  test('gameBrowseProvider delegates to the registered source', () async {
    final container = _container();
    addTearDown(container.dispose);
    final list =
        await container.read(gameBrowseProvider(('fake', 'latest', 2)).future);
    expect(list.page, 2);
    expect(list.items.single.title, '游戏latest');
  });

  test('gameDetailProvider delegates to the registered source', () async {
    final container = _container();
    addTearDown(container.dispose);
    final detail = await container.read(gameDetailProvider(('fake', '1')).future);
    expect(detail.game.id, '1');
    expect(detail.sourceUrl, 'https://fake/game/1');
  });

  test('unknown source id throws', () async {
    final container = _container();
    addTearDown(container.dispose);
    expect(
      container.read(gameBrowseProvider(('nope', 'latest', 1)).future),
      throwsStateError,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/modules/game/game_providers_test.dart`
Expected: FAIL（找不到 `game_providers.dart`）。

- [ ] **Step 3: Write minimal implementation**

Create `lib/modules/game/game_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/game/galgamezywz_source.dart';
import '../../core/game/game_source.dart';
import '../../core/game/models.dart';

final gameSourceManagerProvider = Provider<GameSourceManager>(
  (ref) => GameSourceManager(sources: [GalgameZywzSource()]),
);

final gameSourcesProvider = Provider<List<GameSource>>(
  (ref) => ref.watch(gameSourceManagerProvider).sources,
);

final gameBrowseProvider =
    FutureProvider.family<GameList, (String, String, int)>((ref, key) async {
  final (sourceId, optionKey, page) = key;
  final source = ref.watch(gameSourceManagerProvider).byId(sourceId);
  if (source == null) throw StateError('game source $sourceId not found');
  return source.browse(optionKey, page: page);
});

final gameDetailProvider =
    FutureProvider.family<GameDetail, (String, String)>((ref, key) async {
  final (sourceId, gameId) = key;
  final source = ref.watch(gameSourceManagerProvider).byId(sourceId);
  if (source == null) throw StateError('game source $sourceId not found');
  return source.detail(gameId);
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/modules/game/game_providers_test.dart`
Expected: PASS（3 tests）。

- [ ] **Step 5: Commit**

```bash
git add lib/modules/game/game_providers.dart test/modules/game/game_providers_test.dart
git commit -m "feat(game): add game Riverpod providers"
```

---

