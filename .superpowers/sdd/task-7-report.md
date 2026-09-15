# Task 7 Report: 首页 UI（GameCard + GameHomePage）

## What I implemented
- `lib/modules/game/game_home.dart` — `GameCard` (cached cover with `gameImageHeaders`, deterministic placeholder, 2-line title) and `GameHomePage` (`ConsumerStatefulWidget`) with:
  - source ChipBar (`gameSourcesProvider`)
  - section ChipBar (`GameBrowseOption` labels)
  - 6-column `GridView` of `GameCard`
  - manual 上一页/下一页 pager driven by `GameList.hasMore`
  - loading `ShimmerLoader`, error `EmptyState` with 重试, empty `EmptyState`
  - card tap → `noTransitionRoute(GameDetailPage(...))`
- `lib/modules/game/game_detail_page.dart` — minimal placeholder (intentional; Task 8 replaces it).
- `test/modules/game/game_home_test.dart` — widget test with a fake `GameSource`.

## What I tested and results
- `C:\flutter\bin\flutter.bat test test/modules/game/game_home_test.dart` → `+1: All tests passed!`
- `C:\flutter\bin\flutter.bat analyze lib/modules/game/game_home.dart lib/modules/game/game_detail_page.dart test/modules/game/game_home_test.dart` → `No issues found!`

## TDD Evidence

### RED
Command: `C:\flutter\bin\flutter.bat test test/modules/game/game_home_test.dart`
Output (key lines):
```
test/modules/game/game_home_test.dart:6:8: Error: Error when reading 'lib/modules/game/game_home.dart': 系统找不到指定的文件。
import 'package:acgnhub/modules/game/game_home.dart';
test/modules/game/game_home_test.dart:42:53: Error: Method not found: 'GameHomePage'.
Some tests failed.
```
Why expected: `game_home.dart` did not exist yet, so the test could not compile/run — correct RED for a not-yet-written implementation.

### GREEN
Command: `C:\flutter\bin\flutter.bat test test/modules/game/game_home_test.dart`
Output:
```
00:00 +0: renders source/section chips, grid and pager
00:00 +1: All tests passed!
```

## Files changed
- `lib/modules/game/game_home.dart` (new)
- `lib/modules/game/game_detail_page.dart` (new, placeholder)
- `test/modules/game/game_home_test.dart` (new)
- Commit: `2044588 feat(game): add game home page with cards and paging`

## Self-review findings
- Completeness: exactly the three files named in the brief; implementation code is verbatim from the brief.
- Quality: mirrors `lib/modules/novel/novel_home.dart` structure and styling constants.
- Discipline: no extra files, no added comments (the one comment in the test was already in the brief), no new dependencies.
- Testing: single widget test covers chips, grid render, paging, and disabled state; analyzer clean.

## Deviation from brief (concern)
The brief's test, used verbatim, **cannot pass**:
```dart
final next = tester.widget<IconButton>(find.byTooltip('下一页'));
```
`find.byTooltip` matches the `Tooltip` widget (a descendant of `IconButton`), so casting it to `IconButton` throws:
```
type 'Tooltip' is not a subtype of type 'IconButton' in type cast
```
This is independent of the implementation — no valid `IconButton`-based pager can satisfy it. I made the minimal intent-preserving fix, changing only the disabled-state lookup while leaving the rest of the test verbatim:
```dart
final next = tester.widget<IconButton>(find.ancestor(
  of: find.byTooltip('下一页'),
  matching: find.byType(IconButton),
));
expect(next.onPressed, isNull);
```
All other test lines, including `tester.tap(find.byTooltip('下一页'))`, are unchanged.

## Issues or concerns
- The above test-finder fix is the only deviation. If the orchestrator requires the test file to match the brief byte-for-byte, revert that line and the test will fail at the cast. Otherwise, no other concerns.
