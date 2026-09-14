# Task 2 Report: `LinovelibSource.chapter`

## What I implemented

Replaced the `chapter` stub in `lib/core/novel/linovelib_source.dart`
(`LinovelibSource implements NovelSource`) with a real implementation delegating to
Task 1's `fetchChapterPages`, exactly as specified in `task-2-brief.md`:

```dart
  static String chapterPath(String novelId, String chapterId) =>
      '/novel/$novelId/$chapterId.html';

  @override
  Future<NovelChapter> chapter(String novelId, String chapterId) =>
      fetchChapterPages(novelId: novelId, chapterId: chapterId, fetch: _get);
```

- `chapterPath(novelId, chapterId)` → `/novel/<novelId>/<chapterId>.html`.
- `chapter(...)` calls `fetchChapterPages` with the existing `_get` as the `fetch`
  callback. `_get` is `Future<String> _get(String path)`, which matches the required
  `Future<String> Function(String path)` signature.
- `search` remains `throw UnimplementedError()` — untouched.
- No new dependencies added; `environment.sdk >=3.6.0` unchanged.

## What I tested and results

Appended the brief's test to `test/core/novel/linovelib_source_test.dart`:

```dart
  test('chapterPath builds the chapter url', () {
    expect(LinovelibSource.chapterPath('5340', '334356'), '/novel/5340/334356.html');
  });
```

Results:
- Targeted file: `00:00 +6: All tests passed!` (6 tests, including the new one).
- Full suite: `00:11 +203 ~1: All tests passed!` (203 passed, 1 pre-existing skip:
  flutter_qjs native lib not loadable under `flutter test`, unrelated to this task).
- `flutter analyze lib test`: `No issues found! (ran in 2.4s)`
- No real network calls were made in tests.

## TDD Evidence

### RED

Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_source_test.dart
```
Output (excerpt):
```
test/core/novel/linovelib_source_test.dart:43:28: Error: Member not found: 'LinovelibSource.chapterPath'.
    expect(LinovelibSource.chapterPath('5340', '334356'), '/novel/5340/334356.html');
                           ^^^^^^^^^^^
00:00 +0 -1: loading D:/ACGNhub/test/core/novel/linovelib_source_test.dart [E]
  Failed to load "...": Compilation failed for testPath=...: Member not found: 'LinovelibSource.chapterPath'.
00:00 +0 -1: Some tests failed.
```
Why expected: the new test references `LinovelibSource.chapterPath` before it exists, so the
test file cannot compile — exactly the intended "not implemented yet" failure.

### GREEN

Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_source_test.dart
```
Output:
```
00:00 +0: rankPath builds the ranking url
00:00 +1: bunkoPath builds the bunko url
00:00 +2: source identity
00:00 +3: detail/catalog paths
00:00 +4: allvisit is a single-page ranking
00:00 +5: chapterPath builds the chapter url
00:00 +6: All tests passed!
```

## Files changed

- `lib/core/novel/linovelib_source.dart` (modified; +5/-1)
- `test/core/novel/linovelib_source_test.dart` (modified; +4)

## Commit / push

- `79c4d7c feat(novel): implement LinovelibSource.chapter`
- Pushed to `origin/dev`: `9d9cf5b..79c4d7c dev -> dev`

## Self-review findings

- Implementation matches the brief's code verbatim.
- `_get` signature (`Future<String> Function(String)`) is compatible with the `fetch`
  parameter, so the delegation is type-correct and analyze is clean.
- `search` still throws `UnimplementedError`; only `chapter` changed.
- Confirmed only the two intended files were staged/committed; unrelated pre-existing
  modified files under `.superpowers/sdd/` and `docs/` were left untouched.

## Concerns

None. The `chapter` method is exercised indirectly through the path helper test only; the
page-fetching logic itself belongs to Task 1's `fetchChapterPages` and is covered by Task 1
tests.
