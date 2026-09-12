### Task 2: `FollowManager` + `FollowNotifier`

**Files:**
- Create: `lib/core/services/follow_manager.dart`
- Test: `test/core/services/follow_manager_test.dart`

**Interfaces:**
- Consumes: `FollowRecord`, `Work`, `AppDatabase`.
- Produces: `FollowManager` with `all()`, `isFollowing(String)`, `follow(Work)`, `unfollow(String)`, `dirty()`, `markSynced(Set<String>)`, `mergeFromServer(List<FollowRecord>)`, and `@visibleForTesting static upsert/sortDescending/merge`; `FollowNotifier extends Notifier<List<FollowRecord>>` with `isFollowing(String)`/`toggle(Work)`; `followProvider`.

- [ ] **Step 1: Write the failing test**

Create `test/core/services/follow_manager_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acgnhub/core/models/follow_record.dart';
import 'package:acgnhub/core/models/work.dart';
import 'package:acgnhub/core/services/follow_manager.dart';
import 'package:acgnhub/core/storage/database.dart';

Work _work(String id) => Work(
      id: id,
      sourceId: 'bangumi',
      sourceName: 'Bangumi',
      type: WorkType.anime,
      title: 'Title $id',
    );

FollowRecord _record(String id, int ms, {bool dirty = false}) => FollowRecord(
      work: _work(id),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(ms),
      dirty: dirty,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('merge keeps a newer local record and takes a newer server record', () {
    final merged = FollowManager.merge(
      [_record('a', 300), _record('b', 100, dirty: true)],
      [_record('a', 200), _record('b', 500), _record('c', 400)],
    );
    final byId = {for (final r in merged) r.work.id: r};
    expect(byId['a']!.updatedAt.millisecondsSinceEpoch, 300); // local newer
    expect(byId['a']!.dirty, isFalse);
    expect(byId['b']!.updatedAt.millisecondsSinceEpoch, 500); // server newer
    expect(byId['b']!.dirty, isFalse);
    expect(byId['c']!.updatedAt.millisecondsSinceEpoch, 400); // new
  });

  test('merge applies a server tombstone', () {
    final merged = FollowManager.merge(
      [_record('a', 100)],
      [
        FollowRecord(
            work: _work('a'),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(200),
            deleted: true)
      ],
    );
    expect(merged.single.deleted, isTrue);
  });

  test('follow/unfollow/dirty/markSynced round-trip through storage', () async {
    await AppDatabase.init();
    final manager = FollowManager();

    await manager.follow(_work('a'));
    expect(manager.isFollowing('a'), isTrue);
    expect(manager.dirty().map((r) => r.work.id), ['a']);

    await manager.markSynced({'a'});
    expect(manager.dirty(), isEmpty);
    expect(manager.all().single.dirty, isFalse);

    await manager.unfollow('a');
    expect(manager.isFollowing('a'), isFalse);
    expect(manager.dirty().single.deleted, isTrue);
    expect(manager.all(), isEmpty);
  });

  test('all() orders by updatedAt descending', () async {
    await AppDatabase.init();
    final manager = FollowManager();
    await manager.follow(_work('a'));
    await Future.delayed(const Duration(milliseconds: 2));
    await manager.follow(_work('b'));
    expect(manager.all().map((r) => r.work.id), ['b', 'a']);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/services/follow_manager_test.dart`
Expected: FAIL — `follow_manager.dart` not found.

- [ ] **Step 3: Create `lib/core/services/follow_manager.dart`**

```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/follow_record.dart';
import '../models/work.dart';
import '../storage/database.dart';

class FollowManager {
  static const _key = 'follows';

  List<FollowRecord> _readAll() {
    final records = <FollowRecord>[];
    for (final raw in AppDatabase().getStringList(_key)) {
      try {
        records.add(
            FollowRecord.fromJson(json.decode(raw) as Map<String, dynamic>));
      } catch (_) {
        // Skip a malformed entry.
      }
    }
    return records;
  }

  Future<void> _save(List<FollowRecord> records) async {
    await AppDatabase().setStringList(
        _key, records.map((r) => json.encode(r.toJson())).toList());
  }

  List<FollowRecord> all() =>
      sortDescending(_readAll().where((r) => !r.deleted).toList());

  bool isFollowing(String workId) =>
      all().any((r) => r.work.id == workId);

  List<FollowRecord> dirty() => _readAll().where((r) => r.dirty).toList();

  Future<void> follow(Work work) async {
    final record = FollowRecord(work: work, updatedAt: DateTime.now(), dirty: true);
    await _save(upsert(_readAll(), record));
  }

  Future<void> unfollow(String workId) async {
    final records = _readAll();
    final existing = records.where((r) => r.work.id == workId).toList();
    if (existing.isEmpty) return;
    final tombstone = existing.first.copyWith(
        updatedAt: DateTime.now(), deleted: true, dirty: true);
    await _save(upsert(records, tombstone));
  }

  Future<void> markSynced(Set<String> workIds) async {
    final records = _readAll()
        .map((r) => workIds.contains(r.work.id) ? r.copyWith(dirty: false) : r)
        .toList();
    await _save(records);
  }

  Future<void> mergeFromServer(List<FollowRecord> server) async {
    await _save(merge(_readAll(), server));
  }

  @visibleForTesting
  static List<FollowRecord> upsert(
      List<FollowRecord> current, FollowRecord record) {
    final out = current.where((r) => r.work.id != record.work.id).toList();
    out.insert(0, record);
    return out;
  }

  @visibleForTesting
  static List<FollowRecord> sortDescending(List<FollowRecord> records) {
    final out = [...records];
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  /// LWW: a local record strictly newer than the server's is kept (still
  /// dirty); otherwise the server record wins with `dirty = false`.
  @visibleForTesting
  static List<FollowRecord> merge(
      List<FollowRecord> local, List<FollowRecord> server) {
    final byId = {for (final r in local) r.work.id: r};
    for (final item in server) {
      final existing = byId[item.work.id];
      if (existing != null && existing.updatedAt.isAfter(item.updatedAt)) {
        byId[item.work.id] = existing.copyWith(dirty: false);
      } else {
        byId[item.work.id] = item.copyWith(dirty: false);
      }
    }
    return byId.values.toList();
  }
}

class FollowNotifier extends Notifier<List<FollowRecord>> {
  final _manager = FollowManager();

  @override
  List<FollowRecord> build() => _manager.all();

  bool isFollowing(String workId) =>
      state.any((r) => r.work.id == workId);

  Future<void> toggle(Work work) async {
    if (isFollowing(work.id)) {
      await _manager.unfollow(work.id);
    } else {
      await _manager.follow(work);
    }
    state = _manager.all();
  }
}

final followProvider =
    NotifierProvider<FollowNotifier, List<FollowRecord>>(FollowNotifier.new);
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/services/follow_manager_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Analyze**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/core/services/follow_manager.dart test/core/services/follow_manager_test.dart
git commit -m "feat(sync): add FollowManager and followProvider"
```

---
