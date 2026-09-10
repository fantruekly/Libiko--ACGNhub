# Task 2 Report: MetadataProvider interface + JikanProvider

## Status: DONE_WITH_CONCERNS

## What I implemented
- `lib/core/metadata/metadata_provider.dart` — `enum AnimeFeed { trending, season, today }` and abstract `MetadataProvider` (`id`, `feed`, `search`, `detail`).
- `lib/core/metadata/jikan_provider.dart` — `JikanProvider` implementing `MetadataProvider` against the Jikan v4 API (`https://api.jikan.moe/v4`), with `feed`, `search`, `detail`, plus `@visibleForTesting` static `parseList` / `parseItem` and helpers `_title`, `_clean`.
- `test/core/metadata/jikan_provider_test.dart` — `parseList` mapping test from the brief.

## TDD evidence

### RED
Command: `flutter test test/core/metadata/jikan_provider_test.dart`

```
00:00 +0: loading D:/ACGNhub/test/core/metadata/jikan_provider_test.dart
flutter : test/core/metadata/jikan_provider_test.dart:2:8: Error: Error when reading 'lib/core/metadata/jikan_provider.dart': 系统找不到指定的文件
...
  Failed to load "D:/ACGNhub/test/core/metadata/jikan_provider_test.dart":
  Compilation failed for testPath=D:/ACGNhub/test/core/metadata/jikan_provider_test.dart: ... Error: Undefined name 'JikanProvider'.
00:00 +0 -1: Some tests failed.
```

(Note: after adding the implementation, a second compile error surfaced from the brief's import path — see Concerns. After correcting the import to `../models/work.dart`, the test compiled and ran.)

### GREEN
Command: `flutter test test/core/metadata/jikan_provider_test.dart`

```
00:00 +0: loading D:/ACGNhub/test/core/metadata/jikan_provider_test.dart
00:00 +0: parseList maps a Jikan response to Work items
00:00 +1: All tests passed!
```

Analyzer: `flutter analyze lib/core/metadata test/core/metadata` → `No issues found!`

## Files changed
- Added `lib/core/metadata/metadata_provider.dart`
- Added `lib/core/metadata/jikan_provider.dart`
- Added `test/core/metadata/jikan_provider_test.dart`

Commit: `dbf3fda feat(metadata): add MetadataProvider interface and JikanProvider`

## Self-review
- Completeness: interface, provider, and test all match the brief's interface contract. `Work` constructor usage (`id`, `sourceId`, `sourceName`, `type`, `title`, `coverUrl`, `summary`, `tags`, `extra`) verified against `lib/core/models/work.dart:15`.
- Quality: analyzer clean; test green; code matches brief verbatim apart from the import fix.
- YAGNI: no extra methods/abstractions beyond the brief.
- Test hygiene: single focused unit test on pure parsing (no network), matching brief scope.

## Concerns
1. **Brief bug — import path (fixed).** The brief specified `import '../../models/work.dart';` in both new files. From `lib/core/metadata/`, that resolves to `lib/models/work.dart` (does not exist). The correct path is `../models/work.dart` (Work lives at `lib/core/models/work.dart`). I corrected both files to make the code compile; this is the only deviation from verbatim.
2. **Test coverage limited to `parseList`.** `feed`/`search`/`detail`, the `_title` fallback chain, and `_clean` HTML-entity handling are untested. This matches the brief's single-test scope, but network paths are unverified.
3. **`parseItem` assumes `mal_id` is present/non-null** (`item['mal_id'] as int`); a malformed response would throw rather than skip. Per brief.
4. **`_clean` only unescapes `&amp;`** and strips tags — other HTML entities (`&quot;`, `&#39;`, `&lt;`, etc.) pass through. Per brief.
5. **`bannerUrl` is always set to `null`** in `extra`; the `Work.bannerUrl` getter therefore returns null for Jikan works. Per brief.

## Fix: perPage 25

Change: `lib/core/metadata/jikan_provider.dart:7` — `static const perPage = 30;` → `static const perPage = 25;` (Jikan v4 caps `limit` at 25; 30 causes a 504). No other changes.

Test command: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/metadata/jikan_provider_test.dart`

Output:
```
00:00 +0: loading D:/ACGNhub/test/core/metadata/jikan_provider_test.dart
00:00 +0: parseList maps a Jikan response to Work items
00:00 +1: All tests passed!
```

Analyzer: `flutter analyze lib/core/metadata/jikan_provider.dart` → `No issues found! (ran in 0.3s)`
