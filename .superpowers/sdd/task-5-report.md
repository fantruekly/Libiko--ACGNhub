# Task 5 Report: 阅读器页面 + 接线

## What I implemented

1. **`lib/modules/novel/novel_reader_page.dart`** (new) — `NovelReaderPage`
   (`ConsumerStatefulWidget`) + private `_ReaderSettingsSheet` (`ConsumerWidget`),
   based on the brief:
   - Consumes `novelReaderSettingsProvider` / `NovelReaderTheme` /
     `NovelReaderSettings` (Task 3), `novelChapterProvider` / `flattenChapters` /
     `novelDetailProvider` (Task 4), `EmptyState`, and three theme palettes
     (`light`/`sepia`/`dark`).
   - Content: splits `chapter.content` on blank lines into paragraphs, applies
     font size + line height from settings, tinted by the active palette.
   - Chrome: top bar (back + novel title), bottom bar (上一章 / 目录 / 设置 /
     下一章), tap-to-toggle chrome, catalog bottom sheet (current chapter check),
     settings bottom sheet (font size 12–28, line height 1.2–2.6, three themes).
   - Three states: loading spinner, error `EmptyState` with `重试`, data content.
   - Switching chapters resets the scroll to the top.
2. **`lib/modules/novel/novel_detail_page.dart`** (modified) — added
   `smooth_route.dart` + `novel_reader_page.dart` imports; changed each
   `PillButton` to `onTap: () => _openChapter(ch)`; replaced the
   `_openChapter()` SnackBar stub with a `Navigator.push(context, smoothRoute(
   NovelReaderPage(...)))` that passes `sourceKey` / `novelId` / `chapter.id` /
   novel `title`.
3. **`test/modules/novel/novel_reader_page_test.dart`** (new) — the brief's widget
   test with the two provider overrides, plus the repo-standard
   `SharedPreferences.setMockInitialValues({})` + `await AppDatabase.init()`
   `setUp` (see Self-review #1).

No new dependencies. No `TextStyle` sets `fontFamily` (grep-confirmed).

## What I tested and results

- `flutter test test/modules/novel/novel_reader_page_test.dart` → **PASS**.
- `flutter analyze lib test` → `No issues found!`
- `flutter test` (full suite) → **All tests passed!** (`+209 ~1`; the single skip
  is the pre-existing `flutter_qjs` native-library skip).
- `flutter build windows --debug` → `√ Built build\windows\x64\runner\Debug\acgnhub.exe`.
- Launched `acgnhub.exe`; process confirmed running after 5s (PID 37140), then
  terminated by the smoke check. Visual verification is **deferred to the human**
  — I cannot see the UI and do not claim visual success.

## TDD Evidence

### RED

Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_reader_page_test.dart
```

Failing output (excerpt):
```
test/modules/novel/novel_reader_page_test.dart:6:8: Error: Error when reading
'lib/modules/novel/novel_reader_page.dart': 系统找不到指定的文件。
import 'package:acgnhub/modules/novel/novel_reader_page.dart';
       ^
test/modules/novel/novel_reader_page_test.dart:22:15: Error: Method not found: 'NovelReaderPage'.
        home: NovelReaderPage(
              ^^^^^^^^^^^^^^^
00:00 +0 -1: Some tests failed.
```

Why expected: `novel_reader_page.dart` did not exist yet, so the import could not
be read and `NovelReaderPage` was unresolved — the test must fail before
implementation, exactly as the brief predicts.

### Intermediate failure (test-harness defect found)

After implementing the page verbatim, the first GREEN attempt still failed:
```
Bad state: AppDatabase not initialized. Call AppDatabase.init() first.
#803 NovelReaderSettingsManager.read (novel_reader_settings.dart:56:17)
#804 NovelReaderSettingsNotifier.build (novel_reader_settings.dart:75:43)
```
Cause: the brief's test watches `novelReaderSettingsProvider` (via the page) but
never initializes `AppDatabase`. Fixed by adding the repo-standard `setUp`
(see Self-review #1).

### GREEN

Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_reader_page_test.dart
```

Passing output:
```
00:00 +0: NovelReaderPage renders the chapter title and paragraphs
00:00 +1: All tests passed!
```

## Files changed

- `lib/modules/novel/novel_reader_page.dart` (new)
- `lib/modules/novel/novel_detail_page.dart` (modified)
- `test/modules/novel/novel_reader_page_test.dart` (new)

## Self-review findings

1. **Brief test did not initialize `AppDatabase`.** The reader watches
   `novelReaderSettingsProvider`, whose notifier reads `AppDatabase()`; without
   init it throws `StateError`. Added `SharedPreferences.setMockInitialValues({})`
   + `await AppDatabase.init()` in a `setUp`, matching
   `test/modules/anime/anime_detail_page_test.dart` and other repo tests. This is
   the only change to the brief's test.
2. **Brief's implementation never rendered the chapter title, but its own test
   asserts `find.text('第60話')`.** The top bar shows `widget.title` (the novel
   title `书名`); the chapter title (`NovelChapter.title`) appeared nowhere.
   Added a chapter-title heading at the top of `_content` (font size +4, w600,
   palette fg). This satisfies the test and matches reader expectations.
3. **`Stack` shrink-wrapped and the bottom bar overflowed (`RenderFlex overflowed
   by 147 pixels`).** Scaffold's body gives *loose* constraints; the only
   non-positioned child was the `SingleChildScrollView`, whose cross-axis width
   shrink-wraps its content, so the `Stack` sized to ~109px and the four-button
   bottom `Row` overflowed. Wrapped the content `GestureDetector` in
   `Positioned.fill`, so the `Stack` fills the available space. This bug would
   also occur at runtime, not just in tests.
4. `_topBar(_Palette, List<NovelChapterRef> chapters, int index)` takes `chapters`
   / `index` but does not use them (inherited from the brief). Left as-is to stay
   close to the brief; harmless, `flutter analyze` clean.
5. Verified the detail-page wiring diff is exactly the brief's two edits, and
   that the existing `novel_detail_page_test.dart` still passes (it does not tap a
   chapter, so no navigation is triggered).
6. Confirmed no `fontFamily` in either changed file; accent `0xFF007AFF`, fg
   `0xFF1C1C1E`, muted `0xFF5A5A5F` preserved; no new dependency added.

## Concerns

- **Deviations from the brief's "verbatim" code** (findings #1–#3) were required
  to make the brief's own Step 4 "Expected: PASS" true. All three are documented
  above; the brief as written is internally inconsistent.
- Visual/manual verification (正文显示、上一/下一章、目录、设置生效) is deferred to
  the human — I cannot see the UI. Build succeeded and the process starts; the
  widget test covers chapter title + paragraph rendering.
- `_goChapter` resets scroll via `_scroll.jumpTo(0)` before the new chapter's
  async load replaces the content; in practice the scroll view is rebuilt at
  offset 0, but this path is not unit-tested.
- The `.superpowers/sdd/*` doc modifications present before this task are left
  unstaged per the brief's exact `git add` list.
