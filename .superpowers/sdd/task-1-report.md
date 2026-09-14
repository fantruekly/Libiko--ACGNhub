# Task 1 Report: 轻小说模块模型 `models.dart`

## What I implemented

Created the pure-Dart data models for the new 轻小说 (light novel) module, exactly as specified in the brief:

- `lib/core/novel/models.dart`
  - `_stringList(dynamic)` helper (list → non-empty `List<String>`).
  - `Novel` — `id`, `title`, `author?`, `coverUrl?`, `tags`, `summary?`, `extra`; const ctor with defaults, `fromJson`, `toJson` (omits null/empty fields).
  - `NovelSection`, `NovelHome`, `NovelList`.
  - `enum NovelBrowseKind { ranking, bunko }` and `NovelBrowse(kind, key)`.
  - `NovelDetail`, `NovelChapter`.
- `test/core/novel/models_test.dart` — 3 tests from the brief.

No UI, no network, no new dependency. No `fontFamily` set (no `TextStyle`s at all). SDK constraint untouched.

## What I tested and results

- Focused test: `flutter test test/core/novel/models_test.dart` → 3 tests pass.
- Full suite: `flutter test` → `+173 ~1: All tests passed!` (173 passed, 1 pre-existing skip: `js_engine_smoke_test.dart` native library not loadable under `flutter test`).
- Analyzer: `flutter analyze lib test` → `No issues found!`.

## TDD Evidence

### RED

Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/models_test.dart
```

Output (excerpt):
```
test/core/novel/models_test.dart:4:8: Error: Error when reading 'lib/core/novel/models.dart': 系统找不到指定的路径。
import 'package:acgnhub/core/novel/models.dart';
       ^
test/core/novel/models_test.dart:8:19: Error: Method not found: 'Novel'.
test/core/novel/models_test.dart:38:27: Error: Undefined name 'NovelBrowseKind'.
00:00 +0 -1: Some tests failed.
```

Why expected: the implementation file did not exist yet, so the test target failed to compile — the test genuinely exercises the missing API.

### GREEN

Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/models_test.dart
```

Output:
```
00:00 +0: Novel round-trips through JSON
00:00 +1: Novel.fromJson tolerates missing optional fields
00:00 +2: NovelBrowse holds kind and key
00:00 +3: All tests passed!
```

## Files changed

- `lib/core/novel/models.dart` (new, 84 lines)
- `test/core/novel/models_test.dart` (new, 42 lines)

Commit: `3821f0b feat(novel): add novel models` (pushed to `origin/dev`).

## Self-review findings

- **Completeness:** all 8 interfaces from the brief are present with the exact signatures/ctors. Verified `flutter analyze` clean and full suite green.
- **Quality:** `toJson`/`fromJson` mirror the existing `lib/core/comic/models.dart` style (null/empty omission, `?.toString()` coercion).
- **YAGNI:** no extra fields, helpers, or serialization for the container classes (`NovelSection`/`NovelHome`/`NovelList`/`NovelDetail`/`NovelChapter`) beyond what the brief specifies.
- **Test hygiene:** 3 focused tests, one behavior each; the round-trip test goes through `json.encode`/`json.decode` so it verifies true JSON compatibility.
- No fixes required; nothing found to correct.

## Concerns

- `_stringList` (from the brief) only flattens a top-level `List` and drops empty strings; it does not recurse into nested lists/maps like the comic module's helper. This matches the brief verbatim and is sufficient for the planned linovelib source, but if a future source emits grouped/nested tags, this helper would silently drop them. Left as-is per the brief; worth noting for the source task.

## Verdict

DONE — TDD RED→GREEN followed, analyze clean, full suite green, committed and pushed.
