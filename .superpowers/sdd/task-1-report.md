# Task 1 Report: æµè§ˆåˆ†ç»„é€šç”¨åŒ–ï¼ˆæ¨¡å‹ / æ¥å£ / linovelib / é¦–é¡µ UIï¼‰

## Status

DONE

## What I implemented

Replaced the hardcoded `NovelBrowseKind {ranking, bunko}` enum + `NovelBrowse` class with
source-declared browse groups/options, so each source can declare its own browse taxonomy.

- **models.dart**: Removed `NovelBrowseKind`/`NovelBrowse`; added `NovelBrowseOption`
  (`key`, `label`) and `NovelBrowseGroup` (`label`, `options`). Added optional `id` field to
  `NovelVolume` (for future lknovel per-volume chapter fetching), preserving `title`/`url`/
  `chapters` and the existing default for `chapters`.
- **novel_source.dart**: Replaced `browse(NovelBrowse, {page})` with
  `List<NovelBrowseGroup> get browseGroups` and `browse(String optionKey, {int page = 1})`.
  `NovelSourceManager` untouched.
- **linovelib_source.dart**: Added `static const Set<String> rankingKeys`; added
  `browseGroups` declaring æ’è¡Œ (13 options) and æ–‡åº“ (14 options) â€” exactly the option
  key/label pairs that previously lived in `novel_home.dart`; rewrote `browse` to dispatch
  ranking vs. bunko via `rankingKeys` and call `rankPath`/`bunkoPath` + `parseRankRows`/
  `parseBookList` as before. `rankPath`/`bunkoPath` remain.
- **novel_providers.dart**: `novelBrowseProvider` family key changed from
  `(String, NovelBrowseKind, String, int)` to `(String, String, int)`
  `(sourceId, optionKey, page)`.
- **novel_home.dart**: Full rewrite to render source chips, then group chips (æ¨è + one chip
  per `source.browseGroups` group), then option chips for the selected group, then the body
  (home feed for æ¨è, paged browse list for a group). Removed `_NovelSection`,
  `_rankingOptions`, `_bunkoOptions`. `NovelCard`, `_pager`, `_grid`, `_chip` kept unchanged.
- **Tests**: Updated `models_test.dart` (group/option test), `novel_source_test.dart`
  (`_FakeSource` now overrides `browseGroups` + new `browse`), and
  `novel_home_pager_test.dart` (`_FakeSource` declares a æ’è¡Œ group and new `browse`).

## Commands run and results

```
$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test
=> No issues found! (ran in 4.3s)

$env:Path = "C:\flutter\bin;$env:Path"; flutter test
=> 00:08 +210 ~1: All tests passed!
   (1 pre-existing skip: js_engine_smoke_test â€” flutter_qjs native lib unavailable under test)
```

## Commit

- `683433e` refactor(novel): source-declared browse groups
- Pushed to `origin/dev` (`7ce8641..683433e`).

## Files changed (all 8 from the brief)

1. lib/core/novel/models.dart
2. lib/core/novel/novel_source.dart
3. lib/core/novel/linovelib_source.dart
4. lib/modules/novel/novel_providers.dart
5. lib/modules/novel/novel_home.dart
6. test/core/novel/models_test.dart
7. test/core/novel/novel_source_test.dart
8. test/modules/novel/novel_home_pager_test.dart

## Self-review findings

- All 8 files in the brief's `Files:` list were updated and staged/committed.
- The three test files compile against the new signatures; `flutter analyze lib test` is clean.
- `flutter test` is fully green (210 passed, 1 pre-existing skip unrelated to this task).
- `NovelBrowseKind` / `NovelBrowse` have no remaining references in `lib/` or `test/`.
  A pre-existing dev probe `.superpowers/sdd/novel_rank_probe.dart` still uses the old API,
  but it is outside `lib`/`test` (not analyzed by the required command) and is a scratch probe,
  not shipped code. Left untouched per the brief.
- The brief file itself (`.superpowers/sdd/task-1-brief.md`) showed as modified in the working
  tree but was NOT touched by me; it was not staged or committed.

## Concerns

- None blocking. Minor: `.superpowers/sdd/novel_rank_probe.dart` is now stale against the new
  interface. If a future task runs `flutter analyze` over the whole repo (including
  `.superpowers`), it would flag that probe. Not part of this task's required scope.

---

# Fix Report: cover linovelib browse path routing

## Finding addressed

The spec (`docs/superpowers/specs/2026-09-14-lknovel-source-design.md`, ²âÊÔ) requires
`test/core/novel/linovelib_browse_test.dart` to assert `browseGroups` shape and the
ranking-vs-bunko `browse` dispatch. Task 1 omitted it, leaving the new dispatch untested.
The spec permits verifying routing by asserting a path-mapping function.

## Files changed

1. `lib/core/novel/linovelib_source.dart`
   - Extracted the path choice from `browse` into public
     `static String browsePath(String optionKey, int page)` and call it from `browse`.
2. `test/core/novel/linovelib_browse_test.dart` (new)
   - Asserts exactly 2 groups labelled `['ÅÅĞĞ', 'ÎÄ¿â']`; ÅÅĞĞ keys include
     `allvisit`/`monthvote`/`newhot`; ÎÄ¿â keys include
     `dengekibunko`/`chineselightnovel`/`other`;
     `browsePath('allvisit', 1) == '/top/allvisit/1.html'`,
     `browsePath('allvisit', 2) == '/top/allvisit/2.html'`,
     `browsePath('dengekibunko', 2) == '/wenku/dengekibunko/2.html'`.

## Commands run and results

```
$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test
=> No issues found! (ran in 2.0s)

$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_browse_test.dart test/core/novel/linovelib_source_test.dart
=> 00:00 +10: All tests passed!

$env:Path = "C:\flutter\bin;$env:Path"; flutter test
=> 00:11 +215 ~1: All tests passed!
   (1 pre-existing skip: js_engine_smoke_test)
```

## Concerns

- None.
