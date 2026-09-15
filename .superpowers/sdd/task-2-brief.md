## Task 2: GameSource 抽象与管理器

**Files:**
- Create: `lib/core/game/game_source.dart`
- Test: `test/core/game/game_source_test.dart`

**Interfaces:**
- Consumes: `lib/core/game/models.dart`（Task 1）。
- Produces: `abstract class GameSource { String get id; String get name; String get baseUrl; List<GameBrowseOption> get browseOptions; Future<GameList> browse(String optionKey, {int page = 1}); Future<GameDetail> detail(String id); }` 与 `GameSourceManager({List<GameSource>? sources})`（`sources` / `register` / `byId`）。

- [ ] **Step 1: Write the failing test**

Create `test/core/game/game_source_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/game/game_source.dart';
import 'package:acgnhub/core/game/models.dart';

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
      GameList(items: const [], page: page, hasMore: false);
  @override
  Future<GameDetail> detail(String id) async =>
      GameDetail(game: Game(id: id, title: id), sourceUrl: 'https://fake/$id');
}

void main() {
  test('manager exposes registered sources', () {
    final m = GameSourceManager(sources: [_FakeSource()]);
    expect(m.sources.map((s) => s.id), ['fake']);
    expect(m.byId('fake')!.name, 'Fake');
    expect(m.byId('nope'), isNull);
  });

  test('manager rejects duplicate ids', () {
    final m = GameSourceManager(sources: [_FakeSource()]);
    expect(() => m.register(_FakeSource()), throwsArgumentError);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/game/game_source_test.dart`
Expected: FAIL（找不到 `GameSourceManager` / `GameSource`）。

- [ ] **Step 3: Write minimal implementation**

Create `lib/core/game/game_source.dart`:

```dart
import 'models.dart';

abstract class GameSource {
  String get id;
  String get name;
  String get baseUrl;

  /// 该源声明的浏览分区（首页顶部 chip）。
  List<GameBrowseOption> get browseOptions;

  /// 按分区选项分页拉取。
  Future<GameList> browse(String optionKey, {int page = 1});

  /// 详情。
  Future<GameDetail> detail(String id);
}

class GameSourceManager {
  GameSourceManager({List<GameSource>? sources}) {
    for (final s in sources ?? const <GameSource>[]) {
      register(s);
    }
  }

  final List<GameSource> _sources = [];

  List<GameSource> get sources => List.unmodifiable(_sources);

  void register(GameSource source) {
    if (_sources.any((s) => s.id == source.id)) {
      throw ArgumentError('duplicate game source id: ${source.id}');
    }
    _sources.add(source);
  }

  GameSource? byId(String id) {
    for (final s in _sources) {
      if (s.id == id) return s;
    }
    return null;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/game/game_source_test.dart`
Expected: PASS（2 tests）。

- [ ] **Step 5: Commit**

```bash
git add lib/core/game/game_source.dart test/core/game/game_source_test.dart
git commit -m "feat(game): add GameSource abstraction and manager"
```

---

