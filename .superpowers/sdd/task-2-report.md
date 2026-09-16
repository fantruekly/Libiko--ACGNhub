# Task 2 Report: 游戏首页接入 SlideSwitcher

## What I implemented

Modified `lib/modules/game/game_home.dart` exactly per the brief:

1. Added import `import '../../core/widgets/slide_switcher.dart';` (alphabetically between
   `shimmer_loader.dart` and `smooth_route.dart`).
2. In `_body`, after `final option = ...`, added:
   ```dart
   final sourceIndex =
       ref.watch(gameSourcesProvider).indexWhere((s) => s.id == _sourceId);
   ```
3. Replaced the `data:` branch so the grid is wrapped in `SlideSwitcher` while `_pager`
   stays outside the switcher:
   ```dart
   data: (list) => Column(
     children: [
       Expanded(
         child: SlideSwitcher(
           id: (_sourceId, option.key, _page),
           index: sourceIndex * 10000 + _optionIndex * 100 + _page,
           child: _grid(list.items),
         ),
       ),
       _pager(list.hasMore),
     ],
   ),
   ```

`id`/`index` encode source/section/page with page as the lowest-order component
(`_optionIndex * 100 + _page`), so page flips animate as small forward/back steps.

## Commands and results

- `C:\flutter\bin\flutter.bat test test/modules/game/game_home_test.dart`
  → `+4: All tests passed!` (4 tests, PASS)
- `C:\flutter\bin\flutter.bat analyze`
  → `No issues found! (ran in 2.6s)`
- `git commit`
  → `[dev 77c0463] feat(game): slide the grid when switching sections or pages`
  `1 file changed, 10 insertions(+), 1 deletion(-)`

## Files changed

- `lib/modules/game/game_home.dart` (committed)

## Self-review

- Completeness: import added; `sourceIndex` computed; `_grid` wrapped in `SlideSwitcher`;
  `_pager` remains outside the switcher (direct child of the `Column`). Yes.
- Discipline: only `game_home.dart` staged/committed; no comments added; no new deps.
- Testing: regression test passes; analyze clean.

## Concerns

None. The pre-existing modified `.superpowers/sdd/*.md` files were left unstaged and
untouched by this commit.

## Fix: keep the slide switcher mounted across loading

### Change

`lib/modules/game/game_home.dart` `_body` (lines 161-190). The `SlideSwitcher` previously lived
inside the `data:` branch of `async.when`, so a source/section/page switch put the provider into
`loading`, the `data:` branch was replaced by the shimmer, the `SlideSwitcher` unmounted, and the
slide never played. The switcher now wraps the whole `async.when` (so it stays mounted across
loading/error/data) while `_pager` remains outside the switcher:

```dart
final pageData = async.valueOrNull;
return Column(
  children: [
    Expanded(
      child: SlideSwitcher(
        id: key,
        index: sourceIndex * 10000 + _optionIndex * 100 + _page,
        child: async.when(
          loading: () => LayoutBuilder(...),
          error: (_, __) => EmptyState(...),
          data: (list) => _grid(list.items),
        ),
      ),
    ),
    if (pageData != null) _pager(pageData.hasMore),
  ],
);
```

The `options.isEmpty` early return was left unchanged. No comments added.

### Commands run and output

- `C:\flutter\bin\flutter.bat test test/modules/game/game_home_test.dart`
  → `00:00 +4: All tests passed!`
- `C:\flutter\bin\flutter.bat analyze`
  → `No issues found! (ran in 2.7s)`
