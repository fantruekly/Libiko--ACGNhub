# Comic Continuous Paging into Category Content — Design (Sub-project C2f)

> Date: 2026-09-13
> Status: Approved (design)
> Scope: the 发现 tab's client-paged sections — when their one-shot explore content is exhausted, keep paging by pulling the source's category listing automatically, so the user never taps a 查看更多/viewMore button.

## 1. Goal

Make the 发现 tab's sections effectively endless: page 1..N show the section's explore content (client-paged at 48/page); once exhausted, further pages are served from the source's `categoryComics` listing and appended. The user only taps 下一页 — no category/viewMore UI.

## 2. Background

- Explore sections are one of: server-paged (`multiPageComicList` with `load(page)`), cursor-paged (`loadNext`), or one-shot (`multiPartPage` / `singlePageWithMultiPart` / `mixed`). One-shot sections are currently client-paged at 48/page and end when the fixed list ends (e.g. manhuagui 78 → 2 pages, baozi 108 → 3 pages).
- Most sources also define a category browser:
  - `category = { title, parts: [{ name, type, categories: string[], categoryParams: string[], itemType }] }`.
  - `categoryComics = { load(category, param, options, page) → { comics, maxPage }, optionList: [{ options: ['value-text', ...] }] }`.
  - e.g. manhuagui's first category is `全部` with param `""`; `categoryComics.load` returns a server-paginated `{comics, maxPage}`.
- Venera's `explore[].load()` for `multiPartPage` may return parts with `viewMore`, a jump target string. jm uses `category:<title>@<id>`; manhuagui does not use `viewMore`.
- The current parser flattens parts and discards `viewMore`.

## 3. Architecture

| File | Change |
|---|---|
| `lib/core/comic/explore_result.dart` | `ExplorePage` gains `String? viewMore`; `parseExploreResult` captures the first non-null `viewMore` from parts. |
| `lib/core/comic/comic_source.dart` | `ComicSource` gains `hasCategoryComics`, `categoryDefault`, `categoryParam`, `categoryOptions`; the registry computes them; new `ComicSourceManager.category(...)`. |
| `lib/modules/comic/comic_providers.dart` | `comicExploreAllProvider` returns `ExplorePage`; `comicExploreProvider`'s client-paged branch continues into `categoryComics` after the explore pages. |
| `assets/comic_source/test_source.js` | Add a `categoryComics` + `category` to the fixture so a probe can verify continuation without network. |

The UI (`comic_home.dart`) is unchanged: it already shows `第 X 页` when `maxPage == null` and enables 下一页 on `hasNext`.

## 4. Engine

### 4.1 `ExplorePage.viewMore`

```dart
class ExplorePage {
  final List<Comic> comics;
  final int? maxPage;
  final String? next;
  final String? viewMore;
  const ExplorePage({required this.comics, this.maxPage, this.next, this.viewMore});
}
```

`parseExploreResult` records the first non-null, non-empty `viewMore` seen among `parts` entries (`part['viewMore']`) and `data` entries. (The `{title: comics}` map shape has none.)

### 4.2 Category metadata + call

`ComicSource` gains:

```dart
final bool hasCategoryComics;
final String categoryDefault;
final String categoryParam;
final List<String> categoryOptions;
```

The registry pass-2 `finish` object adds:

```js
      category: (function () {
        const c = s.category;
        const cc = s.categoryComics;
        const parts = c && Array.isArray(c.parts) ? c.parts : [];
        const part = parts.length ? parts[0] : null;
        const cats = part && Array.isArray(part.categories) ? part.categories : [];
        const params = part && Array.isArray(part.categoryParams) ? part.categoryParams : [];
        const optList = cc && Array.isArray(cc.optionList) ? cc.optionList : [];
        const options = optList.map(function (o) {
          const opts = o && Array.isArray(o.options) ? o.options : [];
          return opts.length ? String(opts[0]).split('-')[0] : '';
        });
        return {
          hasComics: !!(cc && typeof cc.load === 'function'),
          category: cats.length ? String(cats[0]) : '',
          param: params.length ? String(params[0]) : '',
          options: options
        };
      })()
```

`fromMetadata` reads it into the four fields.

`ComicSourceManager.category`:

```dart
Future<ExplorePage> category(ComicSource source, int page,
    {String? category, String? param, List<String>? options}) async {
  await _ensureInitialized();
  if (!source.hasCategoryComics) return const ExplorePage(comics: []);
  final cat = category ?? source.categoryDefault;
  final par = param ?? source.categoryParam;
  final opts = options ?? source.categoryOptions;
  final result = await _engine.evaluate('''
    (async () => {
      const s = await globalThis.__acgnhub_instance(${jsonEncode(source.key)});
      if (!s.categoryComics || typeof s.categoryComics.load !== 'function') {
        return { comics: [], maxPage: 1 };
      }
      return await s.categoryComics.load(${jsonEncode(cat)}, ${jsonEncode(par)},
        ${jsonEncode(opts)}, $page);
    })()
  ''');
  return parseExploreResult(result);
}
```

## 5. Provider

`comicExploreAllProvider` returns `ExplorePage` (the full one-shot result, including `viewMore`) instead of `List<Comic>`.

`comicExploreProvider`'s client-paged branch:

- `explorePages = max(1, ceil(comics.length / 48))`.
- `page <= explorePages` → the 48-chunk; `hasNext = source.hasCategoryComics || page < explorePages`; `maxPage = source.hasCategoryComics ? null : explorePages`.
- `page > explorePages` and `source.hasCategoryComics` → resolve the continuation target (see below), call `manager.category(source, page - explorePages, ...)`; `hasNext = result.maxPage == null ? result.comics.isNotEmpty : (page - explorePages) < result.maxPage`; `maxPage = null`.
- `page > explorePages` and no category → `{comics: [], page, maxPage: explorePages, hasNext: false}`.

Continuation target resolution: if the explore result's `viewMore` starts with `category:`, parse `category:<name>@<param>` (param optional) and pass those; otherwise pass nothing so the engine uses the source defaults.

Server-paged and cursor-paged branches are unchanged.

## 6. UI

No change. `maxPage == null` already renders `第 X 页`; the bar is shown while `hasNext || page > 1` and hidden once the category is exhausted. Source-paged category pages show their own comic count (the "limited data shows normally" rule).

## 7. Data flow

`comicExploreAllProvider(sourceKey, section)` → `ExplorePage{comics, viewMore}` → `comicExploreProvider(sourceKey, section, page)`:
- page ≤ explorePages → 48-chunk of `comics`;
- page > explorePages → `manager.category(source, page - explorePages, target)` → `ExplorePage{comics, maxPage}` → appended grid page.

## 8. Error Handling

- `categoryComics.load` throwing surfaces as the provider's error (existing inline 重试).
- A source with `categoryComics` absent → the section stays finite (no behavior change).
- An empty category page ends the paging (`hasNext = false`).

## 9. Testing

- `test/core/comic/explore_result_test.dart`: `parseExploreResult` captures `viewMore` from parts.
- `assets/comic_source/test_source.js`: give the fixture a `category` + `categoryComics.load` returning `{comics, maxPage}` (e.g. 2 pages of 3 comics), and a `viewMore: 'category:全部@'` on an explore part.
- `.superpowers/sdd/comic_continuous_probe.dart`: a `ProviderContainer` probe that reads `comicExploreProvider` for the fixture across the explore pages and into the category pages, asserting the comics change and `hasNext` eventually goes false.
- Probes against manhuagui / baozi: confirm pages continue past the explore content.
- `flutter analyze lib test`, `flutter test`, `flutter build windows --debug`.

## 10. Files

**Modified**
- `lib/core/comic/explore_result.dart`
- `lib/core/comic/comic_source.dart`
- `lib/modules/comic/comic_providers.dart`
- `assets/comic_source/test_source.js`
- `test/core/comic/explore_result_test.dart`

## 11. Out of Scope

- A category selector UI (choosing a category/param/options) — the continuation always uses the section's `viewMore` target or the source's first category.
- Merging multiple explore parts' viewMore targets; only the first non-null is used.
- Server-paged (`multiPageComicList` with `load`) and cursor-paged (`loadNext`) sections — they already page on the source.
- Deduplication across the explore and category segments (the site's listing may repeat homepage entries).
