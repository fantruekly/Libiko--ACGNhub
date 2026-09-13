# Task 7 Report: Shell wiring + final verification

## Status: DONE_WITH_CONCERNS

The only concern is that the brief's Step 3 manual in-app smoke test was not run (cannot drive a GUI); it is left to the human. All automated verification passed.

## What I implemented

Modified only `lib/shell/main_shell.dart`:

1. Added imports:
   - `import '../modules/comic/comic_home.dart';`
   - `import '../modules/comic/comic_search.dart';`
2. Replaced the 漫画 `_buildModulePlaceholder(...)` entry at `_pages[1]` with `const ComicHomePage()`.
3. Made the title-bar search `IconButton` render for `_currentIndex == 0 || _currentIndex == 1`, and the `MaterialPageRoute` builder now picks `const AnimeSearchPage()` for index 0 and `const ComicSearchPage()` for index 1. The existing push style and icon/colour/splashRadius were preserved.
4. Left `_buildModulePlaceholder` in place because the 轻小说 and 游戏 entries still use it.

No comments were added. Style matches the surrounding code.

## Exact verification commands and observed results

1. `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
   - Observed: `Analyzing 2 items...` then `No issues found! (ran in 1.6s)`
2. `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
   - Observed: `00:06 +136 ~1: All tests passed!`
   - (`~1` is the pre-existing intentional skip in `test/core/comic/js_engine_smoke_test.dart`, documented in that test: flutter_qjs native lib is not loadable under `flutter test`.)
3. `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug`
   - Observed: `√ Built build\windows\x64\runner\Debug\acgnhub.exe`
   - One unrelated CMake dev warning from the `webview_windows` plugin (`CMP0175` / DEPENDS); non-fatal and pre-existing.

## Files changed and commit

- `lib/shell/main_shell.dart` (1 file changed, 7 insertions(+), 4 deletions(-))
- Commit: `763add6` — `feat(comic): wire the comic module into the shell`
- Command used: `git add lib/shell/main_shell.dart` then `git commit -m "feat(comic): wire the comic module into the shell"`.
- Only the shell file was staged. The working tree also contains pre-existing unrelated modifications (`.superpowers/sdd/*`, generated plugin registrants, etc.) which were intentionally not staged.

## Self-review findings

- Confirmed `ComicHomePage` and `ComicSearchPage` both have `const` constructors (`comic_home.dart:19`, `comic_search.dart:15`), so `const ComicHomePage()` / `const ComicSearchPage()` are valid.
- The `_pages` list remains a `final` instance field; `const ComicHomePage()` fits the existing `const AnimeHomePage()` pattern.
- `IndexedStack` still indexes `_pages` by `_currentIndex`; index 1 now correctly shows the comic home.
- `_buildModulePlaceholder` is still referenced twice (轻小说, 游戏), so no unused-element analyzer warning.
- Title `_titles[1]` is already `'漫画'`, matching the new page.
- The diff contains no comments and no unrelated changes.
- `git show HEAD` verified the commit contains exactly the three intended edits.

## Concerns

- **Manual smoke test not run.** Brief Step 3 (launch GUI, import `assets/comic_source/test_source.js`, verify capability chips, search two fixture results, open detail, toggle 收藏, check 收藏/历史 tabs) requires driving a GUI, which this environment cannot do. Left to the human.
- The `flutter analyze`/`flutter test`/`flutter build` runs re-resolved dependencies and may have touched generated files, but none of those were staged; the commit is limited to `lib/shell/main_shell.dart`.

## Final-review fix

### What changed

Fix 1 — serialized the comic local-store writes to close the double-toggle race:

- `lib/core/comic/comic_favorite.dart`: added the `_pending`/`_enqueue` serialization pattern from `FollowManager`. `toggle`, `remove`, and `clear` now route through `_enqueue`. `toggle`'s "exists" branch inlines the removal logic instead of calling `remove` (avoids nesting enqueues and deadlocking on `_pending`). Public signatures, `all()`/`isFavorite()`/`upsert()`, dedupe, newest-first ordering, and malformed-entry skipping are unchanged.
- `lib/core/comic/comic_history.dart`: same `_pending`/`_enqueue` pattern; `record` and `clear` route through it. `all()`/`forComic()`/`upsert()` unchanged.

Fix 2 — surfaced total search failure instead of a false empty result:

- `lib/modules/comic/comic_providers.dart`: `comicSearchProvider` now collects the searchable (`canSearch`) sources, isolates per-source failures, and returns partial results when at least one source succeeded. If there is at least one searchable source and every searchable source threw, it throws `StateError('所有漫画源搜索失败：$lastError')`, which the search page's existing `.when(error:)` branch renders with the 重试 button. With no searchable sources it returns `const []`. Other providers were not touched.

No code comments were added.

### Exact verification commands and observed results

1. `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
   - Observed: `Analyzing 2 items...` then `No issues found! (ran in 2.0s)`
2. `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/comic/comic_favorite_test.dart test/core/comic/comic_history_test.dart`
   - Observed: `00:00 +7: All tests passed!`
3. `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
   - Observed: `00:08 +136 ~1: All tests passed!`
   - (`~1` is the pre-existing intentional skip in `test/core/comic/js_engine_smoke_test.dart`.)
4. `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug`
   - Observed: `√ Built build\windows\x64\runner\Debug\acgnhub.exe`
   - One unrelated CMake dev warning from the `webview_windows` plugin (`CMP0175` / `DEPENDS`); non-fatal and pre-existing.

### Commit

- `git add lib/core/comic/comic_favorite.dart lib/core/comic/comic_history.dart lib/modules/comic/comic_providers.dart`
- `git commit -m "fix(comic): serialize store writes and surface search failures"`
- Commit: `51791fd` — `fix(comic): serialize store writes and surface search failures` (3 files changed, 51 insertions(+), 22 deletions(-)).
- Only the three intended files were staged; the pre-existing unrelated working-tree modifications (`.superpowers/sdd/*`, generated plugin registrants) were left unstaged.
