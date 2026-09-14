# Task 3 Report: lknovel 详情目录与章节正文

## Status
DONE

## Implemented
- `LknovelSource.detail(String id)`: fetches `new-content-read/get-book-detail {book_id, with_volumes: 1}`, parses the book via `parseLkBook` and volume metadata via `parseLkVolumes`, then loads chapters per volume with bounded concurrency (batch size 6, `Future.wait`) and returns `NovelDetail`.
- `LknovelSource._volumeChapters(bookId, volumeId)`: pagination loop over `new-content-read/get-volume-chapters {book_id, volume_id, page, page_size: 50, pageSize: 50}`, accumulating `parseLkVolumeChapters` results and continuing while `lkHasMore` is true (hard cap page 100).
- `LknovelSource.chapter(novelId, chapterId)`: fetches `new-content-read/get-chapter-detail {book_id, chapter_id}` and parses via `parseLkChapter`.
- Added two tests appended to `test/core/novel/lknovel_source_test.dart`:
  - `detail loads every volume and its chapters`
  - `chapter fetches and parses chapter detail`

## TDD evidence
### RED
`flutter test test/core/novel/lknovel_source_test.dart` before implementation:
```
00:00 +10 -1: detail loads every volume and its chapters [E]
  UnimplementedError
  package:acgnhub/core/novel/lknovel_source.dart 281:44  LknovelSource.detail
00:00 +10 -2: chapter fetches and parses chapter detail [E]
  UnimplementedError
  package:acgnhub/core/novel/lknovel_source.dart 285:7  LknovelSource.chapter
00:00 +10 -2: Some tests failed.
```

### GREEN
`flutter analyze lib test`:
```
Analyzing 2 items...
No issues found! (ran in 2.0s)
```
`flutter test` (full suite):
```
00:11 +227 ~1: All tests passed!
```
(227 passed, 1 pre-existing skipped)

## Files changed
- `lib/core/novel/lknovel_source.dart` (replaced the two `UnimplementedError` stubs, added `_volumeChapters`)
- `test/core/novel/lknovel_source_test.dart` (two appended tests)

## Commit
- `8e1159a` feat(novel): lknovel detail catalog and chapter reader (pushed to `origin/dev`)

## Self-review
- Both new tests pass; full suite green.
- Per-volume failure isolation verified by construction: each volume load is wrapped in `try/catch`, returning `NovelVolume(... chapters: const [])` on failure so one failed volume cannot fail the whole `detail`.
- Bounded concurrency: batches of 6 via `Future.wait`, order preserved by `sublist`/`addAll`.
- `flutter analyze lib test` clean; no new dependencies; `pubspec.yaml` untouched.

## Concerns
- The pagination `page_size`/`pageSize` dual-key and the `page >= 100` safety cap are carried verbatim from the brief; not exercised by unit tests (poster mock returns no pagination, so `lkHasMore` falls back to `list.length >= 30`, which is false for the small fixtures and terminates after one page). This is expected for the mocked tests.
- `_volumeChapters` is a private method with no direct unit test; covered indirectly through the `detail` test.

---

# Whole-Branch Review Fixes

## Status
DONE

## Findings addressed
- Fix 1 (Important): normalized illustration URLs in `parseLkChapter`. Added `import 'package:html/dom.dart' as dom;` and top-level `_imageUrl(dom.Element)` helper (prefers `data-src` over `src`, resolves protocol-relative `//`, root-relative `/`, and bare relative paths against `lknovelBaseUrl`). Image branch now emits `NovelImage(_imageUrl(el)!)`.
- Fix 2 (Important): `parseLkBook` now prefers full `summary` over `summary_short`.
- Fix 3 (Minor): `_httpPost` uses `_asInt(map['code']) != 0` for a tolerant code check.
- Fix 4 (Minor): `rankingKeys` changed from `List<String>` to `Set<String>`; `contains(...)` call sites unchanged.
- Tests added: `parseLkBook prefers full summary over summary_short`, `parseLkChapter normalizes lazy and relative image urls`, `http post throws when code is non-zero`, `home skips a failing feed and keeps the rest`, `home throws when every feed is empty`, plus the `_FakeAdapter` test double and `dart:typed_data`/`dio` imports.

## Files changed
- `lib/core/novel/lknovel_source.dart`
- `test/core/novel/lknovel_source_test.dart`

## Commands + results
- `flutter analyze lib test` -> `No issues found! (ran in 1.7s)`
- `flutter test test/core/novel/lknovel_source_test.dart` -> `00:00 +17: All tests passed!`
- `flutter test` (full suite) -> `00:11 +232 ~1: All tests passed!` (232 passed, 1 pre-existing skipped)

## Note
- The brief's `_FakeAdapter` had an unused optional `status` parameter, which `flutter analyze` reported as `unused_element_parameter`. It was converted to a field `final int status = 200;` so the required `No issues found!` result holds; behavior is identical (always 200).

## Commit
- `fix(novel): normalize lknovel image urls and prefer full summary` (pushed to `origin/dev`)
