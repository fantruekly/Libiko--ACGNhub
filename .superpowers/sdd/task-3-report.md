# Task 3 Report: galgamezywz 列表与分页解析

## What I implemented

Created `lib/core/game/galgamezywz_source.dart` with exactly the symbols specified by the brief (nothing from later tasks):

- Constants: `galgameZywzBaseUrl`, `galgameZywzUserAgent`, `gameImageHeaders`.
- Pure/helper parse functions:
  - `gameIdFromHref(String? href)` — extracts numeric id from `/game/<digits>`, null otherwise.
  - `parseCount(String raw)` — parses `4.3K` / `125.2K` / `664` / embedded `浏览热度: (4.3K)`, null when empty/invalid.
  - `galgameZywzBrowsePath(String optionKey, int page)` — maps `latest` -> `/` or `/page/N`; category slugs -> `/lm/<slug>` or `/lm/<slug>/page/N`; throws `ArgumentError` on unknown key.
  - `parseGameList(String html)` — reads `article.post-item` inside the first `div.posts-warp`, resolves lazy cover via `data-bg`/`data-src`/`src`, parses title, summary, category, `time.pub-date[datetime]`, views, and skips items without a `/game/<id>` link.
  - `parseHasNextPage(String html, {required int itemCount})` — `true` iff `nav.page-nav a.page-link.page-next` exists (searching within the pagination scope), otherwise falls back to `itemCount >= 12`.
- Private helpers `_absUrl`, `_textOf`, `_categorySlugs`, `_gameHref`, `_firstPostsWarp`, `_paginationScope`, `_gameFromItem`.

The `GalgameZywzSource` class and `parseGameDetail` were intentionally NOT added (reserved for later tasks).

## What I tested and test results

Created `test/core/game/galgamezywz_parser_test.dart` with the brief's exact fixtures and 5 tests. All pass:

```
00:00 +5: All tests passed!
```

Also ran `flutter analyze` on both files: `No issues found!`

## TDD Evidence

### RED

Command: `C:\flutter\bin\flutter.bat test test/core/game/galgamezywz_parser_test.dart`

Output (excerpt):

```
test/core/game/galgamezywz_parser_test.dart:2:8: Error: Error when reading 'lib/core/game/galgamezywz_source.dart': 系统找不到指定的文件。
test/core/game/galgamezywz_parser_test.dart:56:12: Error: Method not found: 'gameIdFromHref'.
...
00:00 +0 -1: Some tests failed.
```

Why expected: the test imports `galgamezywz_source.dart`, which did not exist yet, so compilation fails with "Method not found" for every symbol — the correct failure for a missing implementation.

### GREEN

Command: `C:\flutter\bin\flutter.bat test test/core/game/galgamezywz_parser_test.dart`

Output:

```
00:00 +0: gameIdFromHref extracts the numeric id
00:00 +1: parseCount parses K/M suffixes and raw numbers
00:00 +2: galgameZywzBrowsePath maps options to paths
00:00 +3: parseGameList keeps items with a /game/<id> link and skips others
00:00 +4: parseHasNextPage follows the next link, else the item-count fallback
00:00 +5: All tests passed!
```

## Files changed

- `lib/core/game/galgamezywz_source.dart` (new)
- `test/core/game/galgamezywz_parser_test.dart` (new)

Commit: `6276962 feat(game): parse galgamezywz listing and pagination` on branch `dev`.

## Self-review findings

- Completeness: only the constants, helper functions, and listing/pagination parsers from the brief; no `GalgameZywzSource` class, no `parseGameDetail`.
- Quality: mirrors the parse-function pattern of `lib/core/novel/linovelib_source.dart` (`_absUrl`, `_textOf`, `_xxxFromItem`, top-level parse functions).
- Discipline: no extra files, no new dependencies, no comments beyond the three `///` doc comments present in the brief's provided code.
- Testing: fixtures and assertions are verbatim from the brief and exercise real parsing behavior; output is pristine.
- Pre-existing modified files under `.superpowers/sdd/` were left untouched and not staged.

## Issues or concerns

None.
