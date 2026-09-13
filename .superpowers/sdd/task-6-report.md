# Task 6 Report: Comic detail page

## What I implemented

### Part A — `lib/modules/comic/comic_detail_page.dart` (new)

`class ComicDetailPage extends ConsumerStatefulWidget` with the four required
constructor params (`sourceKey`, `comicId`, `title`, `cover`). Layout mirrors
`anime_detail_page.dart`:

- **`_header`**: `DragToMoveArea` → 48 px white `Container` (bottom border
  `#E5E5EA` 0.5) with a back `IconButton`, the `title` (`Expanded`, 16 px w600,
  ellipsis) and `const WindowControls()`.
- **Body**: `Scaffold(backgroundColor: Color(0xFFF2F2F7))` → `Column([_header,
  Expanded(child: _body())])`.
- **`_body`**: `ref.watch(comicDetailProvider((sourceKey, comicId)))`:
  - loading → `ShimmerLoader(crossAxisCount: 6, itemCount: 12)`.
  - error → `EmptyState(icon: Icons.error_outline_rounded, message: '加载失败',
    actionLabel: '重试', onAction: ref.invalidate(...))`.
  - data → `CustomScrollView` with the info card, chapter section, and (when
    history exists) the 继续阅读 button, plus a 24 px bottom spacer.
- **Info card**: `GlassSurface(blur: 0, borderRadius: 16, padding: 16, border
  #E5E5EA, boxShadow [0x0F000000/16/(0,6)])` around a `Row(crossAxisAlignment:
  start)`:
  - `Hero(tag: 'comic_${sourceKey}_$comicId')` → `RepaintBoundary` →
    `ClipRRect(10)` → 110×154 `CachedNetworkImage` (plain, `fit: cover`,
    `memCacheWidth: 300`, `errorWidget: _coverPlaceholder`) or
    `_coverPlaceholder` when the cover is null/empty. `ComicImageProvider` is
    intentionally not used (it belongs to the C2b reader).
  - 24 px gap → `Expanded` `Column`: title (20 px w600, max 2 lines), 14 px
    gap, 收藏 button, 14 px gap, tags `Wrap`, 10 px gap, description.
  - 收藏 button: `FilledButton.icon`, 36 px min height, radius 10; not
    favorite → `#007AFF` bg / white fg / `Icons.bookmark_add_outlined` / `收藏`;
    favorite → `#E5E5EA` bg / `#8E8E93` fg / `Icons.bookmark_added_rounded` /
    `已收藏`. State comes from `ref.watch(comicFavoritesProvider)` membership on
    `(sourceKey, comicId)`; press builds a `ComicFavorite` from the loaded
    details (`title`, `cover`, `DateTime.now()`) and calls
    `ref.read(comicFavoritesProvider.notifier).toggle(...)`.
  - tags: `_tagChip` mirrors the anime `_metaChip` visual (accent 10 % bg,
    radius 6, 12 px w600 accent text) without an icon.
  - description: 13 px, `cs.onSurface.withValues(alpha: 0.7)`, `maxLines:
    _expanded ? null : 3` with a 展开/收起 `GestureDetector` (state field
    `_expanded`, shown when the text is long enough to truncate); empty/null →
    `暂无简介`.
- **章节 section**: `GlassSurface` card with a header `Row` (`章节` 16 px w600 +
  `共 N 话` 12 px `#8E8E93`) and a `Wrap(spacing/runSpacing: 10)` of chapter
  buttons from `details.chapters.entries` — each 104×44, radius 10,
  `Color(0x0F007AFF)` fill, `Border.all(Color(0x4D007AFF))`, centered single-line
  ellipsised label = the map **value** (chapter title), 13 px w500 `#007AFF`;
  tap shows `SnackBar('阅读器开发中')`. Empty → `暂无章节`.
- **继续阅读**: a full-width `FilledButton.icon` shown when
  `ref.watch(comicHistoryProvider)` contains an entry matching
  `(sourceKey, comicId)`; tap shows the same C2a `SnackBar` placeholder.

No reader was built; no comments added.

### Part B — call-site wiring

- `comic_home.dart`: imported `comic_detail_page.dart`; `_DiscoverTab._explore`,
  `_FavoritesTab`, and `_historyRow` now push `ComicDetailPage` via
  `smoothRoute`; removed the now-unused `_showDetailPlaceholder`.
- `comic_search.dart`: imported `comic_detail_page.dart` + `smooth_route.dart`;
  result tap now pushes `ComicDetailPage` via `smoothRoute`; removed the unused
  private placeholder.
- Existing `heroTag`s on the cards are unchanged, so the Hero flies into the
  detail cover.

## Verification (exact commands + observed results)

1. `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
   → `No issues found! (ran in 1.7s)`
2. `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
   → `00:06 +136 ~1: All tests passed!` (136 passed / 1 skipped; the skip is the
   pre-existing `js_engine_smoke_test`, which cannot load the QuickJS native
   library under `flutter test`).
3. `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug`
   → `√ Built build\windows\x64\runner\Debug\acgnhub.exe` (only a pre-existing
   webview_windows CMake dev warning).

## Files changed + commit

Commit `6a9b0c9` — `feat(comic): add the comic detail page` (3 files changed,
456 insertions, 14 deletions):
- `lib/modules/comic/comic_detail_page.dart` (new)
- `lib/modules/comic/comic_home.dart`
- `lib/modules/comic/comic_search.dart`

Only the three intended files were staged. Unrelated working-tree changes
(generated plugin registrants, `.superpowers/sdd/*`) were left untouched.

## Self-review findings

- `flutter analyze` is clean, confirming no unused imports/helpers remain after
  removing both placeholders.
- The 收藏 state is derived by watching the favorites list (not a one-shot
  read), so toggling rebuilds the button.
- `comicImageProvider` is deliberately not consumed, per the brief.
- Chapter labels use the map value (title), not the key (id), matching the
  `chapters: chapterId → title` contract.
- `_historyEntry()` and `_continueReading()` both watch `comicHistoryProvider`,
  so the continue button appears/disappears reactively.

## Concerns

- The 展开/收起 toggle is shown only when the description exceeds 60 chars (a
  heuristic for "long enough to truncate at 3 lines"). Very wide/narrow layouts
  could show a toggle when the text actually fits, or omit it when a wide-glyph
  string wraps sooner; the brief did not specify the threshold.
- With no tags, the info card still reserves the 10 px gap before the
  description (minor cosmetic spacing), matching the anime card's unconditional
  spacing style.
- The chapter/continue taps are intentionally `SnackBar('阅读器开发中')`
  placeholders until the C2b reader lands.
