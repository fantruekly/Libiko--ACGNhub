# Task 7 Report: 轻小说插图渲染（正文块模型）

## Status: DONE

## What I implemented

Root cause: linovelib 插图章节把图片放在 `div#TextContent` 内，真实地址在 `data-src`（`src` 是 `sloading.svg` 懒加载占位），旧阅读器只提取 `<p>`，图片丢失。

1. **`lib/core/novel/models.dart`** — 用有序块模型替换 `NovelChapter.content: String`：
   - `sealed class NovelBlock`
   - `class NovelText extends NovelBlock { final String text; }`
   - `class NovelImage extends NovelBlock { final String url; }`
   - `class NovelChapter { final String title; final List<NovelBlock> blocks; }`
2. **`lib/core/novel/linovelib_source.dart`**：
   - 新增 `_imageUrl(dom.Element)`：优先 `data-src`，回退 `src`；跳过含 `sloading` 或以 `.svg` 结尾的占位符；其余经 `_absUrl` 补全。
   - `parseChapter` 改为遍历 `div#TextContent` 的**直接子元素**（按顺序）：`p` → `NovelText`（trim 后非空），`img` → `NovelImage`。
   - `fetchChapterPages` 改为跨分页拼接块列表。
3. **`lib/modules/novel/novel_reader_page.dart`**：
   - 引入 `cached_network_image`。
   - `_content` 遍历 `chapter.blocks`，用 switch 模式匹配渲染 `NovelText`（保留字号/行距/前景色）与 `NovelImage`（`ClipRRect` + `CachedNetworkImage`，含 placeholder / errorWidget）。空块显示「本章暂无内容」。
4. **测试**：更新所有因模型变更受影响的测试文件（含上下文未列出的两个 ripple 文件）。

## What I tested and results

- `flutter analyze lib test` → **No issues found!**
- `flutter test` → **All tests passed!** (211 passed, 1 skipped)
- 定点：`flutter test test/core/novel/linovelib_chapter_parser_test.dart test/modules/novel/novel_reader_page_test.dart` → **All tests passed!** (7 tests)

## TDD Evidence

### RED

Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_chapter_parser_test.dart
```
Failing output (excerpt):
```
test/core/novel/linovelib_chapter_parser_test.dart:24:13: Error: 'NovelImage' isn't a type.
test/core/novel/linovelib_chapter_parser_test.dart:49:29: Error: 'NovelText' isn't a type.
test/core/novel/linovelib_chapter_parser_test.dart:22:10: Error: The getter 'blocks' isn't defined for the type 'NovelChapter'.
  - 'NovelChapter' is from 'package:acgnhub/core/novel/models.dart'
00:00 +0 -1: Some tests failed.
```
Why expected: tests were written against the new interface (`NovelBlock`/`NovelText`/`NovelImage`/`blocks`) before the model existed, so the compiler rejected the undefined types/getters — the intended red state proving the tests exercise the new API.

### GREEN

Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_chapter_parser_test.dart test/modules/novel/novel_reader_page_test.dart
```
Passing output:
```
00:00 +0: ... parseChapter reads title, paragraphs and images in order
00:00 +1: ... parseChapter extracts lazy-loaded images and skips placeholders
00:00 +2: ... parseChapter falls back to the given title
00:00 +3: ... nextPageHref returns same-chapter page links only
00:00 +4: ... fetchChapterPages concatenates same-chapter pages
00:00 +5: ... NovelReaderPage renders the chapter title and paragraphs
00:00 +6: ... tapping 下一章 loads the next chapter
00:00 +7: All tests passed!
```

Full suite: `flutter test` → `00:08 +211 ~1: All tests passed!`

## Files changed

- `lib/core/novel/models.dart`
- `lib/core/novel/linovelib_source.dart`
- `lib/modules/novel/novel_reader_page.dart`
- `test/core/novel/linovelib_chapter_parser_test.dart`
- `test/modules/novel/novel_reader_page_test.dart`
- `test/core/novel/novel_source_test.dart` (ripple: `NovelChapter(title:'t', content:'c')` → `blocks:[NovelText('c')]`)
- `test/modules/novel/novel_home_pager_test.dart` (same ripple)

Commit: `6b7dc5b fix(novel): render chapter illustrations (block model with images)` (pushed to `dev`, `d4878d6..6b7dc5b`).

## Self-review findings

- **Ripple check**: `grep` for `NovelChapter(` and `.content` under `lib/` and `test/` surfaced two test files beyond the brief's list (`novel_source_test.dart`, `novel_home_pager_test.dart`); both updated. No remaining `content:` usages under the novel tests, and no `.content` references remain in `lib/core/novel/`.
- **Diff fidelity**: implementation matches the brief's verbatim code (verified via `git diff`).
- **No new dependency**: reused `cached_network_image ^3.4.1` (already in `pubspec.yaml`).
- **No `fontFamily`** is set in any `TextStyle`.
- **No real network in tests**: reader test overrides providers; parser tests use inline HTML strings.

## Concerns

- `parseChapter` now iterates only **direct children** of `#TextContent` (per the brief/verified DOM). If some chapter variant nests paragraphs inside a wrapper `div`, those would no longer be picked up. Current linovelib structure puts `p`/`img` as direct children, so this is correct for the known case.
- `_imageUrl` prefers `data-src` unconditionally; a placeholder in `data-src` with a real `src` would be skipped, but that ordering matches the site's lazyload convention.
