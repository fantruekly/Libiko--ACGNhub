# Task 3 Report: `WatchHistoryManager` sync fields

## What I implemented

Extended `WatchHistoryManager` in `lib/core/services/watch_history.dart` with the sync
surface Task 5's sync service needs, following the brief exactly:

- Renamed the private reader to `_readAll()` — returns the raw stored list (unsorted,
  unfiltered, malformed entries skipped).
- `all()` now filters out `deleted` records and then sorts descending.
- `dirty()` returns stored records with `dirty == true`.
- `pendingClear` getter reads the `watch_history_pending_clear` bool (default `false`).
- `clearPendingClear()` removes that flag.
- `record()` sets `watchedAt`/`updatedAt` to `now` and `dirty: true`, saving via
  `upsert(_readAll(), record)`; still serialised on the `_pending` future.
- `clear()` writes a tombstone (`deleted: true, dirty: true, updatedAt: now`) for every
  live record, then sets the `pendingClear` flag; still serialised on `_pending`.
- `markSynced(Set<String> workIds)` clears `dirty` on matching records.
- `mergeFromServer(List<WatchRecord>)` persists `merge(_readAll(), server)`.
- `@visibleForTesting static merge(local, server)` — per work id, keeps the newer of
  local/server by `updatedAt` and always clears `dirty` on the merged result.
- Kept `_save` writing the full list and kept the `upsert`/`sortDescending` statics.

## What I tested and results

Appended two tests to `test/core/services/watch_history_test.dart` (reusing the file's
existing `_work`/`_record` helpers):

1. `merge keeps a newer local record and takes a newer server record` — asserts local
   `a` (updatedAt 300) beats server `a` (200), server `b` (500) beats local `b` (100),
   and every merged record is `dirty == false`.
2. `record marks dirty and clear writes tombstones plus pendingClear` — records a work,
   asserts `dirty().single.work.id == 'a'`; clears, asserts `all()` empty,
   `pendingClear == true`, `dirty().single.deleted == true`; calls `clearPendingClear()`
   and asserts `pendingClear == false`.

Results:
- Focused: `flutter test test/core/services/watch_history_test.dart` → `00:00 +6: All tests passed!`
- `flutter analyze lib test` → `No issues found! (ran in 2.1s)`
- Full suite: `flutter test` → `00:08 +98: All tests passed!`

The pre-existing persistence/dedupe/clear/malformed-entry test still passes, and
`clear()` no longer deletes the storage key, so its final `all()` check remains empty
because the only record is now a filtered tombstone.

## TDD evidence

### RED

Command: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/services/watch_history_test.dart`

Output (excerpt):

```
test/core/services/watch_history_test.dart:76:40: Error: Member not found: 'WatchHistoryManager.merge'.
test/core/services/watch_history_test.dart:93:20: Error: The method 'dirty' isn't defined for the type 'WatchHistoryManager'.
test/core/services/watch_history_test.dart:97:20: Error: The getter 'pendingClear' isn't defined for the type 'WatchHistoryManager'.
test/core/services/watch_history_test.dart:98:20: Error: The method 'dirty' isn't defined for the type 'WatchHistoryManager'.
test/core/services/watch_history_test.dart:100:19: Error: The method 'clearPendingClear' isn't defined for the type 'WatchHistoryManager'.
00:00 +0 -1: Some tests failed.
```

Why expected: the tests exercise members that did not yet exist, so the test file failed
to compile before implementation.

### GREEN

Command: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/services/watch_history_test.dart`

Output (excerpt):

```
00:00 +0: upsert dedupes by work id and puts the new record first
00:00 +1: upsert inserts a new work at the front
00:00 +2: sortDescending orders by watchedAt newest first
00:00 +3: persists, dedupes, clears, and skips malformed stored entries
00:00 +4: merge keeps a newer local record and takes a newer server record
00:00 +5: record marks dirty and clear writes tombstones plus pendingClear
00:00 +6: All tests passed!
```

## Files changed

- `lib/core/services/watch_history.dart` (modified)
- `test/core/services/watch_history_test.dart` (modified, two tests appended)

Commit: `7796fcb feat(sync): add dirty/tombstone/merge support to watch history`
(2 files changed, 83 insertions(+), 5 deletions(-))

## Self-review findings

- Completeness: all interfaces the brief lists are produced; `record()`/`clear()` set the
  new fields; `all()` filters before sorting; `_readAll()` is the raw reader; `_save`
  writes the full list; `upsert`/`sortDescending` retained.
- Quality: code matches the brief verbatim; existing serialisation on `_pending` for
  `record()`/`clear()` preserved.
- YAGNI: no members or behavior beyond the brief.
- Tests verify real behavior (round-trips through `AppDatabase`/`SharedPreferences`), not
  just the pure `merge` static; they confirm tombstones survive as `dirty` while being
  hidden from `all()`.

## Concerns

- `clear()` writes tombstones one at a time, each iteration re-reading and re-writing the
  whole list (`O(n²)` I/O). This is exactly what the brief specifies, so I left it as-is;
  a single batched `_save` would be more efficient if history grows large.
- `markSynced()` and `mergeFromServer()` are `async` but not serialised on the `_pending`
  future (unlike `record()`/`clear()`), per the brief. If Task 5 calls them concurrently
  with a `record()`/`clear()`, a last-writer-wins race is possible. Flagging for Task 5.
- `merge()` clears `dirty` on any server-supplied record, including when the local record
  is newer; the local record's content is kept but its `dirty` flag is dropped. This
  matches the brief and its test, but means a newer unsynced local edit whose work id also
  appears in the server response would not be re-pushed.
