### Task 6: Create FavoriteManager and SearchEngine

**Files:**
- Create: `lib/core/services/favorite_manager.dart`
- Create: `lib/core/services/search_engine.dart`

**Interfaces:**
- Consumes: `AppDatabase` (Task 5), `SourceManager` (Task 3), `Work`, `WorkType` (Task 2)
- Produces: `FavoriteManager`, `SearchEngine` classes

- [ ] **Step 1: Write FavoriteManager**

Create `lib/core/services/favorite_manager.dart`:

```dart
import 'dart:convert';
import '../models/work.dart';
import '../storage/database.dart';

class FavoriteManager {
  static const _key = 'favorites';

  List<Work> getFavorites({WorkType? type}) {
    final jsonList = AppDatabase().getStringList(_key);
    final works = jsonList.map((j) => Work.fromJson(json.decode(j) as Map<String, dynamic>)).toList();
    if (type != null) {
      return works.where((w) => w.type == type).toList();
    }
    return works;
  }

  Future<void> addFavorite(Work work) async {
    final favorites = getFavorites();
    if (favorites.any((w) => w.id == work.id)) return;
    favorites.add(work);
    await _save(favorites);
  }

  Future<void> removeFavorite(String workId) async {
    final favorites = getFavorites();
    favorites.removeWhere((w) => w.id == workId);
    await _save(favorites);
  }

  bool isFavorite(String workId) {
    return getFavorites().any((w) => w.id == workId);
  }

  Future<void> _save(List<Work> works) async {
    final jsonList = works.map((w) => json.encode(w.toJson())).toList();
    await AppDatabase().setStringList(_key, jsonList);
  }
}
```

- [ ] **Step 2: Write SearchEngine**

Create `lib/core/services/search_engine.dart`:

```dart
import '../models/work.dart';
import '../models/search_result.dart';
import '../source/source_manager.dart';

class SearchEngine {
  final SourceManager _sourceManager;

  SearchEngine(this._sourceManager);

  Future<List<SearchResult>> search(
    WorkType type,
    String keyword, {
    int page = 1,
  }) async {
    if (keyword.trim().isEmpty) return [];
    return _sourceManager.searchAll(type, keyword, page: page);
  }

  Future<List<Work>> getAggregatedResults(
    WorkType type,
    String keyword, {
    int page = 1,
  }) async {
    final results = await search(type, keyword, page: page);
    final seen = <String>{};
    final aggregated = <Work>[];
    for (final result in results) {
      for (final work in result.works) {
        if (seen.add(work.id)) {
          aggregated.add(work);
        }
      }
    }
    return aggregated;
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/core/services/favorite_manager.dart lib/core/services/search_engine.dart
git commit -m "feat(core): add FavoriteManager and SearchEngine"
```

---


