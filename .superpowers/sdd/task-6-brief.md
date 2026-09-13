### Task 6: Comic detail page

**Files:**
- Create: `lib/modules/comic/comic_detail_page.dart`

**Interfaces:**
- Consumes: `comicDetailProvider` (Task 3), `comicFavoritesProvider` (Task 1), `comicHistoryProvider` (Task 2), `ComicImageProvider` (Task 3), `WindowControls`/`smooth_route`.
- Produces: `class ComicDetailPage extends ConsumerStatefulWidget { final String sourceKey; final String comicId; final String title; final String? cover; }`.

- [ ] **Step 1: Create `lib/modules/comic/comic_detail_page.dart`**

Structure (mirror `lib/modules/anime/anime_detail_page.dart`'s layout):
- `_header`: `DragToMoveArea` + a 48 px `Container` with a back button, the title (`Expanded`), and `const WindowControls()`.
- Body: `CustomScrollView` with:
  - an info card (a `GlassSurface(blur: 0)` like the anime info card): a `Row` of the cover (`Hero(tag: 'comic_${sourceKey}_$comicId')`, 110×154, `ClipRRect(10)`, `memCacheWidth: 300`) and, 24 px to its right, a `Column` of: the title (20 px w600, max 2 lines), a 14 px gap, the 收藏 button (a `FilledButton.icon`, `收藏` accent-filled + `Icons.bookmark_add_outlined` → `已收藏` dimmed `#E5E5EA`/`#8E8E93` + `Icons.bookmark_added_rounded`, 36 px high, radius 10), a 14 px gap, then the tags `Wrap` (the anime `_metaChip` styling) and the description (13 px, muted, max 3 lines + a 展开/收起 toggle);
  - a 章节 section: a header `Row` (章节 + a count) and a `Wrap` of chapter buttons — each 104×44, radius 10, accent 6 % fill + 30 % border, label = the chapter title (single line ellipsis) — built from `details.chapters`; tapping shows `SnackBar('阅读器开发中')` for C2a (C2b replaces this with `ComicReaderPage`);
  - a 继续阅读 button when `comicHistoryProvider` has an entry for this comic (also a C2a placeholder `SnackBar`).
- Loading: `ShimmerLoader`; error: an `EmptyState` with a 重试 action calling `ref.invalidate(comicDetailProvider((sourceKey, comicId)))`.
- The 收藏 button builds a `ComicFavorite` from the loaded details (`sourceKey`, `comicId`, title, cover, `DateTime.now()`) and calls `ref.read(comicFavoritesProvider.notifier).toggle(...)`.

- [ ] **Step 2: Analyze, test, build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → all pass.
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug` → built.

- [ ] **Step 3: Commit**

```bash
git add lib/modules/comic/comic_detail_page.dart
git commit -m "feat(comic): add the comic detail page"
```

---
