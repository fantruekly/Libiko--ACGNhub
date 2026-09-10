### Task 3: Create SourceAdapter interface and SourceManager

**Files:**
- Create: `lib/core/source/source_adapter.dart`
- Create: `lib/core/source/source_manager.dart`
- Create: `test/core/source/source_manager_test.dart`

**Interfaces:**
- Consumes: `Work`, `Chapter`, `SearchResult`, `SourceInfo`, `WorkType` from Task 2
- Produces: `SourceAdapter` abstract class, `SourceManager` class

- [ ] **Step 1: Create directory**

```bash
mkdir -p lib\core\source
mkdir -p test\core\source
```

- [ ] **Step 2: Write SourceAdapter interface**

Create `lib/core/source/source_adapter.dart`:

```dart
import '../models/work.dart';
import '../models/chapter.dart';
import '../models/search_result.dart';
import '../models/source.dart';

abstract class SourceAdapter {
  String get id;
  String get name;
  WorkType get type;
  String get baseUrl;

  SourceInfo get info => SourceInfo(
        id: id,
        name: name,
        type: type,
        baseUrl: baseUrl,
      );

  Future<SearchResult> search(String keyword, {int page = 1});
  Future<Work> fetchDetail(String workId);
  Future<List<Chapter>> fetchChapters(String workId);
  Future<dynamic> fetchContent(String chapterId);
}
```

- [ ] **Step 3: Write SourceManager**

Create `lib/core/source/source_manager.dart`:

```dart
import 'source_adapter.dart';
import '../models/work.dart';
import '../models/search_result.dart';

class SourceManager {
  final List<SourceAdapter> _adapters = [];

  List<SourceAdapter> get adapters => List.unmodifiable(_adapters);

  void register(SourceAdapter adapter) {
    if (_adapters.any((a) => a.id == adapter.id)) {
      throw ArgumentError('Source with id "${adapter.id}" already registered');
    }
    _adapters.add(adapter);
  }

  void remove(String sourceId) {
    _adapters.removeWhere((a) => a.id == sourceId);
  }

  List<SourceAdapter> getByType(WorkType type) {
    return _adapters.where((a) => a.type == type).toList();
  }

  SourceAdapter? getById(String sourceId) {
    try {
      return _adapters.firstWhere((a) => a.id == sourceId);
    } catch (_) {
      return null;
    }
  }

  Future<List<SearchResult>> searchAll(
    WorkType type,
    String keyword, {
    int page = 1,
  }) async {
    final adapters = getByType(type);
    if (adapters.isEmpty) return [];

    final results = await Future.wait(
      adapters.map((a) => a.search(keyword, page: page)),
    );
    return results;
  }
}
```

- [ ] **Step 4: Write tests**

Create `test/core/source/source_manager_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/source/source_adapter.dart';
import 'package:acgnhub/core/source/source_manager.dart';
import 'package:acgnhub/core/models/work.dart';
import 'package:acgnhub/core/models/chapter.dart';
import 'package:acgnhub/core/models/search_result.dart';

class _MockAdapter extends SourceAdapter {
  @override
  String get id => 'mock';
  @override
  String get name => 'Mock';
  @override
  WorkType get type => WorkType.anime;
  @override
  String get baseUrl => 'https://mock.com';

  @override
  Future<SearchResult> search(String keyword, {int page = 1}) async {
    return SearchResult(works: [], totalPages: 0, currentPage: 1);
  }

  @override
  Future<Work> fetchDetail(String workId) async {
    return Work(id: workId, sourceId: id, sourceName: name, type: type, title: 'Mock');
  }

  @override
  Future<List<Chapter>> fetchChapters(String workId) async => [];
  @override
  Future<dynamic> fetchContent(String chapterId) async => null;
}

void main() {
  group('SourceManager', () {
    test('register and getByType', () {
      final manager = SourceManager();
      final adapter = _MockAdapter();
      manager.register(adapter);
      expect(manager.getByType(WorkType.anime).length, 1);
      expect(manager.getByType(WorkType.comic), isEmpty);
    });

    test('duplicate registration throws', () {
      final manager = SourceManager();
      manager.register(_MockAdapter());
      expect(() => manager.register(_MockAdapter()), throwsArgumentError);
    });

    test('remove source', () {
      final manager = SourceManager();
      manager.register(_MockAdapter());
      manager.remove('mock');
      expect(manager.adapters, isEmpty);
    });

    test('getById', () {
      final manager = SourceManager();
      manager.register(_MockAdapter());
      expect(manager.getById('mock')?.id, 'mock');
      expect(manager.getById('nonexistent'), isNull);
    });
  });
}
```

- [ ] **Step 5: Run tests**

```bash
flutter test test/core/source/source_manager_test.dart
```

Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/core/source/ test/core/source/
git commit -m "feat(core): add SourceAdapter interface and SourceManager"
```

---


