# Task 4 Report: `AccountApi` sync/follow/history endpoints

## Status: DONE_WITH_CONCERNS

## What I implemented
- Added `FollowItem`, `HistoryItem`, and `SyncPage` models with `fromJson`
  factories to `lib/core/account/account_models.dart`, verbatim from the brief.
- Added `AccountApi.sync`, `putFollow`, `deleteFollow`, `putHistory`, and
  `clearHistory` to `lib/core/account/account_api.dart`, all routed through the
  existing private `_request` helper (so non-2xx → `AccountException`, network
  errors → `AccountException(code: 'network')`).
- Appended the five brief-specified tests to
  `test/core/account/account_api_test.dart`.

## What I tested and results
- Focused: `flutter test test/core/account/account_api_test.dart` → 10 tests passed.
- Full suite: `flutter test` → 103 tests passed.
- Analyzer: `flutter analyze lib test` → `No issues found!`

## TDD evidence
RED — `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/account/account_api_test.dart`
```
test/core/account/account_api_test.dart:120:38: Error: The method 'sync' isn't defined for the type 'AccountApi'.
    final page = await _api(adapter).sync('tok', 3);
...
00:00 +0 -1: Some tests failed.
```
Expected because the new endpoints/models did not exist yet; compilation of the
new tests failed for exactly the five undefined methods.

GREEN — same command after implementing models + endpoints:
```
00:00 +5: sync parses the page and sends sinceSeq
00:00 +6: putFollow posts the work and updatedAt
00:00 +7: deleteFollow sends workId and updatedAt as a query parameter
00:00 +8: putHistory posts the episode fields
00:00 +9: clearHistory deletes with updatedAt
00:00 +10: All tests passed!
```

## Files changed
- `lib/core/account/account_models.dart` — added `FollowItem`, `HistoryItem`, `SyncPage`.
- `lib/core/account/account_api.dart` — added the five endpoints.
- `test/core/account/account_api_test.dart` — added five endpoint tests.
- `test/core/account/account_service_test.dart` — **not in the brief**: added
  stubs for the five new methods to the existing `_FakeApi` (and thus its
  subclasses) so the suite compiles.

## Self-review findings
- The brief's expected Dio request shapes matched reality; no assertion
  adjustments were needed. `RequestOptions.data` retains the passed `Map` and
  `uri.queryParameters` exposes `sinceSeq`/`updatedAt` as strings, as asserted.
- Completeness: all five endpoints and all three models produced exactly as
  specified. No extra behavior added (YAGNI respected).
- Tests exercise real behavior: method, path, query params, auth header, request
  body, and response parsing (including the Chinese `episodeTitle`).

## Concerns
- **Deviation from brief's file list:** adding methods to the `AccountApi`
  interface forced `_FakeApi` in `test/core/account/account_service_test.dart`
  (which `implements AccountApi`) to provide the new members, otherwise the
  full suite failed to compile (`Missing concrete implementations ...`). I added
  minimal stubs (`sync` returns an empty `SyncPage`; writers are no-ops). This
  is a mechanical interface-conformance change, not new test behavior. The
  commit therefore contains 4 files instead of the 3 listed in the brief.
- The stubs in `_FakeApi` will likely be superseded/replaced when Task 5's
  `SyncService` tests need real sync behavior.
- `.superpowers/sdd/*.md` files show as modified in `git status` from before
  this task (progress/reports); I did not stage or alter them.
