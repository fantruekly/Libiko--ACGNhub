# Task 2 Report: Make Bangumi primary + generalize the breaker

**Status:** DONE_WITH_CONCERNS

## What was implemented
Made `BangumiProvider` the first metadata provider and replaced the single
AniList-only circuit breaker with a per-provider transient-disable map.

- `lib/core/metadata/metadata_service.dart`
  - Added `import 'bangumi_provider.dart';`.
  - Added `final MetadataProvider bangumi;` field.
  - Constructor now accepts `MetadataProvider? bangumi` (defaults to
    `BangumiProvider()`) and defines `_intervals` with a `'bangumi': 300ms`
    entry.
  - Replaced `DateTime? _anilistDisabledUntil` with
    `final Map<String, DateTime> _disabledUntil = {}` plus
    `List<MetadataProvider> get _providers => [bangumi, anilist, jikan];`.
  - Rewrote `_run<T>` to filter out providers whose disable window has not
    elapsed, fall back to the full list if all are disabled, and record/clear
    the breaker per provider id (`_disabledUntil[provider.id]`).
- `test/core/metadata/metadata_service_test.dart`
  - Added the `bangumi_provider.dart` import.
  - `_service` helper now takes a `bangumi` parameter and defaults it to a
    failing `_FakeProvider('bangumi', fail: true)`.
  - Added test `tries Bangumi first, then falls back`.

## TDD evidence

### RED
Command: `flutter test test/core/metadata/metadata_service_test.dart`
Output (failing, compile error):
```
test/core/metadata/metadata_service_test.dart:108:5: Error: No named parameter with the name 'bangumi'.
    bangumi: bangumi ?? _FakeProvider('bangumi', fail: true),
    ^^^^^^^
lib/core/metadata/metadata_service.dart:34:3: Context: Found this candidate, but the arguments don't match.
  MetadataService({
  ^^^^^^^^^^^^^^^
00:00 +0 -1: Some tests failed.
```

### GREEN
Command: `flutter test test/core/metadata/metadata_service_test.dart`
Output (passing):
```
00:00 +0: tries Bangumi first, then falls back
00:00 +1: falls back to Jikan when AniList fails, then skips AniList for 10 min
00:00 +2: caches identical calls for 5 minutes
00:00 +3: invalidate forces a refetch
00:00 +4: serializes Jikan calls (no overlap)
00:00 +5: retries transient provider failures
00:01 +6: returns disk-cached feed when all providers fail
00:01 +7: returns seed when all providers fail and no cache
00:01 +8: All tests passed!
```

Full suite: `flutter test` → `00:04 +37: All tests passed!`

## Files changed
- `lib/core/metadata/metadata_service.dart` (+? / -?): see diff — new
  `bangumi` field/param, per-provider `_disabledUntil` map, rewritten `_run`.
- `test/core/metadata/metadata_service_test.dart` (+14 / -0): import, `_service`
  helper update, new ordering test.

## Self-review findings
- Implementation matches the brief's Step 3 code verbatim.
- `_run` behavior verified against every existing test: default failing Bangumi
  is transparently skipped so `anilist`/`jikan` call-count assertions hold; the
  per-provider breaker disables AniList for 1 minute (re-enabled after the
  11-minute jump) exactly as before.
- `anime_detail_page_test.dart` still constructs `MetadataService` with only
  `anilist`/`jikan`; the now-default real `BangumiProvider` fails fast (the test
  work has no `bangumiId`, so `detail` throws `StateError`, not a retried
  `DioException`). Full suite passes, no timeout.
- `flutter analyze` on the two files reports 1 warning: the
  `bangumi_provider.dart` import added to the test file is unused (the test uses
  `_FakeProvider('bangumi')`, not `BangumiProvider`). This import was specified
  verbatim in the brief, so it was kept as instructed rather than removed.

## Concerns
- The test file's `import 'package:acgnhub/core/metadata/bangumi_provider.dart';`
  is unused and produces an analyzer warning. Recommend removing it in a
  follow-up unless a later task adds a direct `BangumiProvider` reference to the
  test.

## Fix: unused import

Removed the unused `import 'package:acgnhub/core/metadata/bangumi_provider.dart';`
line from `test/core/metadata/metadata_service_test.dart`. The test uses
`_FakeProvider('bangumi')`, not `BangumiProvider`, so the import made
`flutter analyze` fail. No other changes were made.

### Commands and output

`flutter analyze test/core/metadata/metadata_service_test.dart`
```
Analyzing metadata_service_test.dart...
No issues found! (ran in 0.9s)
```

`flutter test test/core/metadata/metadata_service_test.dart`
```
00:00 +0: tries Bangumi first, then falls back
00:00 +1: falls back to Jikan when AniList fails, then skips AniList for 10 min
00:00 +2: caches identical calls for 5 minutes
00:00 +3: invalidate forces a refetch
00:00 +4: serializes Jikan calls (no overlap)
00:00 +5: retries transient provider failures
00:01 +6: returns disk-cached feed when all providers fail
00:01 +7: returns seed when all providers fail and no cache
00:01 +8: All tests passed!
```

Commit: `fix(test): drop unused import in metadata service test`
