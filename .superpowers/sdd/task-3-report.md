# Task 3 Report: linovelib 纯解析函数

## What I implemented

Created `lib/core/novel/linovelib_source.dart` containing only the constants and top-level pure parsing functions (no `LinovelibSource` class — deferred to Task 4):

- `const String linovelibBaseUrl`
- `const String linovelibUserAgent`
- `String? novelIdFromHref(String? href)`
- `List<Novel> parseBookList(String html)`
- `List<Novel> parseHome(String html)`
- `List<Novel> parseRankRows(String html)`
- `bool hasNextPage(String html)`
- Private helpers `_absUrl`, `_textOf`, `_novelFromBookLi`, and `_novelHref` regex.

Consumes Task 1's `models.dart` (`Novel`, `NovelSection`); no models redefined. No new dependencies added.

Created `test/core/novel/linovelib_parser_test.dart` verbatim from the brief with the real trimmed fixtures.

## What I tested and results

- Focused test: `flutter test test/core/novel/linovelib_parser_test.dart` → 5/5 passed.
- Full suite: `flutter test` → 180 passed, 1 skipped (pre-existing `js_engine_smoke_test` skip), 0 failed.
- `flutter analyze lib test` → `No issues found!`

## TDD Evidence

### RED

Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_parser_test.dart
```

Output (failing):
```
test/core/novel/linovelib_parser_test.dart:2:8: Error: Error when reading 'lib/core/novel/linovelib_source.dart': 系统找不到指定的文件。
test/core/novel/linovelib_parser_test.dart:38:12: Error: Method not found: 'novelIdFromHref'.
test/core/novel/linovelib_parser_test.dart:45:19: Error: Method not found: 'parseBookList'.
test/core/novel/linovelib_parser_test.dart:55:22: Error: Method not found: 'parseHome'.
test/core/novel/linovelib_parser_test.dart:62:19: Error: Method not found: 'parseRankRows'.
test/core/novel/linovelib_parser_test.dart:72:12: Error: Method not found: 'hasNextPage'.
00:00 +0 -1: Some tests failed.
```

Why expected: the test imports `lib/core/novel/linovelib_source.dart`, which did not exist yet, so compilation fails and every referenced top-level function is reported missing.

### GREEN

Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_parser_test.dart
```

Output (passing):
```
00:00 +0: novelIdFromHref extracts id
00:00 +1: parseBookList keeps only book entries with a.title
00:00 +2: parseHome returns titled sections
00:00 +3: parseRankRows parses rank rows
00:00 +4: hasNextPage detects the next link
00:00 +5: All tests passed!
```

## Files changed

- `lib/core/novel/linovelib_source.dart` (new)
- `test/core/novel/linovelib_parser_test.dart` (new)

## Self-review findings

- Confirmed the file contains only the two constants and the five required top-level functions plus private helpers; no `LinovelibSource` class was added (Task 4's responsibility).
- Function names/signatures match the brief exactly so Task 4 can depend on them.
- `parseBookList` correctly skips the second fixture `<li>` (no `a.title`), yielding length 1.
- `parseHome` derives the section title from `div.top-title .title` and only emits sections with non-empty items.
- `parseRankRows` reads rank from `div.rank_i_num` and stores it in `extra['rank']`; cover prefers `data-original` then `src`; relative URLs are absolutized.
- `hasNextPage` matches anchor text containing 下一页/下页.
- No comments added; code matches brief verbatim.

## Concerns

- None functional. Note: the pre-existing working-tree modifications to `.superpowers/sdd/*` were left untouched and not included in the commit (only the two brief-specified files were staged), per the task instruction.

## Commit

- `c08c2f8` feat(novel): add linovelib html parsers (pushed to `dev`)
