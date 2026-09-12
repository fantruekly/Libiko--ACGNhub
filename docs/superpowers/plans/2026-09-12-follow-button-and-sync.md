# Follow Button and Sync Implementation Plan (B3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A boolean 追番 button on the detail page, a 追番 home tab, and local-first two-way sync of follows and history with the B1 backend.

**Architecture:** Local stores gain per-item `updatedAt`/`deleted`/`dirty` (LWW + offline retry). `AccountApi` gains the sync/follow/history endpoints. A `SyncService` pushes dirty state, pulls `GET /api/sync?sinceSeq=<cursor>` and LWW-merges into the stores. The UI toggles follows and triggers `schedule()`.

**Tech Stack:** Flutter 3.35, Dart 3, Riverpod 2 (`NotifierProvider`), `dio`, `shared_preferences` via `AppDatabase`.

## Global Constraints

- Local-first: follows/history work fully when logged out; `sync()` is a no-op without a token.
- LWW on `updatedAt` (ms): a local record newer than the server's is kept (and stays dirty); otherwise the server record wins (`dirty = false`).
- Deletions are local tombstones (`deleted = true`, `dirty = true`) kept until pushed; a history clear also sets a `pendingClear` flag.
- Sync is silent on network failure (dirty flags persist); a 401 refreshes once and retries the whole sync once.
- `SyncService.schedule()` debounces and never runs two syncs concurrently.
- To avoid an import cycle, managers do NOT import `sync_service.dart`; the UI/notifiers call `syncProvider.notifier.schedule()` after a change.
- Persistence via `AppDatabase`: `follows`, `watch_history`, `sync_cursor`.
- Design tokens: accent `#007AFF`, muted `#8E8E93`.
- Commit after every task. Flutter commands run with `$env:Path = "C:\flutter\bin;$env:Path";` prefixed.

---

### Task 1: Models — `FollowRecord` + `WatchRecord` additions

**Files:**
- Create: `lib/core/models/follow_record.dart`
- Modify: `lib/core/models/watch_record.dart`
- Test: `test/core/models/follow_record_test.dart`, `test/core/models/watch_record_test.dart`

**Interfaces:**
- Produces: `FollowRecord{work, updatedAt, deleted, dirty}` + `fromJson`/`toJson`/`copyWith`; `WatchRecord{work, episodeTitle, episodeIndex, watchedAt, updatedAt, deleted, dirty}` + `copyWith`.

- [ ] **Step 1: Write the failing tests**

Create `test/core/models/follow_record_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/models/follow_record.dart';
import 'package:acgnhub/core/models/work.dart';

void main() {
  const work = Work(
    id: 'w1',
    sourceId: 'bangumi',
    sourceName: 'Bangumi',
    type: WorkType.anime,
    title: '葬送的芙莉莲',
    extra: {'bangumiId': 1},
  );

  test('round-trips through JSON including dirty/deleted', () {
    final record = FollowRecord(
      work: work,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      dirty: true,
    );
    final restored = FollowRecord.fromJson(record.toJson());
    expect(restored.work.id, 'w1');
    expect(restored.work.bangumiId, 1);
    expect(restored.updatedAt.millisecondsSinceEpoch, 1700000000000);
    expect(restored.deleted, isFalse);
    expect(restored.dirty, isTrue);
  });

  test('copyWith changes only the named flags', () {
    final record = FollowRecord(
        work: work, updatedAt: DateTime.fromMillisecondsSinceEpoch(1));
    final marked = record.copyWith(deleted: true, dirty: true);
    expect(marked.deleted, isTrue);
    expect(marked.dirty, isTrue);
    expect(marked.work.id, 'w1');
    expect(marked.updatedAt.millisecondsSinceEpoch, 1);
  });
}
```

Append to `test/core/models/watch_record_test.dart` (inside `main`):

```dart
  test('carries updatedAt/deleted/dirty with defaults', () {
    final record = WatchRecord(
      work: work,
      episodeTitle: '第1集',
      episodeIndex: 0,
      watchedAt: DateTime.fromMillisecondsSinceEpoch(100),
    );
    expect(record.updatedAt, record.watchedAt);
    expect(record.deleted, isFalse);
    expect(record.dirty, isFalse);

    final restored = WatchRecord.fromJson(record.copyWith(dirty: true).toJson());
    expect(restored.dirty, isTrue);
    expect(restored.updatedAt.millisecondsSinceEpoch, 100);
  });
```

(That test file already declares a `work` constant; reuse it.)

- [ ] **Step 2: Run the tests to verify they fail**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/models/follow_record_test.dart test/core/models/watch_record_test.dart`
Expected: FAIL — `follow_record.dart` not found / `copyWith` undefined.

- [ ] **Step 3: Create `lib/core/models/follow_record.dart`**

```dart
import 'work.dart';

class FollowRecord {
  final Work work;
  final DateTime updatedAt;
  final bool deleted;
  final bool dirty;

  const FollowRecord({
    required this.work,
    required this.updatedAt,
    this.deleted = false,
    this.dirty = false,
  });

  factory FollowRecord.fromJson(Map<String, dynamic> json) => FollowRecord(
        work: Work.fromJson(json['work'] as Map<String, dynamic>),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int? ?? 0),
        deleted: json['deleted'] as bool? ?? false,
        dirty: json['dirty'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'work': work.toJson(),
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'deleted': deleted,
        'dirty': dirty,
      };

  FollowRecord copyWith({DateTime? updatedAt, bool? deleted, bool? dirty}) =>
      FollowRecord(
        work: work,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
        dirty: dirty ?? this.dirty,
      );
}
```

- [ ] **Step 4: Extend `lib/core/models/watch_record.dart`**

Replace the class with:

```dart
class WatchRecord {
  final Work work;
  final String episodeTitle;
  final int episodeIndex;
  final DateTime watchedAt;
  final DateTime updatedAt;
  final bool deleted;
  final bool dirty;

  WatchRecord({
    required this.work,
    required this.episodeTitle,
    required this.episodeIndex,
    required this.watchedAt,
    DateTime? updatedAt,
    this.deleted = false,
    this.dirty = false,
  }) : updatedAt = updatedAt ?? watchedAt;

  factory WatchRecord.fromJson(Map<String, dynamic> json) {
    final watchedAt =
        DateTime.fromMillisecondsSinceEpoch(json['watchedAt'] as int? ?? 0);
    final updatedMs = json['updatedAt'] as int?;
    return WatchRecord(
      work: Work.fromJson(json['work'] as Map<String, dynamic>),
      episodeTitle: json['episodeTitle'] as String? ?? '',
      episodeIndex: json['episodeIndex'] as int? ?? 0,
      watchedAt: watchedAt,
      updatedAt: updatedMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(updatedMs),
      deleted: json['deleted'] as bool? ?? false,
      dirty: json['dirty'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'work': work.toJson(),
        'episodeTitle': episodeTitle,
        'episodeIndex': episodeIndex,
        'watchedAt': watchedAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'deleted': deleted,
        'dirty': dirty,
      };

  WatchRecord copyWith({
    String? episodeTitle,
    int? episodeIndex,
    DateTime? watchedAt,
    DateTime? updatedAt,
    bool? deleted,
    bool? dirty,
  }) =>
      WatchRecord(
        work: work,
        episodeTitle: episodeTitle ?? this.episodeTitle,
        episodeIndex: episodeIndex ?? this.episodeIndex,
        watchedAt: watchedAt ?? this.watchedAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
        dirty: dirty ?? this.dirty,
      );
}
```

(Keep the existing `import 'work.dart';`.)

- [ ] **Step 5: Run the tests to verify they pass**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/models/`
Expected: PASS.

- [ ] **Step 6: Analyze and run the full suite**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → all pass (the existing history tests still compile because the new fields are optional/defaulted).

- [ ] **Step 7: Commit**

```bash
git add lib/core/models/follow_record.dart lib/core/models/watch_record.dart test/core/models/
git commit -m "feat(sync): add FollowRecord and sync fields on WatchRecord"
```

---

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

### Task 3: `WatchHistoryManager` sync fields

**Files:**
- Modify: `lib/core/services/watch_history.dart`
- Test: `test/core/services/watch_history_test.dart`

**Interfaces:**
- Produces: `WatchHistoryManager.dirty()`, `markSynced(Set<String>)`, `mergeFromServer(List<WatchRecord>)`, `pendingClear`/`clearPendingClear()`, and `@visibleForTesting static merge(...)`; `record()`/`clear()` set the new fields.

- [ ] **Step 1: Add the failing tests**

Append to `test/core/services/watch_history_test.dart` (inside `main`; reuse the file's `_work`/`_record` helpers if present, otherwise define locals):

```dart
  test('merge keeps a newer local record and takes a newer server record', () {
    final merged = WatchHistoryManager.merge(
      [_record('a', '第1集', 300), _record('b', '第1集', 100)],
      [_record('a', '第0集', 200), _record('b', '第9集', 500)],
    );
    final byId = {for (final r in merged) r.work.id: r};
    expect(byId['a']!.episodeTitle, '第1集');
    expect(byId['b']!.episodeTitle, '第9集');
    expect(merged.every((r) => !r.dirty), isTrue);
  });

  test('record marks dirty and clear writes tombstones plus pendingClear', () async {
    SharedPreferences.setMockInitialValues({});
    await AppDatabase.init();
    final manager = WatchHistoryManager();

    const ep = VideoEpisode(id: 'e1', title: '第1集', index: 0, playUrl: 'u');
    await manager.record(_work('a'), ep);
    expect(manager.dirty().single.work.id, 'a');

    await manager.clear();
    expect(manager.all(), isEmpty);
    expect(manager.pendingClear, isTrue);
    expect(manager.dirty().single.deleted, isTrue);

    await manager.clearPendingClear();
    expect(manager.pendingClear, isFalse);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/services/watch_history_test.dart`
Expected: FAIL — `merge`/`dirty`/`pendingClear` undefined.

- [ ] **Step 3: Update `lib/core/services/watch_history.dart`**

Add `static const _kPendingClear = 'watch_history_pending_clear';` and change `all()`/`record()`/`clear()`, then add the new members:

```dart
  List<WatchRecord> all() =>
      sortDescending(_readAll().where((r) => !r.deleted).toList());

  List<WatchRecord> dirty() => _readAll().where((r) => r.dirty).toList();

  bool get pendingClear => AppDatabase().getBool(_kPendingClear) ?? false;

  Future<void> clearPendingClear() async {
    await AppDatabase().remove(_kPendingClear);
  }

  Future<void> record(Work work, VideoEpisode episode) {
    final next = _pending.then((_) async {
      final now = DateTime.now();
      final record = WatchRecord(
        work: work,
        episodeTitle: episode.title,
        episodeIndex: episode.index,
        watchedAt: now,
        updatedAt: now,
        dirty: true,
      );
      await _save(upsert(_readAll(), record));
    });
    _pending = next.catchError((_) {});
    return next;
  }

  Future<void> clear() {
    final next = _pending.then((_) async {
      final tombstones = _readAll()
          .where((r) => !r.deleted)
          .map((r) => r.copyWith(
              deleted: true, dirty: true, updatedAt: DateTime.now()))
          .toList();
      for (final tombstone in tombstones) {
        await _save(upsert(_readAll(), tombstone));
      }
      await AppDatabase().setBool(_kPendingClear, true);
    });
    _pending = next.catchError((_) {});
    return next;
  }

  Future<void> markSynced(Set<String> workIds) async {
    final records = _readAll()
        .map((r) => workIds.contains(r.work.id) ? r.copyWith(dirty: false) : r)
        .toList();
    await _save(records);
  }

  Future<void> mergeFromServer(List<WatchRecord> server) async {
    await _save(merge(_readAll(), server));
  }

  @visibleForTesting
  static List<WatchRecord> merge(
      List<WatchRecord> local, List<WatchRecord> server) {
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
```

Also rename the existing private reader to `_readAll()` (it currently builds and sorts) and make `_save` write the full list — keep the existing `upsert`/`sortDescending` statics. `all()` must filter `deleted` before sorting.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/services/watch_history_test.dart`
Expected: PASS (existing + new tests).

- [ ] **Step 5: Analyze and run the full suite**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/core/services/watch_history.dart test/core/services/watch_history_test.dart
git commit -m "feat(sync): add dirty/tombstone/merge support to watch history"
```

---

### Task 4: `AccountApi` + models — sync/follow/history endpoints

**Files:**
- Modify: `lib/core/account/account_models.dart`
- Modify: `lib/core/account/account_api.dart`
- Test: `test/core/account/account_api_test.dart`

**Interfaces:**
- Produces: `SyncPage{follows, history, nextSeq}`, `FollowItem{work, updatedAt, deleted}`, `HistoryItem{work, episodeTitle, episodeIndex, watchedAt, updatedAt, deleted}`; `AccountApi.sync(String token, int sinceSeq)`, `putFollow(String token, Map<String,dynamic> work, int updatedAt)`, `deleteFollow(String token, String workId, int updatedAt)`, `putHistory(String token, Map<String,dynamic> work, String episodeTitle, int episodeIndex, int watchedAt, int updatedAt)`, `clearHistory(String token, int updatedAt)`.

- [ ] **Step 1: Add the failing tests**

Append to `test/core/account/account_api_test.dart` (inside `main`):

```dart
  test('sync parses the page and sends sinceSeq', () async {
    final adapter = _FakeAdapter(
      200,
      jsonEncode({
        'follows': [
          {'work': {'id': 'w1'}, 'updatedAt': 5, 'deleted': false}
        ],
        'history': [
          {
            'work': {'id': 'w1'},
            'episodeTitle': '第3集',
            'episodeIndex': 2,
            'watchedAt': 9,
            'updatedAt': 9,
            'deleted': false,
          }
        ],
        'nextSeq': 4,
      }),
    );
    final page = await _api(adapter).sync('tok', 3);

    expect(page.nextSeq, 4);
    expect(page.follows.single.work['id'], 'w1');
    expect(page.history.single.episodeTitle, '第3集');
    expect(adapter.last!.uri.queryParameters['sinceSeq'], '3');
    expect(adapter.last!.headers['authorization'], 'Bearer tok');
  });

  test('putFollow posts the work and updatedAt', () async {
    final adapter = _FakeAdapter(200, jsonEncode({'work': {}, 'updatedAt': 5}));
    await _api(adapter).putFollow('tok', {'id': 'w1'}, 5);
    expect(adapter.last!.method, 'PUT');
    expect(adapter.last!.uri.path, '/api/follows');
    expect(adapter.last!.data, {'work': {'id': 'w1'}, 'updatedAt': 5});
  });

  test('deleteFollow sends workId and updatedAt as a query parameter', () async {
    final adapter = _FakeAdapter(200, jsonEncode({'workId': 'w1'}));
    await _api(adapter).deleteFollow('tok', 'w1', 7);
    expect(adapter.last!.method, 'DELETE');
    expect(adapter.last!.uri.path, '/api/follows/w1');
    expect(adapter.last!.uri.queryParameters['updatedAt'], '7');
  });

  test('putHistory posts the episode fields', () async {
    final adapter = _FakeAdapter(200, jsonEncode({}));
    await _api(adapter).putHistory('tok', {'id': 'w1'}, '第3集', 2, 9, 9);
    expect(adapter.last!.uri.path, '/api/history');
    expect(adapter.last!.data, {
      'work': {'id': 'w1'},
      'episodeTitle': '第3集',
      'episodeIndex': 2,
      'watchedAt': 9,
      'updatedAt': 9,
    });
  });

  test('clearHistory deletes with updatedAt', () async {
    final adapter = _FakeAdapter(200, jsonEncode({'deleted': 2}));
    await _api(adapter).clearHistory('tok', 11);
    expect(adapter.last!.method, 'DELETE');
    expect(adapter.last!.uri.path, '/api/history');
    expect(adapter.last!.uri.queryParameters['updatedAt'], '11');
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/account/account_api_test.dart`
Expected: FAIL — `sync`/`putFollow`/... undefined.

- [ ] **Step 3: Add the models to `lib/core/account/account_models.dart`**

```dart
class FollowItem {
  final Map<String, dynamic> work;
  final int updatedAt;
  final bool deleted;
  const FollowItem(
      {required this.work, required this.updatedAt, required this.deleted});

  factory FollowItem.fromJson(Map<String, dynamic> json) => FollowItem(
        work: json['work'] as Map<String, dynamic>? ?? const {},
        updatedAt: json['updatedAt'] as int? ?? 0,
        deleted: json['deleted'] as bool? ?? false,
      );
}

class HistoryItem {
  final Map<String, dynamic> work;
  final String episodeTitle;
  final int episodeIndex;
  final int watchedAt;
  final int updatedAt;
  final bool deleted;
  const HistoryItem({
    required this.work,
    required this.episodeTitle,
    required this.episodeIndex,
    required this.watchedAt,
    required this.updatedAt,
    required this.deleted,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
        work: json['work'] as Map<String, dynamic>? ?? const {},
        episodeTitle: json['episodeTitle'] as String? ?? '',
        episodeIndex: json['episodeIndex'] as int? ?? 0,
        watchedAt: json['watchedAt'] as int? ?? 0,
        updatedAt: json['updatedAt'] as int? ?? 0,
        deleted: json['deleted'] as bool? ?? false,
      );
}

class SyncPage {
  final List<FollowItem> follows;
  final List<HistoryItem> history;
  final int nextSeq;
  const SyncPage(
      {required this.follows, required this.history, required this.nextSeq});

  factory SyncPage.fromJson(Map<String, dynamic> json) => SyncPage(
        follows: (json['follows'] as List<dynamic>? ?? const [])
            .map((e) => FollowItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        history: (json['history'] as List<dynamic>? ?? const [])
            .map((e) => HistoryItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        nextSeq: json['nextSeq'] as int? ?? 0,
      );
}
```

- [ ] **Step 4: Add the endpoints to `lib/core/account/account_api.dart`**

```dart
  Future<SyncPage> sync(String token, int sinceSeq) async {
    final json = await _request(() => _dio.get(
          '$baseUrl/api/sync?sinceSeq=$sinceSeq',
          options: Options(headers: {'authorization': 'Bearer $token'}),
        ));
    return SyncPage.fromJson(json);
  }

  Future<void> putFollow(
      String token, Map<String, dynamic> work, int updatedAt) async {
    await _request(() => _dio.put('$baseUrl/api/follows',
        data: {'work': work, 'updatedAt': updatedAt},
        options: Options(headers: {'authorization': 'Bearer $token'})));
  }

  Future<void> deleteFollow(String token, String workId, int updatedAt) async {
    await _request(() => _dio.delete(
          '$baseUrl/api/follows/$workId?updatedAt=$updatedAt',
          options: Options(headers: {'authorization': 'Bearer $token'}),
        ));
  }

  Future<void> putHistory(String token, Map<String, dynamic> work,
      String episodeTitle, int episodeIndex, int watchedAt, int updatedAt) async {
    await _request(() => _dio.put('$baseUrl/api/history',
        data: {
          'work': work,
          'episodeTitle': episodeTitle,
          'episodeIndex': episodeIndex,
          'watchedAt': watchedAt,
          'updatedAt': updatedAt,
        },
        options: Options(headers: {'authorization': 'Bearer $token'})));
  }

  Future<void> clearHistory(String token, int updatedAt) async {
    await _request(() => _dio.delete(
          '$baseUrl/api/history?updatedAt=$updatedAt',
          options: Options(headers: {'authorization': 'Bearer $token'}),
        ));
  }
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/account/account_api_test.dart`
Expected: PASS.

- [ ] **Step 6: Analyze and run the full suite**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → all pass.

- [ ] **Step 7: Commit**

```bash
git add lib/core/account/account_models.dart lib/core/account/account_api.dart test/core/account/account_api_test.dart
git commit -m "feat(sync): add sync/follow/history endpoints to AccountApi"
```

---

### Task 5: `SyncService` + triggers

**Files:**
- Create: `lib/core/account/sync_service.dart`
- Modify: `lib/core/account/account_service.dart` (trigger after login/register)
- Modify: `lib/modules/anime/video_player_page.dart` (trigger after recording)
- Modify: `lib/modules/anime/anime_history.dart` (trigger after clearing)
- Test: `test/core/account/sync_service_test.dart`

**Interfaces:**
- Consumes: `AccountApi`/`AccountException`/`SyncPage`, `accountProvider`, `FollowManager`, `WatchHistoryManager`, `AppDatabase`.
- Produces: `class SyncService { SyncService({AccountApi Function(String)? apiFactory, FollowManager? follows, WatchHistoryManager? history}); Future<void> sync(); void schedule(); }`; `final syncProvider = Provider<SyncService>(...)`.

- [ ] **Step 1: Write the failing test**

Create `test/core/account/sync_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acgnhub/core/account/account_api.dart';
import 'package:acgnhub/core/account/account_models.dart';
import 'package:acgnhub/core/account/sync_service.dart';
import 'package:acgnhub/core/models/work.dart';
import 'package:acgnhub/core/services/follow_manager.dart';
import 'package:acgnhub/core/services/watch_history.dart';
import 'package:acgnhub/core/storage/database.dart';
import 'package:acgnhub/core/video/video_source.dart';

Work _work(String id) => Work(
    id: id,
    sourceId: 'bangumi',
    sourceName: 'Bangumi',
    type: WorkType.anime,
    title: 'Title $id');

class _FakeApi implements AccountApi {
  _FakeApi({this.syncPage, this.unauthorizedOnce = false});
  SyncPage? syncPage;
  bool unauthorizedOnce;
  final putFollows = <String>[];
  final deleteFollows = <String>[];
  final putHistory = <String>[];
  int clearHistoryCalls = 0;
  int syncCalls = 0;

  @override
  String get baseUrl => 'http://127.0.0.1:8080';

  @override
  Future<SyncPage> sync(String token, int sinceSeq) async {
    syncCalls++;
    if (unauthorizedOnce && syncCalls == 1) {
      throw const AccountException(statusCode: 401, code: 'unauthorized', message: 'expired');
    }
    return syncPage ?? const SyncPage(follows: [], history: [], nextSeq: sinceSeq);
  }

  @override
  Future<void> putFollow(String token, Map<String, dynamic> work, int updatedAt) async =>
      putFollows.add(work['id'] as String);

  @override
  Future<void> deleteFollow(String token, String workId, int updatedAt) async =>
      deleteFollows.add(workId);

  @override
  Future<void> putHistory(String token, Map<String, dynamic> work,
          String episodeTitle, int episodeIndex, int watchedAt, int updatedAt) async =>
      putHistory.add(work['id'] as String);

  @override
  Future<void> clearHistory(String token, int updatedAt) async =>
      clearHistoryCalls++;

  @override
  Future<AuthSession> register(String username, String password) async =>
      throw UnimplementedError();

  @override
  Future<AuthSession> login(String username, String password) async =>
      throw UnimplementedError();

  @override
  Future<String> refresh(String refreshToken) async => 'new-token';

  @override
  Future<AccountUser> me(String token) async =>
      const AccountUser(id: 1, username: 'alice');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('pushes dirty follows and history then pulls and advances the cursor', () async {
    await AppDatabase.init();
    final api = _FakeApi(
      syncPage: SyncPage(
        follows: [
          FollowItem(
              work: _work('server').toJson(), updatedAt: 500, deleted: false)
        ],
        history: const [],
        nextSeq: 9,
      ),
    );
    final follows = FollowManager();
    final history = WatchHistoryManager();
    await follows.follow(_work('local'));
    await history.record(
        _work('h'), const VideoEpisode(id: 'e', title: '第1集', index: 0, playUrl: 'u'));
    await AppDatabase().setString('account_token', 'tok');

    await SyncService(apiFactory: (_) => api, follows: follows, history: history)
        .sync();

    expect(api.putFollows, ['local']);
    expect(api.putHistory, ['h']);
    expect(follows.dirty(), isEmpty);
    expect(history.dirty(), isEmpty);
    expect(follows.isFollowing('server'), isTrue);
    expect(AppDatabase().getString('sync_cursor'), '9');
  });

  test('a history pendingClear pushes a clear instead of per-record puts', () async {
    await AppDatabase.init();
    final api = _FakeApi();
    final history = WatchHistoryManager();
    await history.record(
        _work('h'), const VideoEpisode(id: 'e', title: '第1集', index: 0, playUrl: 'u'));
    await history.clear();
    await AppDatabase().setString('account_token', 'tok');

    await SyncService(apiFactory: (_) => api, follows: FollowManager(), history: history)
        .sync();

    expect(api.clearHistoryCalls, 1);
    expect(api.putHistory, isEmpty);
    expect(history.pendingClear, isFalse);
    expect(history.dirty(), isEmpty);
  });

  test('a network failure leaves dirty flags set', () async {
    await AppDatabase.init();
    final api = _NetworkFailApi();
    final follows = FollowManager();
    await follows.follow(_work('local'));
    await AppDatabase().setString('account_token', 'tok');

    await SyncService(apiFactory: (_) => api, follows: follows, history: WatchHistoryManager())
        .sync();

    expect(follows.dirty(), isNotEmpty);
  });

  test('a 401 refreshes and retries the sync once', () async {
    await AppDatabase.init();
    final api = _FakeApi(unauthorizedOnce: true);
    final follows = FollowManager();
    await follows.follow(_work('local'));
    await AppDatabase().setString('account_token', 'tok');

    final service = SyncService(
        apiFactory: (_) => api,
        follows: follows,
        history: WatchHistoryManager());
    var refreshes = 0;
    service.refreshSession = () async {
      refreshes++;
      return true;
    };

    await service.sync();

    expect(refreshes, 1);
    expect(api.syncCalls, 2);
    expect(follows.dirty(), isEmpty);
  });

  test('no token is a no-op', () async {
    await AppDatabase.init();
    final api = _FakeApi();
    await SyncService(apiFactory: (_) => api, follows: FollowManager(), history: WatchHistoryManager())
        .sync();
    expect(api.syncCalls, 0);
  });
}

class _NetworkFailApi extends _FakeApi {
  @override
  Future<SyncPage> sync(String token, int sinceSeq) async {
    throw const AccountException(code: 'network', message: '网络错误');
  }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/account/sync_service_test.dart`
Expected: FAIL — `sync_service.dart` not found.

- [ ] **Step 3: Create `lib/core/account/sync_service.dart`**

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/follow_record.dart';
import '../models/watch_record.dart';
import '../services/follow_manager.dart';
import '../services/watch_history.dart';
import '../storage/database.dart';
import 'account_api.dart';
import 'account_models.dart';
import 'account_service.dart';

const _kCursor = 'sync_cursor';

class SyncService {
  SyncService({
    AccountApi Function(String baseUrl)? apiFactory,
    FollowManager? follows,
    WatchHistoryManager? history,
  })  : _apiFactory = apiFactory ?? ((baseUrl) => AccountApi(baseUrl)),
        _follows = follows ?? FollowManager(),
        _history = history ?? WatchHistoryManager();

  final AccountApi Function(String baseUrl) _apiFactory;
  final FollowManager _follows;
  final WatchHistoryManager _history;

  bool _running = false;
  Timer? _debounce;

  /// Coalesces bursts of local changes into one background sync.
  void schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () => sync());
  }

  Future<void> sync() async {
    if (_running) return;
    final db = AppDatabase();
    final token = db.getString('account_token');
    if (token == null) return;

    _running = true;
    try {
      await _run(db, token);
    } finally {
      _running = false;
    }
  }

  Future<void> _run(AppDatabase db, String token) async {
    try {
      await _push(db, token);
      await _pull(db, token);
    } on AccountException catch (e) {
      if (e.statusCode != 401) return; // network/other: retry next time
      if (!await _refresh()) return;
      final refreshed = db.getString('account_token');
      if (refreshed == null) return;
      try {
        await _push(db, refreshed);
        await _pull(db, refreshed);
      } on AccountException {
        return;
      }
    }
  }

  Future<void> _push(AppDatabase db, String token) async {
    final api = _apiFactory(_baseUrl(db));
    final syncedFollows = <String>{};
    for (final record in _follows.dirty()) {
      if (record.deleted) {
        await api.deleteFollow(
            token, record.work.id, record.updatedAt.millisecondsSinceEpoch);
      } else {
        await api.putFollow(token, record.work.toJson(),
            record.updatedAt.millisecondsSinceEpoch);
      }
      syncedFollows.add(record.work.id);
    }
    if (syncedFollows.isNotEmpty) await _follows.markSynced(syncedFollows);

    final syncedHistory = <String>{};
    if (_history.pendingClear) {
      await api.clearHistory(token, DateTime.now().millisecondsSinceEpoch);
      for (final record in _history.dirty()) {
        syncedHistory.add(record.work.id);
      }
      await _history.clearPendingClear();
    } else {
      for (final record in _history.dirty()) {
        await api.putHistory(
          token,
          record.work.toJson(),
          record.episodeTitle,
          record.episodeIndex,
          record.watchedAt.millisecondsSinceEpoch,
          record.updatedAt.millisecondsSinceEpoch,
        );
        syncedHistory.add(record.work.id);
      }
    }
    if (syncedHistory.isNotEmpty) await _history.markSynced(syncedHistory);
  }

  Future<void> _pull(AppDatabase db, String token) async {
    final sinceSeq = int.tryParse(db.getString(_kCursor) ?? '0') ?? 0;
    final page = await _apiFactory(_baseUrl(db)).sync(token, sinceSeq);

    await _follows.mergeFromServer(page.follows
        .map((item) => FollowRecord(
              work: Work.fromJson(item.work),
              updatedAt:
                  DateTime.fromMillisecondsSinceEpoch(item.updatedAt),
              deleted: item.deleted,
            ))
        .toList());

    await _history.mergeFromServer(page.history
        .map((item) => WatchRecord(
              work: Work.fromJson(item.work),
              episodeTitle: item.episodeTitle,
              episodeIndex: item.episodeIndex,
              watchedAt: DateTime.fromMillisecondsSinceEpoch(item.watchedAt),
              updatedAt: DateTime.fromMillisecondsSinceEpoch(item.updatedAt),
              deleted: item.deleted,
            ))
        .toList());

    await db.setString(_kCursor, page.nextSeq.toString());
  }

  String _baseUrl(AppDatabase db) =>
      db.getString('account_base_url') ?? kDefaultBaseUrl;

  Future<bool> _refresh() async {
    // AccountNotifier.refreshSession needs a ProviderContainer; the service is
    // constructed with a callback instead so it stays testable.
    return _refreshSession?.call() ?? false;
  }

  Future<bool> Function()? _refreshSession;

  set refreshSession(Future<bool> Function() value) => _refreshSession = value;
}

final syncProvider = Provider<SyncService>((ref) => SyncService());
```

`Work` needs importing: add `import '../models/work.dart';`.

Hmm — the 401 retry needs `accountProvider.notifier.refreshSession()`. Wiring that into a plain `SyncService` is awkward. Simplify: give `SyncService` a `Future<bool> Function()? refreshSession` setter, and wire it in the provider:

```dart
final syncProvider = Provider<SyncService>((ref) {
  final service = SyncService();
  service.refreshSession = () => ref.read(accountProvider.notifier).refreshSession();
  return service;
});
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/account/sync_service_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Wire the triggers**

- `lib/core/account/account_service.dart`: at the end of `_authenticate`'s success branch, after setting state, add
  `ref.read(syncProvider.notifier).schedule();` (add `import 'sync_service.dart';`).
- `lib/modules/anime/video_player_page.dart`: after `await history.record(work, episode);` add
  `ref.read(syncProvider.notifier).schedule();` (add `import '../../core/account/sync_service.dart';`).
- `lib/modules/anime/anime_history.dart`: after `await ref.read(watchHistoryProvider.notifier).clear();` add
  `ref.read(syncProvider.notifier).schedule();` (add the import).
- `lib/main.dart`: after the startup `unawaited(container.read(accountProvider.notifier).load());` add
  `unawaited(container.read(accountProvider.notifier).load().then((_) => container.read(syncProvider.notifier).sync()));`
  — i.e. chain a one-shot sync after the load future. (Replace the existing single `unawaited(...load())` line with a
  single `unawaited(container.read(accountProvider.notifier).load().then((_) => container.read(syncProvider.notifier).sync()));`
  and add `import 'core/account/sync_service.dart';`.)

- [ ] **Step 6: Analyze and run the full suite**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → all pass.

- [ ] **Step 7: Commit**

```bash
git add lib/core/account/sync_service.dart lib/core/account/account_service.dart lib/modules/anime/video_player_page.dart lib/modules/anime/anime_history.dart lib/main.dart test/core/account/sync_service_test.dart
git commit -m "feat(sync): add SyncService and its triggers"
```

---

### Task 6: UI — 追番 button + 追番 tab

**Files:**
- Modify: `lib/modules/anime/anime_detail_page.dart`
- Create: `lib/modules/anime/anime_follow.dart`
- Modify: `lib/modules/anime/anime_home.dart`

**Interfaces:**
- Consumes: `followProvider` (Task 2), `syncProvider` (Task 5), `WorkCard`, `AnimeDetailPage`, `smoothRoute`, `EmptyState`.
- Produces: the header button; `class AnimeFollowView extends ConsumerWidget`; a 5th home tab.

- [ ] **Step 1: Add the follow button to `_header`**

In `lib/modules/anime/anime_detail_page.dart`, add `import 'package:flutter_riverpod/flutter_riverpod.dart';` (already present) and
`import '../../core/services/follow_manager.dart';` plus `import '../../core/account/sync_service.dart';`.

In `_header`, insert immediately before `const WindowControls(),`:

```dart
            Consumer(builder: (context, ref, _) {
              final followed = ref.watch(followProvider).any((r) => r.work.id == w.id);
              return IconButton(
                tooltip: followed ? '已追番' : '追番',
                icon: Icon(
                  followed ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: followed ? const Color(0xFF007AFF) : const Color(0xFF8E8E93),
                ),
                onPressed: () {
                  ref.read(followProvider.notifier).toggle(w);
                  ref.read(syncProvider.notifier).schedule();
                },
              );
            }),
```

- [ ] **Step 2: Create `lib/modules/anime/anime_follow.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/follow_manager.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/smooth_route.dart';
import '../../core/widgets/work_card.dart';
import 'anime_detail_page.dart';

class AnimeFollowView extends ConsumerWidget {
  const AnimeFollowView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(followProvider);

    if (records.isEmpty) {
      return const EmptyState(icon: Icons.favorite_border_rounded, message: '还没有追番');
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.66,
      ),
      itemCount: records.length,
      itemBuilder: (_, i) {
        final work = records[i].work;
        return WorkCard(
          work: work,
          onTap: () =>
              Navigator.push(context, smoothRoute(AnimeDetailPage(work: work))),
        );
      },
    );
  }
}
```

- [ ] **Step 3: Add the 5th tab in `lib/modules/anime/anime_home.dart`**

Add `import 'anime_follow.dart';`, change `length: 4` to `length: 5`, add `Tab(text: '追番')` after 历史记录, and add `_heroTab(controller, 4, const AnimeFollowView()),` to the `TabBarView` children.

- [ ] **Step 4: Analyze, test, build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → all pass.
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug` → built.

- [ ] **Step 5: Commit**

```bash
git add lib/modules/anime/anime_detail_page.dart lib/modules/anime/anime_follow.dart lib/modules/anime/anime_home.dart
git commit -m "feat(follow): add the detail-page follow button and the 追番 tab"
```

---

### Task 7: Final verification (incl. an end-to-end probe)

**Files:**
- Create: `.superpowers/sdd/sync_probe.dart` (a throwaway Flutter target, not committed)

- [ ] **Step 1: Analyze and test**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → all pass.
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug` → built.

- [ ] **Step 2: End-to-end probe**

Start the backend locally (`cd server`; `ACGHUB_JWT_SECRET=probe-secret`, `ACGHUB_DB_PATH` in a temp dir, `PORT=8080`; run `C:\flutter\bin\cache\dart-sdk\bin\dart.exe run bin/server.dart` detached). Write `.superpowers/sdd/sync_probe.dart` that:
1. registers a fresh account via `AccountApi`,
2. stores the token + base URL in `AppDatabase`,
3. follows a work through `FollowManager`, records a history entry through `WatchHistoryManager`,
4. runs `SyncService().sync()`,
5. asserts the dirty flags cleared and `sync_cursor` advanced,
6. runs `sync()` again and confirms `GET /api/sync` returns nothing new.

Run it with `flutter run -d windows -t .superpowers/sdd/sync_probe.dart`, capture the output, then stop the server and delete the temp DB.

- [ ] **Step 3: Record the observed result**

Write the probe output into the task report.

---

## Self-Review

- **Spec coverage:** §3 models → Task 1; `FollowManager`/`FollowNotifier` → Task 2; history dirty/tombstone/merge → Task 3; §4 `AccountApi` → Task 4; §5 `SyncService` + triggers → Task 5; §6 UI → Task 6; §8 testing → Tasks 1–5, 7.
- **Placeholders:** none — every step has complete code or an exact command.
- **Type consistency:** `FollowRecord{work, updatedAt, deleted, dirty}`; `WatchRecord{..., updatedAt, deleted, dirty}`; `FollowManager.all/isFollowing/follow/unfollow/dirty/markSynced/mergeFromServer/upsert/sortDescending/merge`; `followProvider`; `WatchHistoryManager.dirty/markSynced/mergeFromServer/pendingClear/clearPendingClear/merge`; `SyncPage/FollowItem/HistoryItem`; `AccountApi.sync/putFollow/deleteFollow/putHistory/clearHistory`; `SyncService.sync/schedule/refreshSession`; `syncProvider`; `AnimeFollowView` — used consistently across tasks.
