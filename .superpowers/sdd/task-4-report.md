# Task 4 Report: 漫画发现页接入 SlideSwitcher

## What I implemented

Modified `lib/modules/comic/comic_home.dart`:

1. Added import `import '../../core/widgets/slide_switcher.dart';` (between `shimmer_loader.dart` and `smooth_route.dart`).
2. Changed the `_explore` call site to pass `sources.indexOf(selected)`:
   `Expanded(child: _explore(selected, section, part, sources.indexOf(selected))),`
3. Added `int sourceIndex` parameter to `_explore`:
   `Widget _explore(ComicSource source, int section, int part, int sourceIndex) {`
4. Wrapped the `Expanded`'s child (the entire `async.when`) in `SlideSwitcher` with
   `id: (source.key, section, part, _page)` and
   `index: sourceIndex * 1000000 + section * 10000 + part * 100 + _page`.
   The `_paginationBar` remains a sibling outside the `SlideSwitcher`, inside the outer `Column`.

The switcher stays mounted across loading→data because it wraps the whole `async.when`,
not just the data branch.

## Commands + results

- `C:\flutter\bin\flutter.bat test test/modules/comic/comic_explore_paging_test.dart`
  → `00:00 +4: All tests passed!`
- `C:\flutter\bin\flutter.bat analyze`
  → `No issues found! (ran in 2.9s)`
- `git commit` → `f74cb47 feat(comic): slide the grid when switching sections or pages`
  (1 file changed, 50 insertions(+), 42 deletions(-))

## Files changed

- `lib/modules/comic/comic_home.dart` (only source file committed)

Note: several `.superpowers/sdd/*.md` files were already modified in the working tree before
this task; they were left unstaged and not committed.

## Self-review

- Completeness: import added; call site + signature updated; `SlideSwitcher` wraps the whole
  `async.when`; `_paginationBar` stays outside as a sibling. Yes.
- Discipline: only `comic_home.dart` changed and committed; no comments added; no new deps.
- Testing: regression test passes (4/4); analyze clean.

## Concerns

None.
