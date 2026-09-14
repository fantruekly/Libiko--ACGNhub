# Task 1 Report: 轻小说章节解析函数

## Status: DONE

## What I implemented
Added three top-level pure functions to `lib/core/novel/linovelib_source.dart` (appended after `parseCatalog`, before `class LinovelibSource`), exactly as specified in the brief:

- `NovelChapter parseChapter(String html, String fallbackTitle)` — reads title from `#mlfy_main_text h1` (falls back to `fallbackTitle` when empty) and collects non-empty `<p>` texts under `div#TextContent`, joined with `\n\n`.
- `String? nextPageHref(String html, String novelId, String chapterId)` — finds the `下一页` `<a>` in `div.mlfy_page` and returns its href only when it matches `/novel/<novelId>/<chapterId>_<n>.html`; otherwise `null`.
- `Future<NovelChapter> fetchChapterPages({required String novelId, required String chapterId, required Future<String> Function(String path) fetch, int maxPages = 50})` — fetches the first page, then follows same-chapter page links, concatenating non-empty content with `\n\n`, bounded by `maxPages`.

No new dependency added; `html` package already imported. `NovelChapter` reused from `models.dart`, not redefined.

## What I tested and results
- `flutter test test/core/novel/linovelib_chapter_parser_test.dart` → `+4: All tests passed!` (4 tests).
- `flutter analyze lib test` → `No issues found! (ran in 2.7s)`.
- `flutter test` → `+202 ~1: All tests passed!` (202 passed; 1 skip is the pre-existing `js_engine_smoke_test.dart` flutter_qjs native-library skip, unrelated to this task).

## TDD Evidence

### RED
Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_chapter_parser_test.dart
```
Output (relevant):
```
test/core/novel/linovelib_chapter_parser_test.dart:18:16: Error: Method not found: 'parseChapter'.
test/core/novel/linovelib_chapter_parser_test.dart:30:12: Error: Method not found: 'nextPageHref'.
test/core/novel/linovelib_chapter_parser_test.dart:41:22: Error: Method not found: 'fetchChapterPages'.
Failed to load "test/core/novel/linovelib_chapter_parser_test.dart": Compilation failed
00:00 +0 -1: Some tests failed.
```
Why expected: the three functions did not exist in `linovelib_source.dart` yet, so the new test could not compile — the failure mode the brief predicted (`parseChapter` 未定义).

### GREEN
Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_chapter_parser_test.dart
```
Output:
```
00:00 +0: parseChapter reads title and paragraphs
00:00 +1: parseChapter falls back to the given title
00:00 +2: nextPageHref returns same-chapter page links only
00:00 +3: fetchChapterPages concatenates same-chapter pages
00:00 +4: All tests passed!
```

## Files changed
- `lib/core/novel/linovelib_source.dart` (modified)
- `test/core/novel/linovelib_chapter_parser_test.dart` (new)

Commit: `9d9cf5b feat(novel): add chapter parsers (paragraphs + same-chapter paging)` (pushed to `dev`).

## Self-review findings
- `parseChapter` filters blank `<p>` nodes, so `<br>` separators and empty paragraphs do not produce stray `\n\n`.
- `nextPageHref` deliberately returns `null` when the `下一页` link exists but is the next *chapter* (does not match the `_<n>` prefix), which is what keeps `fetchChapterPages` from spilling into the next chapter.
- `fetchChapterPages` guards against runaway/looping pagination with `maxPages` (default 50) and does not re-add empty content.
- Implementation matches the brief verbatim; signatures match the names/signatures later tasks depend on.
- `flutter analyze lib test` and the full `flutter test` suite are clean.

## Concerns
- `nextPageHref` matches the link text exactly (`下一页`); real linovelib pages could include surrounding whitespace, but `.trim()` handles that. If the site ever changes the label (e.g. `下一页 »`), this would need widening — out of scope here.
- `.superpowers/sdd/task-1-brief.md` and other `.superpowers/` / `docs/` files were already modified in the working tree before this task (orchestrator updates) and were intentionally NOT staged; only the two brief-listed files were committed.
