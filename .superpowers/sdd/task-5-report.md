# Task 5 Report: 主壳搜索入口

## Status: DONE_WITH_CONCERNS

## What I implemented

Wired the game tab into the main shell's title-bar search entry.

- `lib/shell/main_shell.dart`
  - Added `import '../modules/game/game_search.dart';`
  - Widened the search-button condition from `_currentIndex <= 2` to `_currentIndex <= 3`.
  - Extended the route builder so index 3 pushes `const GameSearchPage()` (index 0/1/2 unchanged: anime/comic/novel).
- `test/shell/main_shell_test.dart`
  - Added `import 'package:acgnhub/modules/game/game_search.dart';`
  - Added widget test `game tab exposes the search entry`: select the 游戏 sidebar item, assert exactly one title-bar `IconButton` with `Icons.search_rounded`, tap it, assert `GameSearchPage` is shown.

## TDD evidence

### RED
With only the test added (shell unchanged), `flutter test test/shell/main_shell_test.dart`:

```
00:01 +1 -1: game tab exposes the search entry [E]
Expected: exactly one matching candidate
  Actual: _WidgetPredicateWidgetFinder:<Found 0 widgets with widget matching predicate: []>
  ... test/shell/main_shell_test.dart:77:5
```

(The search button predicate found 0 widgets for index 3 — expected, since the condition was still `<= 2`.)

### GREEN
After the shell change, same command:

```
00:00 +1: game tab exposes the search entry
00:01 +2: All tests passed!
```

### Full regression + analyze

```
flutter test      -> 00:15 +339 ~1: All tests passed!   (1 pre-existing skip)
flutter analyze   -> No issues found! (ran in 2.5s)
```

## Files changed

```
lib/shell/main_shell.dart        (+7 -2)
test/shell/main_shell_test.dart  (+24)
```

Commit: `0d90efe feat(shell): open game search from the title bar` (branch `dev`, exactly the two files staged).

## Deviation from the brief (concern)

The brief's Step 1 test used `await tester.pump();` after tapping the search button and expected PASS. That literal code **fails** here:

```
Expected: exactly one matching candidate
  Actual: _TypeWidgetFinder:<Found 0 widgets with type "GameSearchPage": []>
```

Root cause: the title bar is wrapped in `window_manager`'s `DragToMoveArea`, whose internal `GestureDetector` declares `onDoubleTap`. Flutter's `DoubleTapGestureRecognizer` delays a single tap by `kDoubleTapTimeout` (300 ms) to disambiguate from a double tap, so `onPressed` has not fired by the time a bare `pump()` builds its frame.

Evidence (debug instrumentation): the widget only appears after ≥300 ms of pumped time, and `find.byType(GameSearchPage, skipOffstage: false)` is still 0 at t=200 ms. `tester.pumpAndSettle()` also passes.

Fix applied — smallest change that keeps the brief's shape and is deterministic:

```dart
await tester.tap(searchButton);
await tester.pump(const Duration(milliseconds: 400));
await tester.pump();
expect(find.byType(GameSearchPage), findsOneWidget);
```

No production behavior changed for this; it is a test-timing correction only. Flagging because it diverges from the brief's exact text.

## Self-review

- Completeness: condition widened to `<= 3`; `GameSearchPage` branch added; import added; shell test added. Yes.
- Discipline: only `lib/shell/main_shell.dart` and `test/shell/main_shell_test.dart` committed; no comments added; no new dependencies.
- Testing: RED confirmed before the source change, GREEN after; full suite 339 pass / 1 pre-existing skip; `analyze` clean.
- Note: pre-existing unstaged changes under `.superpowers/sdd/` (progress/briefs/reports) were left untouched and NOT committed.

## Concerns

1. The brief's literal `pump()` assertion cannot pass due to the `DragToMoveArea` double-tap timeout; test uses `pump(400ms) + pump()` instead. Documented above.
2. Manual verification (real Windows run, live sources, Hero, empty/error states) is explicitly reserved for the user per the brief and was not performed.
