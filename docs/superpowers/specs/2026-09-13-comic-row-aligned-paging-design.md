# Comic Row-Aligned Paging — Design (Sub-project C2g)

> Date: 2026-09-13
> Status: Approved (design)
> Scope: source-paged (`multiPageComicList` with `load(page)`) and cursor-paged (`loadNext`) explore sections — make every UI page a multiple of the grid's column count (6) so no page ends with a partial row, except the true last page.

## 1. Goal

A source that returns 25 comics/page (ehentai) currently renders 24 + a stray 1-comic row. Make all source/cursor sections show UI pages of 48 comics (8 rows × 6 columns) by concatenating source pages, so only the final page (when the source is exhausted) can have fewer than 6 on its last row. Client-paged sections already use 48.

## 2. Background

- Client-paged sections (`multiPartPage` / `singlePageWithMultiPart`) already client-page at 48 = 6×8.
- Server-paged sections (`type == 'multiPageComicList'` with `load(page)`) show the source's page verbatim (e.g. Komiic 20, zaimanhua 20), so the last row is partial.
- Cursor-paged sections (`usesLoadNext`) show the source's page verbatim (ehentai `eh latest` 25 → 24 + 1; `eh popular` 53 → 48 + 5).
- `ComicSourceManager.explore(source, section, {page, cursor}) → ExplorePage` already supports both. `ExplorePage` carries `maxPage` (server) or `next` (cursor).

## 3. Architecture

| File | Change |
|---|---|
| `lib/modules/comic/comic_providers.dart` | Add `comicSourcePageProvider` (one source page, chaining cursors); rewrite the server/cursor branches of `comicExploreProvider` to accumulate source pages and slice at 48. |

No engine change; no UI change. Client-paged and category-continuation behavior is unchanged.

## 4. Design

### 4.1 `comicSourcePageProvider`

```dart
final comicSourcePageProvider =
    FutureProvider.family<ExplorePage, (String, int, int)>((ref, key) async {
  final (sourceKey, section, sourceIndex) = key;
  final manager = ref.watch(comicSourceManagerProvider);
  final source = ...; // resolve sourceKey
  if (source == null) throw StateError('source $sourceKey not loaded');
  final meta = section >= 0 && section < source.sections.length
      ? source.sections[section]
      : null;
  if (meta?.usesLoadNext == true) {
    final cursor = sourceIndex <= 1
        ? null
        : (await ref.watch(
                comicSourcePageProvider((sourceKey, section, sourceIndex - 1))
                    .future))
            .next;
    return manager.explore(source, section, page: sourceIndex, cursor: cursor);
  }
  return manager.explore(source, section, page: sourceIndex);
});
```

### 4.2 `comicExploreProvider` server/cursor branch

Replace the two branches (`usesLoadNext` and `multiPageComicList`) with one accumulate-and-slice branch:

```dart
  if (sectionMeta?.usesLoadNext == true || type == 'multiPageComicList') {
    final accumulated = <Comic>[];
    var sourceIndex = 1;
    var hasMoreSource = true;
    while (accumulated.length <= page * _explorePageSize && hasMoreSource) {
      final sourcePage = await ref.watch(
          comicSourcePageProvider((sourceKey, section, sourceIndex)).future);
      accumulated.addAll(sourcePage.comics);
      if (sectionMeta?.usesLoadNext == true) {
        hasMoreSource = sourcePage.next != null;
      } else {
        hasMoreSource = sourcePage.maxPage != null
            ? sourceIndex < sourcePage.maxPage!
            : sourcePage.comics.isNotEmpty;
      }
      if (sourcePage.comics.isEmpty) break;
      sourceIndex++;
    }
    final start = (page - 1) * _explorePageSize;
    final end = (start + _explorePageSize).clamp(0, accumulated.length);
    final comics =
        start >= accumulated.length ? const <Comic>[] : accumulated.sublist(start, end);
    return ComicExplorePage(
      comics: comics,
      page: page,
      maxPage: null,
      hasNext: accumulated.length > page * _explorePageSize,
      serverPaged: true,
    );
  }
```

Key points:
- The loop fetches source pages until it has **more than** `page * 48` comics (so `hasNext` is exact) or the source is exhausted.
- Each UI page is 48 comics except the final page (the true remainder).
- `maxPage` becomes `null`, so the UI shows `第 X 页` (the source's own page total is no longer surfaced; the aligned total is unknown without fetching everything).
- Cursor sections chain through `comicSourcePageProvider` (source page N reads N-1's `next`).
- Source pages are cached by the family, so sequential navigation reuses them.

## 5. Error Handling

- A source page that throws propagates through `comicSourcePageProvider` to `comicExploreProvider`'s `AsyncError`; the UI's inline 重试 invalidates the page provider and the current family key.
- A section with no server/cursor capability (client-paged) is untouched.
- A source that returns an empty page ends the accumulation.

## 6. UI

No change. `maxPage == null` renders `第 X 页`; the pager shows while `hasNext || page > 1`.

## 7. Data flow

`comicSourcePageProvider(sourceKey, section, sourceIndex)` → source page → accumulated 1..K → `comicExploreProvider(sourceKey, section, page)` slices `[(page-1)*48, page*48)`.

## 8. Testing

- `assets/comic_source/test_source.js`: give `最近更新` (`multiPageComicList`) 25 comics/page and `maxPage: 3` (75 total); keep `游标` (`loadNext`) as the cursor case but return 25 comics/page for 3 pages.
- `.superpowers/sdd/comic_align_probe.dart`: a `ProviderContainer` probe that reads `comicExploreProvider` for the fixture's `最近更新` at pages 1–2 and asserts page 1 = 48, page 2 = 27, `hasNext` false; and for `游标` page 1 = 48, page 2 = 27.
- Probes against ehentai: pages are 48 (multiple of 6) and the last page is the remainder.
- `flutter analyze lib test`, `flutter test`, `flutter build windows --debug`.

## 9. Files

**Modified**
- `lib/modules/comic/comic_providers.dart`
- `assets/comic_source/test_source.js`

## 10. Out of Scope

- Changing the grid column count or card size.
- Surfacing the source's own page total for aligned sections (the aligned total is unknown without a full fetch).
- Deduplication across concatenated source pages (a source may repeat entries across pages).
