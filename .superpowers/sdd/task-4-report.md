# Task 4 Report: MetadataService (fallback + cache)

## What I implemented
Created `MetadataService` in `lib/core/metadata/metadata_service.dart` with:
- Constructor `MetadataService({MetadataProvider? anilist, MetadataProvider? jikan, DateTime Function()? now})`, defaulting to `AniListProvider()`, `JikanProvider()`, and `DateTime.now`.
- `feed(AnimeFeed, {int page})`, `search(String, {int page})`, `detail(Work)` — all routed through a generic `_run<T>`.
- Provider fallback: tries AniList first, falls back to Jikan on error. On AniList failure, disables AniList for 10 minutes (`_disableDuration`); on AniList success, clears the disable. While disabled, Jikan is tried first.
- In-memory cache keyed per call, TTL 5 minutes (`_cacheTtl`).

Applied the brief's corrected import path: `import '../models/work.dart';` (brief had the wrong `../../models/work.dart`).

Created test `test/core/metadata/metadata_service_test.dart` verbatim from the brief.

## TDD evidence

### RED
Command: `flutter test test/core/metadata/metadata_service_test.dart`
Output (key lines):
```
Failed to load ".../metadata_service_test.dart":
Compilation failed ... Error when reading 'lib/core/metadata/metadata_service.dart': 系统找不到指定的文件。
Error: Method not found: 'MetadataService'.
00:00 +0 -1: Some tests failed.
```

### GREEN
Command: `flutter test test/core/metadata/metadata_service_test.dart`
Output:
```
00:00 +0: falls back to Jikan when AniList fails, then skips AniList for 10 min
00:00 +1: caches identical calls for 5 minutes
00:00 +2: All tests passed!
```

### Regression check
Command: `flutter test test/core/metadata/`
Output: `00:00 +5: All tests passed!`

### Static analysis
Command: `flutter analyze lib/core/metadata/metadata_service.dart test/core/metadata/metadata_service_test.dart`
Output: `No issues found!`

## Files changed
- Added: `lib/core/metadata/metadata_service.dart`
- Added: `test/core/metadata/metadata_service_test.dart`

## Commit
`4f634d8 feat(metadata): add MetadataService with fallback and cache`

## Self-review findings
- Fallback/cache logic matches the two brief tests exactly; verified by passing suite.
- `_run<T>` caches `Object?` and casts back to `T`; safe for the `List<Work>`/`Work` return types in use.
- Cache key for `detail` uses `anilistId ?? malId ?? work.id`, matching the brief.
- Analyzer clean on both new files.
- No unrelated files staged; commit contains only the two task files.

## Concerns
- None blocking. Note: the `now` injection is only used for cache/disable timing; cache TTL relies on a monotonic-ish wall clock, so system clock changes could affect cache behaviour (acceptable per brief).

## Fix: transient-only AniList disable

### Changes
- `lib/core/metadata/metadata_service.dart`: added `import 'package:dio/dio.dart';`. In `_run<T>`, the catch block now disables AniList only when `e is DioException`, so non-transient/programming errors no longer trip the 10-minute circuit breaker.
- `test/core/metadata/metadata_service_test.dart`: added `import 'package:dio/dio.dart';`; `_FakeProvider` now throws `DioException(requestOptions: RequestOptions(path: '/$id'))` instead of a generic `Exception` in `feed`, `search`, and `detail`, exercising the transient-error path.

### Test
Command: `flutter test test/core/metadata/metadata_service_test.dart`
Output:
```
00:00 +0: loading D:/ACGNhub/test/core/metadata/metadata_service_test.dart
00:00 +0: falls back to Jikan when AniList fails, then skips AniList for 10 min
00:00 +1: caches identical calls for 5 minutes
00:00 +2: All tests passed!
```

Analyze: `flutter analyze lib/core/metadata/metadata_service.dart test/core/metadata/metadata_service_test.dart` → `No issues found! (ran in 0.8s)`
