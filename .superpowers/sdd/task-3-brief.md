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
