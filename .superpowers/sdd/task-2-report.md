# Task 2 Report: GameSource 抽象与管理器

## What I implemented
- `lib/core/game/game_source.dart` — `abstract class GameSource` (id/name/baseUrl/browseOptions/browse/detail) and `GameSourceManager` (sources getter returning unmodifiable list, `register` with duplicate-id `ArgumentError` guard, `byId` lookup). Mirrors `lib/core/novel/novel_source.dart`.
- `test/core/game/game_source_test.dart` — fake source + 2 tests (registered sources exposed, duplicate ids rejected).

Both files written verbatim from the brief's provided code.

## What I tested and test results
Command: `C:\flutter\bin\flutter.bat test test/core/game/game_source_test.dart`
Result: `00:00 +2: All tests passed!` (2 tests).

## TDD Evidence
### RED
Command: `C:\flutter\bin\flutter.bat test test/core/game/game_source_test.dart`
Output (excerpt):
```
test/core/game/game_source_test.dart:2:8: Error: Error when reading 'lib/core/game/game_source.dart': 系统找不到指定的文件。
test/core/game/game_source_test.dart:5:30: Error: Type 'GameSource' not found.
test/core/game/game_source_test.dart:25:15: Error: Method not found: 'GameSourceManager'.
00:00 +0 -1: Some tests failed.
```
Why expected: implementation file did not yet exist, so `GameSource`/`GameSourceManager` could not resolve — the brief's Step 2 anticipated exactly this failure.

### GREEN
Command: `C:\flutter\bin\flutter.bat test test/core/game/game_source_test.dart`
Output:
```
00:00 +0: manager exposes registered sources
00:00 +1: manager rejects duplicate ids
00:00 +2: All tests passed!
```

## Files changed
- `lib/core/game/game_source.dart` (new)
- `test/core/game/game_source_test.dart` (new)

Commit: `29c1b2c feat(game): add GameSource abstraction and manager` (branch `dev`).

## Self-review findings
- Completeness: exactly the brief's two files and API surface.
- Quality: matches `novel_source.dart` naming/structure and duplicate-id guard.
- Discipline: no extra files, no dependencies added, no comments beyond those in the brief's provided code (three doc comments on the abstract class members).
- Testing: tests exercise real manager behavior (listing, lookup, duplicate rejection) and output is pristine.

## Issues or concerns
None.
