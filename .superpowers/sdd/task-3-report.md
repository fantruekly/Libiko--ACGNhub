# Task 3 Report: AniListProvider

## Summary

Implemented `AniListProvider` for the AniList GraphQL API, following TDD (RED → GREEN).

- Created `lib/core/metadata/anilist_provider.dart` implementing the `MetadataProvider`
  interface (`id`, `feed`, `search`, `detail`) plus static parsers
  `parsePage`, `parseAiring`, `parseMedia`.
- Created `test/core/metadata/anilist_provider_test.dart` with the brief's two tests.

### Deviation from brief (approved by coordinator)
- Brief's implementation wrote `import '../../models/work.dart';`, which is wrong from
  `lib/core/metadata/`. Used the correct `import '../models/work.dart';`. Everything else
  is verbatim from the brief.

## TDD Evidence

### RED — before implementation
Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/metadata/anilist_provider_test.dart
```
Output (excerpt):
```
Error: Error when reading 'lib/core/metadata/anilist_provider.dart': 系统找不到指定的文件。
Error: Undefined name 'AniListProvider'.
00:00 +0 -1: Some tests failed.
```

### GREEN — after implementation
Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/metadata/anilist_provider_test.dart
```
Output:
```
00:00 +0: parsePage maps AniList media to Work items
00:00 +1: parseAiring reads nested media
00:00 +2: All tests passed!
```

### Full suite (regression check)
```
00:02 +17: All tests passed!
```

### Analyzer
```
flutter analyze lib/core/metadata/anilist_provider.dart test/core/metadata/anilist_provider_test.dart
No issues found!
```

## Files Changed

- `lib/core/metadata/anilist_provider.dart` (new)
- `test/core/metadata/anilist_provider_test.dart` (new)

Commit: `2ffd7a2 feat(metadata): add AniListProvider`

## Self-Review

- **Completeness:** All interface members implemented; all three static parsers present and
  match the interface/`Work` model. Tests cover `parsePage` and `parseAiring`.
- **Quality:** Verbatim from brief except the corrected relative import. Analyzer clean, no
  unused imports.
- **YAGNI:** No extra abstraction added. GraphQL fields `season`, `popularity`, and `color`
  are requested but unused downstream (carried over from brief; left as-is).
- **Test hygiene:** Tests assert on public parser output only; no network calls; deterministic.

## Concerns

1. `detail()` requests `meanScore` and `characters(...)` in the GraphQL query, but
   `parseMedia` never maps them into `Work.extra`, so that detail-only data is discarded.
   If a later task (detail page) expects score/characters, this needs a follow-up.
2. `_strip` only decodes `&quot;` and `&amp;`; other HTML entities (e.g. `&#039;`, `&mdash;`)
   pass through. Minor cosmetic risk.
3. `season` is fetched in `_media` but not stored in `extra`; test does not require it.

## Fix: drop unused detail fields

Removed the unused `meanScore` and `characters(sort:ROLE,perPage:12){...}` fragments from
both branches of `detail()` in `lib/core/metadata/anilist_provider.dart`, so each query is
now just `{_media}` (addressing Concern 1). No other changes.

### Test command and output
Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/metadata/anilist_provider_test.dart
```
Output:
```
00:00 +0: loading D:/ACGNhub/test/core/metadata/anilist_provider_test.dart
00:00 +0: parsePage maps AniList media to Work items
00:00 +1: parseAiring reads nested media
00:00 +2: All tests passed!
```

### Analyzer
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib/core/metadata/anilist_provider.dart
No issues found! (ran in 0.3s)
```
