# Task 2 Report: `FollowManager` + `FollowNotifier`

## What I implemented

Created `lib/core/services/follow_manager.dart`, an `AppDatabase`-backed follow store following the `WatchHistoryManager` pattern (JSON list under one `SharedPreferences` key `follows`):

- `FollowManager`
  - `all()` — live (non-deleted) records, newest `updatedAt` first.
  - `isFollowing(String workId)`.
  - `follow(Work)` — writes a new `dirty: true` record at `DateTime.now()`.
  - `unfollow(String)` — converts the existing record into a `dirty: true` tombstone (no-op if absent).
  - `dirty()` — all records flagged for sync (including tombstones).
  - `markSynced(Set<String>)` — clears `dirty` for the given ids.
  - `mergeFromServer(List<FollowRecord>)` — LWW merge persisted to storage.
  - `@visibleForTesting static upsert`, `sortDescending`, `merge`.
- `FollowNotifier extends Notifier<List<FollowRecord>>` with `isFollowing(String)` / `toggle(Work)`, plus `followProvider`.

LWW semantics: a local record strictly newer than the server's is kept (dirty cleared); otherwise the server record wins with `dirty = false`. Server tombstones propagate. Malformed stored entries are skipped.

## What I tested and results

`test/core/services/follow_manager_test.dart` (verbatim from the brief), 4 tests:

1. `merge keeps a newer local record and takes a newer server record`
2. `merge applies a server tombstone`
3. `follow/unfollow/dirty/markSynced round-trip through storage`
4. `all() orders by updatedAt descending`

Results:
- Focused test: `+4: All tests passed!`
- `flutter analyze lib test`: `No issues found!`
- Full suite: `+96: All tests passed!`

## TDD evidence

### RED
Command: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/services/follow_manager_test.dart`

Output (excerpt):
```
Error when reading 'lib/core/services/follow_manager.dart': 系统找不到指定的文件。
import 'package:acgnhub/core/services/follow_manager.dart';
test/core/services/follow_manager_test.dart:26:20: Error: Undefined name 'FollowManager'.
...
00:00 +0 -1: Some tests failed.
```
Expected: the test file references `FollowManager`, which did not exist yet, so compilation fails. This is the correct RED — failure is due to the missing production feature, not a typo in the test.

### GREEN
After creating `follow_manager.dart`:
Command: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/services/follow_manager_test.dart`

Output:
```
00:00 +0: merge keeps a newer local record and takes a newer server record
00:00 +1: merge applies a server tombstone
00:00 +2: follow/unfollow/dirty/markSynced round-trip through storage
00:00 +3: all() orders by updatedAt descending
00:00 +4: All tests passed!
```

## Files changed

- `lib/core/services/follow_manager.dart` (new)
- `test/core/services/follow_manager_test.dart` (new)

Commit: `b0ddce8 feat(sync): add FollowManager and followProvider`

## Self-review findings

- **Completeness:** Every interface from the brief is present and matches signatures (`all`, `isFollowing`, `follow`, `unfollow`, `dirty`, `markSynced`, `mergeFromServer`, static `upsert`/`sortDescending`/`merge`, `FollowNotifier.isFollowing`/`toggle`, `followProvider`). Consumes `FollowRecord`/`Work`/`AppDatabase`; no other task's code was touched.
- **Quality:** Mirrors `watch_history.dart` (read/save helpers, `@visibleForTesting` statics). `unfollow` correctly removes any duplicate id before inserting the tombstone via `upsert`. `all()` filters tombstones while `dirty()` includes them so they sync.
- **YAGNI:** Implemented exactly the brief's code; no extra APIs, config, or abstractions.
- **Tests verify real behavior:** Storage round-trip test exercises the actual `SharedPreferences`-backed `AppDatabase` (mock values, real serialization), not a mock. `merge` tests cover the LWW branches and tombstone. Ordering test uses real timestamps.

## Concerns

- None blocking. `FollowNotifier.toggle` reads storage synchronously after the async write and reassigns `state`; consistent with `WatchHistoryNotifier`. `mergeFromServer` only persists — refreshing notifier state is deferred to Task 5's sync service, as intended.
