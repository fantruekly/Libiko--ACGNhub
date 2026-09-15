# Task 1 Report: 游戏数据模型

## What I implemented

Created the game data models in `lib/core/game/models.dart`, mirroring the existing
`lib/core/novel/models.dart` conventions:

- `_stringList(dynamic)` helper — coerces a raw list into a de-duplicated-free `List<String>`,
  dropping empty entries; returns `const []` for non-lists.
- `Game` — fields `id/title/coverUrl/summary/category/tags/publishedAt/views/extra`, with
  `const` constructor, `Game.fromJson`, and `toJson` (omits null/empty optional fields).
- `GameBrowseOption(key,label)`.
- `GameList(items,page,hasMore)`.
- `GameDetail(game,size,platform,updatedAt,paragraphs,screenshots,sourceUrl)`.

No comments added. No new dependencies. No other files touched.

## What I tested and test results

`test/core/game/models_test.dart` (verbatim from the brief) contains two tests:

1. `Game fromJson/toJson round-trips` — constructs a fully-populated `Game`, serializes and
   deserializes it, and asserts every field including tags and `extra`.
2. `Game.fromJson tolerates missing optional fields` — parses only `id`/`title` and asserts all
   optional fields are null/empty.

Result: **2 tests passed**, `All tests passed!`
Analyzer: `flutter analyze lib/core/game/models.dart test/core/game/models_test.dart` →
`No issues found!`

Note: `flutter` is not on PATH in this shell; used the full path
`C:\flutter\bin\flutter.bat`.

## TDD Evidence

### RED

Command:
```
& "C:\flutter\bin\flutter.bat" test test/core/game/models_test.dart
```

Output (key excerpt):
```
Failed to load "D:/ACGNhub/test/core/game/models_test.dart":
Compilation failed for testPath=D:/ACGNhub/test/core/game/models_test.dart: test/core/game/models_test.dart:2:8: Error: Error when reading 'lib/core/game/models.dart': 系统找不到指定的路径。
test/core/game/models_test.dart:6:15: Error: Method not found: 'Game'.
test/core/game/models_test.dart:17:18: Error: Undefined name 'Game'.
test/core/game/models_test.dart:30:15: Error: Undefined name 'Game'.
00:00 +0 -1: Some tests failed.
```

Why expected: the implementation file `lib/core/game/models.dart` did not exist yet, so the
`package:acgnhub/core/game/models.dart` import could not be resolved and `Game` was undefined.
This is the correct RED for Step 1/2.

### GREEN

Command:
```
& "C:\flutter\bin\flutter.bat" test test/core/game/models_test.dart
```

Output:
```
00:00 +0: loading D:/ACGNhub/test/core/game/models_test.dart
00:00 +0: Game fromJson/toJson round-trips
00:00 +1: Game.fromJson tolerates missing optional fields
00:00 +2: All tests passed!
```

## Files changed

- `lib/core/game/models.dart` (new)
- `test/core/game/models_test.dart` (new)

## Self-review findings

- Completeness: implemented exactly the interfaces listed in the brief (`Game`, `GameBrowseOption`,
  `GameList`, `GameDetail`), no more, no less.
- Quality: matches `lib/core/novel/models.dart` patterns (`_stringList`, `fromJson`/`toJson`
  conditional emission, `const` constructors).
- Discipline: no overbuilding, no extra files committed, no comments added, no new dependencies.
- Testing: tests assert real round-trip and tolerant-parsing behavior; test output clean
  (only the pre-existing `pub outdated` dependency notice from `flutter test`).

## Issues or concerns

- None blocking. Minor environment note: Flutter SDK is at `C:\flutter` and not on PATH; future
  tasks must invoke `C:\flutter\bin\flutter.bat` explicitly.
