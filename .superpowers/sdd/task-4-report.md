# Task 4 Report: 搜索页与入口

## Status: DONE

## What I Implemented

- **Created** `lib/modules/novel/novel_search.dart` — `NovelSearchPage`
  (`ConsumerStatefulWidget`, `String? initialKeyword`), transcribed verbatim
  from the brief. Mirrors `comic_search.dart`: a top search bar
  (back button, autofocus text field with `initialKeyword`, clear button,
  搜索 button), an `EmptyState` prompt (`输入关键词搜索轻小说`) before a keyword
  is entered, and a `GridView` of `NovelCard`s fed by
  `novelSearchProvider(_keyword)`. Loading uses `ShimmerLoader`
  (`crossAxisCount: 6`, `aspectRatio: 0.58`); empty results show
  `没有找到轻小说`; errors show a retry `EmptyState`. Tapping a card pushes
  `noTransitionRoute(NovelDetailPage(...))` with the result's `sourceKey`.
- **Modified** `lib/shell/main_shell.dart` — added
  `import '../modules/novel/novel_search.dart';` and widened the top-bar search
  condition from `_currentIndex == 0 || _currentIndex == 1` to
  `_currentIndex >= 0 && _currentIndex <= 2`, adding the novel branch
  (`const NovelSearchPage()`). Anime (0) and comic (1) behavior unchanged.
- **Created** `test/modules/novel/novel_search_page_test.dart` — the brief's two
  widget tests, transcribed verbatim.

No new dependencies; `pubspec.yaml` untouched. No new comments. Chinese UI copy.

## TDD Evidence

### RED

Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_search_page_test.dart
```

Output (excerpt):
```
test/modules/novel/novel_search_page_test.dart:6:8: Error: Error when reading
'lib/modules/novel/novel_search.dart': 系统找不到指定的文件。
test/modules/novel/novel_search_page_test.dart:17:38: Error: Method not found:
'NovelSearchPage'.
test/modules/novel/novel_search_page_test.dart:26:32: Error: Method not found:
'NovelSearchPage'.
00:00 +0 -1: Some tests failed.
```

Why expected: `novel_search.dart` did not exist yet, so compilation fails —
exactly as the brief's Step 2 predicts.

### GREEN

Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_search_page_test.dart
```

Output:
```
00:00 +0: renders results from the provider
00:00 +1: shows a prompt before searching
00:00 +2: All tests passed!
```

## Verification

```
$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test
→ No issues found! (ran in 2.0s)
```

```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test
→ 00:10 +259 ~1: All tests passed!
  (259 passed, 1 pre-existing skip: flutter_qjs native lib)
```

## Files Changed

- `lib/modules/novel/novel_search.dart` (new)
- `lib/shell/main_shell.dart` (modified)
- `test/modules/novel/novel_search_page_test.dart` (new)

## Self-Review

- **Both page tests pass.** `renders results from the provider`: the overridden
  `novelSearchProvider('关键词')` resolves after two pumps and `find.text('结果书')`
  finds one widget. `shows a prompt before searching`: with no `initialKeyword`,
  `_keyword` is empty so `find.text('输入关键词搜索轻小说')` finds one widget. ✅
- `flutter analyze lib test` clean. ✅
- `flutter test` fully green (only the pre-existing `flutter_qjs` skip). ✅
- Only the three allowed code files changed; `pubspec.yaml` untouched; no new
  comments. ✅
- `main_shell.dart` diff verified to match the brief's Step 5 replacement exactly. ✅

## Concerns

- Manual on-device verification (brief's 验证 section: build, switch to the novel
  module, real keyword such as 「败犬」, enter detail) was not performed in this
  environment; only automated `flutter test` / `flutter analyze` were run.
- The pre-existing `.superpowers/sdd/*` report/brief files were already modified
  in the worktree before this task; they were left untouched by the commit
  (only the three task files were staged), per the brief's Step 7.

---

# Whole-Branch Review Fixes

## Status: DONE

## Findings Addressed

- **Fix 1 (Important): missing empty-results page test.** Added the
  `shows empty message when there are no results` widget test to
  `test/modules/novel/novel_search_page_test.dart`, overriding
  `novelSearchProvider('关键词')` with an empty list and asserting
  `没有找到轻小说` renders. This completes the spec's three page cases
  (results / prompt / empty).
- **Fix 2 (Minor): zero-source guard.** Added `if (sources.isEmpty) return const [];`
  in `novelSearchProvider` (`lib/modules/novel/novel_providers.dart:74`), right
  after `sources` is read. Matches the comic provider's
  `if (searchable.isEmpty) return const [];` and prevents the misleading
  `StateError('所有轻小说源搜索失败：null')`.
- **Fix 3 (Minor): empty-keyword coverage.** Added `empty keyword returns no results`
  and `no sources returns empty` to
  `test/modules/novel/novel_search_provider_test.dart`, and
  `search returns empty for a blank keyword` to
  `test/core/novel/lknovel_source_test.dart` (asserting the poster is never called).
- **Fix 4 (Minor): linovelib `src` fallback test.** Added
  `parseSearchResults falls back to img src when data-original missing` to
  `test/core/novel/linovelib_search_parser_test.dart`.

No new comments were added.

## Verification

```
$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test
→ No issues found! (ran in 2.2s)
```

```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/ test/core/novel/
→ 00:03 +92: All tests passed!
```

```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test
→ 00:10 +264 ~1: All tests passed!
  (264 passed, 1 pre-existing skip: flutter_qjs native lib)
```

## Files Changed

- `lib/modules/novel/novel_providers.dart` (modified)
- `test/modules/novel/novel_search_page_test.dart` (modified)
- `test/modules/novel/novel_search_provider_test.dart` (modified)
- `test/core/novel/lknovel_source_test.dart` (modified)
- `test/core/novel/linovelib_search_parser_test.dart` (modified)

## Concerns

- None. Full suite green; the only skip is the pre-existing `flutter_qjs`
  native-library skip unrelated to these changes.
