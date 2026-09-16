# Task 3 Report: 游戏搜索 Providers

## Status
DONE

## What I implemented
Added to `lib/modules/game/game_providers.dart`:
- `class GameSearchResult { Game game; String sourceKey; }` with const constructor.
- `const Duration gameSearchTimeout = Duration(seconds: 10)`.
- `gameSearchSourceProvider` — `FutureProvider.family<List<GameSearchResult>, (String, String)>`: trims keyword, returns `[]` on blank keyword or unknown source, delegates to `source.search(k)` with `.timeout(gameSearchTimeout)`, maps each game to a `GameSearchResult` tagged with the source id.
- `gameSearchProvider` — `FutureProvider.family<List<GameSearchResult>, String>`: trims keyword, returns `[]` on blank/empty source list, runs all sources concurrently via `Future.wait` with per-source try/catch (failure isolation), dedupes by `game.title.trim()`, throws `StateError` when every source failed.

Updated `test/modules/game/game_providers_test.dart`:
- `_FakeSource.search` now returns `[Game(id: 's-$keyword', title: '搜索结果$keyword')]`.
- Added `_TitleSource` and `_FailingSource` fakes.
- Added 5 tests: source delegation, blank-keyword empty, merge/dedupe by title, failing-source isolation, all-fail throws `StateError`.

## TDD Evidence

### RED (before implementation)
Command: `C:\flutter\bin\flutter.bat test test/modules/game/game_providers_test.dart`
Result: compilation failed —
```
Method not found: 'gameSearchSourceProvider'.
Method not found: 'gameSearchProvider'.
Some tests failed.
```

### GREEN (after implementation)
Command: `C:\flutter\bin\flutter.bat test test/modules/game/game_providers_test.dart`
Result:
```
+9: All tests passed!
```
All 9 tests pass (4 pre-existing + 5 new).

## Static analysis
Command: `C:\flutter\bin\flutter.bat analyze`
Result: `No issues found! (ran in 2.1s)`

## Files changed
- `lib/modules/game/game_providers.dart`
- `test/modules/game/game_providers_test.dart`

Commit: `2447927 feat(game): add game search providers` (2 files changed, 149 insertions(+), 1 deletion(-))

## Self-review
- Completeness: `GameSearchResult`, `gameSearchTimeout`, both providers added; all 5 search tests added. Yes.
- Discipline: only the two specified files were committed; no comments added; no new dependencies; only the game module touched. Yes.
- Testing: RED -> GREEN confirmed; dedupe, per-source isolation, and all-fail covered; analyze clean. Yes.

## Concerns
None. (Pre-existing uncommitted changes under `.superpowers/sdd/` were left untouched and not staged.)
