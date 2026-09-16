# Task 3 Report: 轻小说探索页接入 SlideSwitcher

## What I implemented

Modified `lib/modules/novel/novel_home.dart`:

1. Added import `import '../../core/widgets/slide_switcher.dart';` (placed alphabetically between `shimmer_loader.dart` and `smooth_route.dart`).
2. At the top of `_ExploreTabState._body`, added:
   ```dart
   final sourceIndex =
       ref.watch(novelSourcesProvider).indexWhere((s) => s.id == _sourceId);
   ```
3. 「推荐」branch (`_groupIndex < 0`): replaced `return async.when(...)` with `return SlideSwitcher(id: (_sourceId, '__home__'), index: sourceIndex * 1000000, child: async.when(...))`, wrapping the entire `async.when` so it stays mounted across loading→data.
4. Group branch: replaced `return async.when(...)` with `final pageData = async.valueOrNull;` then `return Column(children: [Expanded(child: SlideSwitcher(id: (_sourceId, option.key, _page), index: ..., child: async.when(...))), if (pageData != null) _pager(pageData.hasMore)])`. The pager stays outside the switcher as a sibling.

## Commands + results

- `C:\flutter\bin\flutter.bat test test/modules/novel/novel_home_tabs_test.dart` → `+2: All tests passed!`
- `C:\flutter\bin\flutter.bat test test/modules/novel/novel_home_pager_test.dart` → `+1: All tests passed!`
- `C:\flutter\bin\flutter.bat analyze` → `No issues found! (ran in 3.1s)`

## Files changed

- `lib/modules/novel/novel_home.dart` (only file committed)

Commit: `fda1d82 feat(novel): slide the grid when switching sections or pages` (branch `dev`)

## Self-review

- Completeness: import added; `sourceIndex` computed; both branches wrapped; pager outside the switcher. ✅
- Discipline: only `novel_home.dart` staged/committed; no comments added. ✅
- Testing: both regression tests pass; analyze clean. ✅

## Concerns

None. Pre-existing unstaged modifications under `.superpowers/sdd/` were left untouched and not committed.
