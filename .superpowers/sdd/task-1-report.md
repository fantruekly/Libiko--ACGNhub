# Task 1 Report: Sync data models — `FollowRecord` + `WatchRecord` additions

## Status
DONE

## What I implemented
Implemented the task brief verbatim (sub-project B3, Task 1):

- `lib/core/models/follow_record.dart` (new): `FollowRecord` with `work`, `updatedAt`,
  `deleted`, `dirty`, a `const` constructor, `fromJson`, `toJson`, and `copyWith`
  (`updatedAt`/`deleted`/`dirty`).
- `lib/core/models/watch_record.dart` (modified): added `updatedAt`, `deleted`, `dirty` fields;
  dropped `const` from the constructor so `updatedAt` can default to `watchedAt`; added
  `copyWith`; extended `fromJson`/`toJson` for the new fields. `fromJson` leaves `updatedAt`
  null when absent so the constructor default (`= watchedAt`) applies.
- `test/core/models/follow_record_test.dart` (new): the two brief tests, verbatim.
- `test/core/models/watch_record_test.dart` (modified): appended the
  `carries updatedAt/deleted/dirty with defaults` test, reusing the existing `work` constant.

No comments beyond the brief's code. 2-space indentation. `Work` untouched.

## What I tested and the results
- Focused: `flutter test test/core/models/` → **PASS (7 tests)**.
- Analyzer: `flutter analyze lib test` → **No issues found! (ran in 2.6s)**.
- Full suite: `flutter test` → **PASS (92 tests)**, including the pre-existing
  `watch_record_test.dart` round-trip and `watch_history_test.dart`.

## TDD evidence

### RED
Command (workdir `D:\ACGNhub`):
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/models/follow_record_test.dart test/core/models/watch_record_test.dart
```
Output (excerpt):
```
test/core/models/follow_record_test.dart:2:8: Error: Error when reading 'lib/core/models/follow_record.dart': 系统找不到指定的文件。
test/core/models/follow_record_test.dart:16:20: Error: Method not found: 'FollowRecord'.
test/core/models/watch_record_test.dart:45:19: Error: The getter 'updatedAt' isn't defined for the type 'WatchRecord'.
test/core/models/watch_record_test.dart:49:50: Error: The method 'copyWith' isn't defined for the type 'WatchRecord'.
00:00 +0 -2: Some tests failed.
```
Why expected: the tests were written before the implementation. `follow_record.dart` did not
exist, and `WatchRecord` had none of the new getters or `copyWith` — the intended RED state.

### GREEN
Command (workdir `D:\ACGNhub`):
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/models/
```
Output:
```
00:00 +0: follow_record_test.dart: round-trips through JSON including dirty/deleted
00:00 +1: follow_record_test.dart: copyWith changes only the named flags
00:00 +2: watch_record_test.dart: toJson/fromJson round-trips the record and its Work
00:00 +3: watch_record_test.dart: carries updatedAt/deleted/dirty with defaults
00:00 +7: All tests passed!
```

## Files changed
- `lib/core/models/follow_record.dart` (new)
- `lib/core/models/watch_record.dart` (modified)
- `test/core/models/follow_record_test.dart` (new)
- `test/core/models/watch_record_test.dart` (modified)

Commit: `39861b0 feat(sync): add FollowRecord and sync fields on WatchRecord`

## Self-review findings
- Completeness: both interfaces match the contract — `FollowRecord{work, updatedAt, deleted,
  dirty}` and `WatchRecord{work, episodeTitle, episodeIndex, watchedAt, updatedAt, deleted,
  dirty}`, each with `fromJson`/`toJson`/`copyWith`.
- Quality: analyzer clean; implementation is the brief's code verbatim; no drift in indentation
  or comments.
- YAGNI: no equality, helpers, or extra fields beyond the brief.
- Tests verify real behavior: actual JSON round-trips assert `work.id`/`bangumiId`,
  `updatedAt` epoch millis, `deleted`/`dirty`; the default test proves `updatedAt == watchedAt`
  when unset, that `deleted`/`dirty` default false, and that `copyWith(dirty: true)` survives
  serialization while retaining `updatedAt`.
- Backward compatibility: the existing round-trip test and history tests still compile/pass
  because the new fields are optional/defaulted.

## Concerns
None. The brief's code compiled and passed as written, with no deviation required.
