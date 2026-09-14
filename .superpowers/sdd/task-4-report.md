# Task 4 Report: `novelChapterProvider` + `flattenChapters`

## Status: DONE

## What I Implemented

Appended to `lib/modules/novel/novel_providers.dart` (verbatim from the brief):

- `List<NovelChapterRef> flattenChapters(NovelDetail detail)` — flattens volumes in order.
- `final novelChapterProvider = FutureProvider.family<NovelChapter, (String, String, String)>((ref, key) async { ... })` — key `(sourceId, novelId, chapterId)`; looks up the source via `novelSourceManagerProvider.byId(sourceId)`; throws `StateError('novel source $sourceId not found')` when unknown; delegates to `source.chapter(novelId, chapterId)`.

Added the brief's `flattenChapters` test to `test/modules/novel/novel_providers_test.dart`.

## What I Tested and Results

- Targeted test: `flutter test test/modules/novel/novel_providers_test.dart` → **2 passed** (existing `flattenHome` + new `flattenChapters`).
- Full suite: `flutter test` → **208 passed, 1 skipped** (pre-existing skip: flutter_qjs native lib under flutter test; unrelated to this task).
- Static analysis: `flutter analyze lib test` → **No issues found**.

## TDD Evidence

### RED

Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_providers_test.dart
```

Failing output (excerpt):
```
test/modules/novel/novel_providers_test.dart:28:12: Error: Method not found: 'flattenChapters'.
    expect(flattenChapters(detail).map((c) => c.id), ['a', 'b', 'c']);
           ^^^^^^^^^^^^^^^
00:00 +0 -1: loading .../novel_providers_test.dart [E]
  Failed to load ...: Compilation failed ...: Method not found: 'flattenChapters'.
00:00 +0 -1: Some tests failed.
```

Why expected: `flattenChapters` did not yet exist, so the test file fails to compile — exactly the intended RED for a not-yet-defined API.

### GREEN

Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_providers_test.dart
```

Passing output (excerpt):
```
00:00 +0: flattenHome merges sections and dedupes by id
00:00 +1: flattenChapters flattens volumes in order
00:00 +2: All tests passed!
```

## Files Changed

- `lib/modules/novel/novel_providers.dart` (modified; +12 lines)
- `test/modules/novel/novel_providers_test.dart` (modified; +17 lines)

Commit: `0103699 feat(novel): add novelChapterProvider and flattenChapters` — pushed to `dev` (`a00f8a0..0103699`).

## Self-Review Findings

- Implementation matches the brief exactly (signatures, key tuple order, `StateError` message).
- `flattenChapters` preserves volume order and chapter order (uses an ordered collection-for over `detail.volumes`).
- Provider follows the same source-lookup/`StateError` pattern as the existing `novelHomeProvider`/`novelBrowseProvider`/`novelDetailProvider` in the same file — consistent with conventions.
- No new dependencies added; only `flutter_riverpod` + existing imports.
- Only the two intended files were staged/committed (the other modified `.superpowers`/`docs` files in the worktree were left untouched).

## Concerns

- None blocking. The `novelChapterProvider` itself is not directly exercised by a unit test in this task (the brief only specified the `flattenChapters` test). It is a thin delegation mirroring already-tested sibling providers; Task 5 will consume it. If desired, a provider-override test could be added later.
