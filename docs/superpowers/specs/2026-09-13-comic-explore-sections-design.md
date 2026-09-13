# Comic Explore Sections + Pagination — Design (Sub-project C2c)

> Date: 2026-09-13
> Status: Approved (design)
> Scope: the 发现 (explore) tab only — a per-source section selector and pagination. New comic sources (哔咔 / 禁漫 / ehentai) and their compatibility needs (AES, login, `loadNext` cursor UI) are a separate sub-project (C2d).

## 1. Goal

Make the 发现 tab show, for the selected source, a selectable list of its explore sections (e.g. e-hentai's 最近更新 / 本月排行) and page through the results — a fixed number of comics per page, with 上一页 / 下一页 navigation.

## 2. Background

- C1's `ComicSourceManager.explore(source, index, {page})` currently only ever evaluates `s.explore[0].load(page)` and flattens the result into `List<Comic>`; `maxPage` and section metadata are discarded. The C2a UI hard-codes section 0 and one page.
- Real Venera sources declare `explore = [{ title, type, load(page) }]` (some use `loadNext(next)`), with types:
  - `multiPageComicList` — `load(page)` (1-based) returns `{ comics, maxPage }`; server-paginated.
  - `multiPartPage` — `load(page)` returns `[{ title, comics, viewMore? }]`; the source may ignore `page` (manhuagui) or always fetch page 0 (jm).
  - `singlePageWithMultiPart` — `load()` returns `{ <section title>: Comic[] , ... }` (a map of parts); one-shot.
  - `mixed` — `load(index)` (0-based) returns `{ data: [Comic[] | {title, comics}], maxPage? }`; complex.
- Currently imported sources and their sections: copy_manga / manwaba / comick / ikmmh / shonen_jump_plus / baozi = `singlePageWithMultiPart` (1 section); Komiic / zaimanhua = `multiPageComicList` (1 section); manga_dex / manhuagui / ykmh = `multiPartPage` (1 section). None currently has more than one section, so the section selector will be hidden for them; it becomes visible once C2d imports ehentai (2) / picacg (5).
- Engine limitation: `flutter_qjs` (native QuickJS) cannot run under `flutter test`, so engine behaviour is verified with app-level probes (`.superpowers/sdd/*_probe.dart`) plus `flutter build windows --debug`.

## 3. Architecture

Two small additions and three modifications:

| File | Change |
|---|---|
| `lib/core/comic/explore_result.dart` (new) | `class ExplorePage { List<Comic> comics; int? maxPage; String? next; }` and the pure parser `ExplorePage parseExploreResult(dynamic raw)` normalising the four Venera shapes. Unit-tested. |
| `lib/core/comic/comic_source.dart` (modify) | `ComicSource` gains `List<ComicSourceSection> sections`; metadata pass reads section titles/types; `explore(source, sectionIndex, {page, cursor})` returns `ExplorePage`. |
| `lib/modules/comic/comic_providers.dart` (modify) | `comicExploreProvider` becomes a `FutureProvider.family<ComicExplorePage, (String sourceKey, int section, int page)>` that applies the server/client pagination rule. |
| `lib/modules/comic/comic_home.dart` (modify) | `_DiscoverTab`: section chips row + paginated grid + pagination bar. |
| `assets/comic_source/test_source.js` (modify) | Add two explore sections (one `multiPageComicList`, one `singlePageWithMultiPart`) so the probe/e2e can exercise the selector and both pagination modes. |

## 4. Engine changes

### 4.1 `ComicSourceSection`

```dart
class ComicSourceSection {
  final String title;
  final String type;
  const ComicSourceSection({required this.title, required this.type});
}
```

`ComicSource` gains `final List<ComicSourceSection> sections;` (default `const []`). `fromMetadata` reads `meta['sections']` (a JS array of `{title, type}`).

The pass-2 registry IIFE (`_registryJs.__acgnhub_registerSource`) additionally returns:

```js
sections: (s.explore || []).map(function (e) {
  return { title: e.title || '', type: e.type || '' };
})
```

### 4.2 `ExplorePage` + parser

`lib/core/comic/explore_result.dart`:

```dart
class ExplorePage {
  final List<Comic> comics;
  final int? maxPage;   // present for server-paginated sections
  final String? next;   // cursor for loadNext-based sections
  const ExplorePage({required this.comics, this.maxPage, this.next});
}

ExplorePage parseExploreResult(dynamic raw);
```

`parseExploreResult` flattens, in order:
- a `Map` with `comics: List` → those comics;
- a `Map` with `parts: List` → each part's `comics`;
- a `List` of `{ title, comics }` parts (`multiPartPage`);
- a `Map` whose values are `List`s (`singlePageWithMultiPart`), flattening each value;
and reads `maxPage` (int) and `next` (String) when present. `Comic.fromJs` maps each entry.

### 4.3 `ComicSourceManager.explore`

```dart
Future<ExplorePage> explore(
  ComicSource source,
  int sectionIndex, {
  int page = 1,
  String? cursor,
});
```

Evaluates:

```js
(async () => {
  const s = await globalThis.__acgnhub_instance(<key>);
  const sec = (s.explore || [])[<index>];
  if (!sec) return { comics: [], maxPage: 1 };
  if (typeof sec.load === 'function') return await sec.load(<page>);
  if (typeof sec.loadNext === 'function') return await sec.loadNext(<cursor?>);
  return { comics: [], maxPage: 1 };
})()
```

and returns `parseExploreResult(result)`. The existing `_comicsFrom` is replaced by `parseExploreResult(...).comics` for `search` too (search results use the `{comics, maxPage}` shape).

## 5. Provider changes

```dart
class ComicExplorePage {
  final List<Comic> comics;
  final int page;        // 1-based
  final int maxPage;     // >= 1
  final bool serverPaged;
  const ComicExplorePage({required this.comics, required this.page,
      required this.maxPage, required this.serverPaged});
}

final comicExploreProvider = FutureProvider.family<ComicExplorePage,
    (String sourceKey, int section, int page)>((ref, key) async { ... });
```

Rule:
- If the section's `type == 'multiPageComicList'` → server-paginated: call `manager.explore(source, section, page: page)`, `maxPage = result.maxPage ?? page`, `serverPaged = true`.
- Otherwise → one-shot: for `page == 1`, call `manager.explore(source, section, page: 1)`; for `page > 1`, `ref.watch(comicExploreProvider((sourceKey, section, 1)).future)` to reuse the cached full list. Slice with `pageSize = 30`: `maxPage = max(1, ceil(total/30))`, `comics = all.sublist(start, end)`.
- A missing/empty section list returns an empty page with `maxPage = 1`.

## 6. UI changes (`_DiscoverTab`)

Layout, top to bottom:
1. Source chips row (existing) + 源管理 button.
2. Section chips row — only rendered when the selected source has **more than one** section. Horizontally scrollable `ChoiceChip`s styled like the source chips (accent `#007AFF` when selected). Empty titles fall back to `分区 <n>`. Selecting a chip resets `_page = 1`.
3. The grid (`Expanded`) for the current page's comics, using the existing `_comicGrid` constants (6 columns, aspect 0.60, `fromLTRB(16, 8, 16, 24)`).
4. A pagination bar at the bottom, rendered only when `maxPage > 1`: a `上一页` `IconButton` (disabled on page 1), a `第 X / Y 页` label, and a `下一页` `IconButton` (disabled on the last page). Page changes call `setState`.

State held by `_DiscoverTabState`: `_selectedKey` (existing), `_selectedSection` (int, default 0), `_page` (int, default 1). Changing the source resets `_selectedSection = 0` and `_page = 1`.

Loading/error/empty states reuse `ShimmerLoader` / `EmptyState` (inline retry invalidates `comicExploreProvider((sourceKey, section, page))`).

## 7. Data flow

`comicSourcesProvider` → source → `source.sections` (chips) → `comicExploreProvider((sourceKey, section, page))` → `ComicSourceManager.explore` → `parseExploreResult` → `ComicExplorePage` → grid + pagination bar.

## 8. Error Handling

- A section whose `load`/`loadNext` throws → the provider surfaces the error; the UI shows the inline `EmptyState` + 重试 (invalidate the current family key).
- An unknown/empty section → an empty page (`暂无内容`), never an unhandled exception.
- A page beyond `maxPage` (e.g. after a source change) is clamped by the UI's disabled buttons; the provider clamps the slice.

## 9. Testing

- `test/core/comic/explore_result_test.dart`: `parseExploreResult` for `{comics, maxPage}`, `[{title, comics}]`, `{title: comics}` map, a bare `List`, and empty/null input.
- `assets/comic_source/test_source.js`: add `explore` with two sections — `最近更新` (`multiPageComicList`, `{comics, maxPage: 3}`) and `分类` (`singlePageWithMultiPart`, a `{title: comics}` map) — so the probe can exercise the selector and both pagination modes without network.
- `.superpowers/sdd/comic_explore_probe.dart`: extend to iterate every section and the first two pages, printing counts; run against copy_manga / manhuagui / Komiic / zaimanhua.
- `flutter analyze lib test`, `flutter test`, `flutter build windows --debug`.

## 10. Files

**New**
- `lib/core/comic/explore_result.dart`
- `test/core/comic/explore_result_test.dart`

**Modified**
- `lib/core/comic/comic_source.dart`
- `lib/modules/comic/comic_providers.dart`
- `lib/modules/comic/comic_home.dart`
- `assets/comic_source/test_source.js`

## 11. Out of Scope

- New sources (哔咔 / 禁漫 / ehentai) and their compatibility needs: AES-ECB (`decryptAesEcb`), account/WebView login, and the `loadNext` cursor UI (the engine supports `loadNext` here, but no current source uses it).
- The `mixed` section type (nhentai) — treated as one-shot for now.
- A per-section "view more" / infinite scroll; download; the reader (C2b, done).
