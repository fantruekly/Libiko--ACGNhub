# Task 4 Report: `LinovelibSource`（HTTP + URL 拼接）

## What I implemented

Appended `class LinovelibSource implements NovelSource` to
`lib/core/novel/linovelib_source.dart`, after the Task 3 parsers (constants + pure
parsing functions kept untouched).

- Added imports `package:dio/dio.dart` and `novel_source.dart`; existing
  `html/dom.dart`, `html/parser.dart`, `models.dart` imports preserved.
- `LinovelibSource({Dio? dio})` — injectable Dio; default `BaseOptions` with
  `baseUrl: linovelibBaseUrl`, 20s connect/receive timeouts, and headers
  `User-Agent: linovelibUserAgent`, `Referer: https://www.linovelib.com/`.
- `id == 'linovelib'`, `name == '哔哩轻小说'`, `baseUrl == linovelibBaseUrl`.
- `static rankPath(key, page)` → `/top.html` when `key == 'allvisit'`, else
  `/top/<key>/<page>.html`.
- `static bunkoPath(key, page)` → `/wenku/<key>/<page>.html`.
- `_get(path)` — GET with `ResponseType.plain`, throws on non-200 / null body.
- `home()` — GET `/`, `parseHome`, throws if no sections.
- `browse(browse, {page})` — ranking → `rankPath` + `parseRankRows`, bunko →
  `bunkoPath` + `parseBookList`; `hasMore = items.isNotEmpty && hasNextPage(html)`.
- `search/detail/chapter` throw `UnimplementedError`.

## What I tested and results

- `test/core/novel/linovelib_source_test.dart` (3 tests): rankPath (monthvote +
  allvisit), bunkoPath, source identity — all pass.
- `flutter analyze lib test` — No issues found.
- `flutter test` — All tests passed (183 passed, 1 skipped pre-existing qjs
  native-library skip).
- No real network calls are made by the tests (only pure static methods and
  identity getters).

## TDD Evidence

### RED
Command: `flutter test test/core/novel/linovelib_source_test.dart`

Output (excerpt):
```
Error: Undefined name 'LinovelibSource'.
    expect(LinovelibSource.rankPath('monthvote', 1), '/top/monthvote/1.html');
Error: Method not found: 'LinovelibSource'.
    final s = LinovelibSource();
00:00 +0 -1: Some tests failed.
```
Why expected: the test file references `LinovelibSource` before it exists, so the
suite fails to compile — a genuine red state proving the test exercises the
not-yet-written API.

### GREEN
Command: `flutter test test/core/novel/linovelib_source_test.dart`

Output (excerpt):
```
00:00 +0: rankPath builds the ranking url
00:00 +1: bunkoPath builds the bunko url
00:00 +2: source identity
00:00 +3: All tests passed!
```

## Files changed

- `lib/core/novel/linovelib_source.dart` (modified, appended class + 2 imports)
- `test/core/novel/linovelib_source_test.dart` (new)

## Self-review findings

- Removed the brief's unused `import 'package:acgnhub/core/novel/models.dart';`
  from the test file. The brief supplied it, but the test never references
  `models.dart` symbols, and `flutter analyze lib test` reported
  `unused_import`, conflicting with the global "analyze clean" constraint. The
  test semantics are unchanged.
- `home()` uses path `'/'` against `baseUrl https://www.linovelib.com`; Dio
  resolves this to `https://www.linovelib.com/`. Correct.
- `browse` ranking with `key == 'allvisit'` ignores `page` (`/top.html`), as
  specified by the brief.
- No new dependencies added; `dio`/`html` were already present.

## Concerns

- `home()`/`browse()` parse live linovelib HTML and cannot be unit-tested
  offline; selectors are only validated indirectly by Task 3 parser tests. If
  linovelib changes `div.tab-lists`, `home()` will throw "首页解析为空".
- `browse`'s `hasMore` combines `items.isNotEmpty` with `hasNextPage`; an empty
  page that still shows a next-page link reports `hasMore == false`.
