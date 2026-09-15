# Task 4 Report: galgamezywz 详情解析

## What I implemented

Appended to `lib/core/game/galgamezywz_source.dart`:
- `String _valueAfterColon(String text)` — extracts the trimmed value after an ASCII `:` or full-width `：`.
- `DateTime? _dateAfterColon(String text)` — parses a date from `_valueAfterColon`.
- `GameDetail parseGameDetail(String html, String sourceUrl)` — parses the detail page:
  - id from `sourceUrl` via `gameIdFromHref`
  - title from `h1.post-title` (fallback `.entry-title`)
  - cover from `.archive-shop .img-box img` `src`/`data-src` via `_absUrl`
  - meta rows from `.archive-shop .info-box .article-meta li` matched by prefix: 资源分类 (inner `a`), 浏览热度 (`parseCount`), 发布时间, 最近更新, 游戏大小, 游戏平台
  - tags from `.entry-tags a[rel="tag"]`
  - paragraphs from `article.post-content p` (fallback whole-text if no `p`)
  - screenshots from `article.post-content img src` (skip `data:`, dedupe, exclude cover)

Appended to `test/core/game/galgamezywz_parser_test.dart`:
- fixture `_detailHtml` (verbatim from the brief)
- test `parseGameDetail extracts meta, paragraphs, tags and screenshots`

No `GalgameZywzSource` class was added (that belongs to a later task). No new dependencies. No comments added.

## What I tested and test results

Command: `C:\flutter\bin\flutter.bat test test/core/game/galgamezywz_parser_test.dart`
Result: `00:00 +6: All tests passed!` (6 tests, including the 5 pre-existing listing/pagination tests).

Also ran: `C:\flutter\bin\flutter.bat analyze lib/core/game/galgamezywz_source.dart test/core/game/galgamezywz_parser_test.dart`
Result: `No issues found!`

## TDD Evidence

### RED
Command:
```
C:\flutter\bin\flutter.bat test test/core/game/galgamezywz_parser_test.dart
```
Output (excerpt):
```
Failed to load ".../galgamezywz_parser_test.dart":
Compilation failed ... test/core/game/galgamezywz_parser_test.dart:129:20:
Error: Method not found: 'parseGameDetail'.
      final detail = parseGameDetail(_detailHtml, '$galgameZywzBaseUrl/game/1207');
                     ^^^^^^^^^^^^^^^
00:00 +0 -1: Some tests failed.
```
Why expected: the test references `parseGameDetail`, which did not exist yet in the source file. This is the intended failing state before implementation.

### GREEN
Command:
```
C:\flutter\bin\flutter.bat test test/core/game/galgamezywz_parser_test.dart
```
Output (excerpt):
```
00:00 +0: gameIdFromHref extracts the numeric id
00:00 +1: parseCount parses K/M suffixes and raw numbers
00:00 +2: galgameZywzBrowsePath maps options to paths
00:00 +3: parseGameList keeps items with a /game/<id> link and skips others
00:00 +4: parseHasNextPage follows the next link, else the item-count fallback
00:00 +5: parseGameDetail extracts meta, paragraphs, tags and screenshots
00:00 +6: All tests passed!
```

## Files changed

- `lib/core/game/galgamezywz_source.dart` (+95)
- `test/core/game/galgamezywz_parser_test.dart` (+48)

Commit: `9b29830 feat(game): parse galgamezywz detail page`

## Self-review findings

- Completeness: matches the brief; `parseGameDetail` plus the two private helpers only. No `GalgameZywzSource` class, no extra files.
- Quality: follows the existing pattern of top-level parse functions and `_absUrl`/`_textOf` reuse.
- Discipline: no comments, no new deps, listing/pagination code and tests untouched.
- Testing: the new test exercises real parsing against the fixture; full file passes; analyzer clean.

## Issues / concerns

**Deviation from the brief's verbatim implementation (required to pass the brief's own test).**

The brief's provided screenshot loop was:
```dart
final src = _absUrl(im.attributes['src'] ?? im.attributes['data-src']);
if (src.isEmpty || src.startsWith('data:')) continue;
```
`_absUrl` is called first, so a `data:` URI (`data:image/gif;base64,AAAA`) does not start with `http`/`//`/`/` and gets rewritten to `https://game.galgamezywz.org/data:image/gif;base64,AAAA`. The subsequent `startsWith('data:')` check therefore never matches, and the fixture's data URI leaked into `screenshots` (observed failing output: actual had 2 entries vs. expected 1). This contradicts the brief's stated intent to "skip `data:`".

Minimal fix applied (checks the raw attribute before `_absUrl`):
```dart
final raw = im.attributes['src'] ?? im.attributes['data-src'];
if (raw == null || raw.isEmpty || raw.startsWith('data:')) continue;
final src = _absUrl(raw);
if (cover.isNotEmpty && src == cover) continue;
if (seen.add(src)) screenshots.add(src);
```
Behavior for all non-`data:` URLs is unchanged; the fixture now passes. This is the only deviation from the brief's provided code.

Also note: pre-existing uncommitted modifications to `.superpowers/sdd/*` files were present in the working tree; they were left untouched and not staged.
