# Task 5 Report: 轻小说 providers

## What I implemented
Created `lib/modules/novel/novel_providers.dart` (verbatim per brief) exposing:
- `novelSourceManagerProvider` — `Provider<NovelSourceManager>` seeded with `[LinovelibSource()]`.
- `novelSourcesProvider` — `FutureProvider<List<NovelSource>>` reading the manager's sources.
- `flattenHome(NovelHome)` — merges all sections and dedupes by `Novel.id`, preserving first-seen order.
- `novelHomeProvider` — `FutureProvider.family<NovelHome, String>` keyed by `sourceId`; throws `StateError` for an unknown source.
- `novelBrowseProvider` — `FutureProvider.family<NovelList, (String, NovelBrowseKind, String, int)>` keyed by `(sourceId, kind, key, page)`; throws `StateError` for an unknown source.

Also created the test `test/modules/novel/novel_providers_test.dart` (verbatim per brief).

## What I tested and results
- Focused test `test/modules/novel/novel_providers_test.dart`: PASS (1 test).
- `flutter analyze lib test`: `No issues found!`
- Full `flutter test`: `All tests passed!` — 184 passed, 1 skipped (pre-existing `js_engine_smoke_test` skip, unrelated).

## TDD Evidence

### RED
Command: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_providers_test.dart`

Failing output (excerpt):
```
test/modules/novel/novel_providers_test.dart:3:8: Error: Error when reading 'lib/modules/novel/novel_providers.dart': 系统找不到指定的路径。
import 'package:acgnhub/modules/novel/novel_providers.dart';
       ^
test/modules/novel/novel_providers_test.dart:11:18: Error: Method not found: 'flattenHome'.
    final flat = flattenHome(home);
                 ^^^^^^^^^^^
00:00 +0 -1: loading ... [E]
Failed to load ...: Compilation failed ...
00:00 +0 -1: Some tests failed.
```
Why expected: the implementation file did not exist yet, so the test could not compile — exactly the brief's expected RED (`FAIL 文件不存在`).

### GREEN
Command: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_providers_test.dart`

Passing output (excerpt):
```
00:00 +0: loading D:/ACGNhub/test/modules/novel/novel_providers_test.dart
00:00 +0: flattenHome merges sections and dedupes by id
00:00 +1: All tests passed!
```
Full suite: `00:10 +184 ~1: All tests passed!`

## Files changed
- `lib/modules/novel/novel_providers.dart` (new)
- `test/modules/novel/novel_providers_test.dart` (new)

## Self-review findings
- Imports use relative paths matching `comic_providers.dart` conventions; only `flutter_riverpod` + core novel imports — no new dependencies added.
- `flattenHome` dedupes by `id` via a `Set` and preserves section/insertion order (verified `['1','2','3']`).
- Both family providers resolve the source through `NovelSourceManager.byId` and throw `StateError` on unknown ids, consistent with `comic_providers.dart`.
- `novelSourcesProvider` uses `ref.watch(novelSourceManagerProvider).sources` as specified; `NovelSourceManager.sources` returns an unmodifiable list.
- API surface matches exactly what Task 6 depends on.

## Concerns
None. The `novelHomeProvider`/`novelBrowseProvider` network paths are not unit-tested here (per brief, only `flattenHome` is); they will be exercised end-to-end by later tasks.
