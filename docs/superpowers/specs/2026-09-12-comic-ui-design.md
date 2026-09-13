# Comic UI — Design (Sub-project C2)

> Date: 2026-09-12
> Status: Approved (design)
> Scope: the comic module's UI — home (source discovery + search + favorites/history), detail (chapters), reader (continuous scroll + page flip), and local favorites/history. The JS source engine (C1) is already implemented.

## 1. Goal

1. Replace the 漫画 sidebar placeholder with a real module: a home with 发现 / 收藏 / 历史 tabs, a source manager, and search.
2. A comic detail page: cover, info, chapter list, favorite toggle.
3. A reader with **continuous vertical scroll** and **horizontal page flip**, zoom, preloading and cross-chapter navigation, which records reading history.

## 2. Background

- C1 (`lib/core/comic/`) provides `ComicSourceManager` (`load`/`sources`/`importFromUrl`/`importFromFile`/`refresh`/`remove`/`search`/`explore`/`loadInfo`/`loadEp`/`onImageLoad`), the models (`Comic`/`ComicDetails`/`ComicEp`/`ImageLoadingConfig`) and `ComicSource`.
- The anime module is the UI template: `lib/modules/anime/` (`anime_home.dart` with a `TabBar`/`TabBarView` + `_FeedView`, `anime_detail_page.dart`, `video_player_page.dart`), `lib/core/widgets/` (`WorkCard`, `GlassSurface`, `EmptyState`, `ShimmerLoader`, `smooth_route`), and the local stores `FollowManager`/`WatchHistoryManager` (JSON lists in `AppDatabase`).
- `WorkType.comic` already exists in the model layer, but the comic module has no code.
- `main_shell.dart` holds the sidebar/title-bar shell; its `_pages[1]` is the 漫画 placeholder to replace.

## 3. Architecture

New package folder `lib/modules/comic/` (UI) plus a small `lib/core/comic/` addition (stores + image provider):

| File | Responsibility |
|---|---|
| `lib/core/comic/comic_favorite.dart` | `ComicFavorite` model + `ComicFavoriteManager` (local, `AppDatabase` key `comic_favorites`) + `comicFavoritesProvider` |
| `lib/core/comic/comic_history.dart` | `ComicHistoryEntry` model (sourceKey, comicId, title, cover, chapterId, chapterTitle, page, readAt) + `ComicHistoryManager` (`comic_history`) + `comicHistoryProvider` |
| `lib/core/comic/comic_image.dart` | `ComicImageProvider` — resolves a page URL through `ComicSourceManager.onImageLoad` and returns a `CachedNetworkImageProvider`-compatible provider carrying the per-image headers |
| `lib/modules/comic/comic_providers.dart` | Riverpod providers: `comicSourceManagerProvider`, `comicSourcesProvider` (the loaded list), `comicExploreProvider(family: sourceKey)`, `comicSearchProvider(family: keyword)`, `comicDetailProvider(family: (sourceKey, comicId))`, `comicEpProvider(family: (sourceKey, comicId, chapterId))`, `comicReaderSettingsProvider` (the persisted reader mode + page direction, in `AppDatabase` key `comic_reader_settings`) |
| `lib/modules/comic/comic_home.dart` | The 漫画 home: `DefaultTabController(length: 3)` with 发现 / 收藏 / 历史 |
| `lib/modules/comic/comic_source_page.dart` | Source management: list loaded sources, import by URL, import by file, refresh, remove, and the remote-list URL setting |
| `lib/modules/comic/comic_search.dart` | Search across the enabled sources (a results grid) |
| `lib/modules/comic/comic_detail_page.dart` | Comic detail: cover + info + favorite toggle + chapter list |
| `lib/modules/comic/comic_reader_page.dart` | The reader (continuous + page flip) |

`main_shell.dart`'s 漫画 entry becomes `ComicHomePage`, and its title-bar search icon (currently anime-only) is wired for the comic tab to open `ComicSearchPage`.

## 4. Home (`comic_home.dart`)

`TabBar` styling matches the anime home (`#007AFF` selected, `#8E8E93` unselected, `#E5E5EA` divider).

- **发现**: a source selector (a `Wrap` of source chips, or a dropdown when there are many) over a scrollable list of that source's `explore` sections. Each section = a title + a horizontally scrolling row of `WorkCard`-style comic cards (cover + title). Tapping a card opens the detail page. A trailing 源管理 icon button opens `ComicSourcePage`. An `EmptyState` (`还没有添加漫画源，点击右上角添加`) when there are no sources.
- **收藏**: the local favorites as a grid (the same 6-column grid as the anime home), each card tapping into the detail page; an `EmptyState` when empty.
- **历史**: the local history as a list (cover + title + `看到 <chapter> · <n>%` + time), tapping resumes the reader at the recorded chapter; a 清空历史 action with a confirm dialog.

The explore/collection loading states reuse `ShimmerLoader`; failures show an inline retry.

## 5. Source management (`comic_source_page.dart`)

A `Scaffold` page:
- A list of the loaded sources: name, key, version, capability chips (搜索/发现/详情/章节), a 刷新 button (when `url` is set) and a 删除 button (with a confirm dialog).
- An 添加源 action offering **从 URL 导入** (a text field) and **从文件导入** (`file_selector`, `.js`), both surfacing `FormatException`/network errors inline.
- A 远程规则列表 section: a `TextField` for `comic_source_list_url` (persisted in `AppDatabase`), a 获取列表 button that fetches the JSON (`[{name, key, url|fileName, version, description}]`) and lists the entries with an 添加 button per entry.

## 6. Detail (`comic_detail_page.dart`)

- Header: back + title + the window controls (the same pattern as the anime detail page).
- Info card: the cover (Hero tag `comic_<sourceKey>_<comicId>`), the title/subtitle, tags, description (expandable), and a 收藏 button (a labelled button, like the anime 追番 button: `收藏` accent-filled → `已收藏` dimmed).
- Chapter list: `ComicDetails.chapters` (a `Map<String,String>`), rendered as a grid of small buttons (like the anime episode buttons) or a compact list when there are many; tapping opens the reader at that chapter.
- A 继续阅读 button when the history has an entry for this comic.

## 7. Reader (`comic_reader_page.dart`)

`ComicReaderPage({sourceKey, comicId, chapterId, initialPage})`.

- Loads `loadEp(sourceKey, comicId, chapterId)` → `List<String> images`, then resolves each through `onImageLoad` for per-image headers.
- **Modes** (`ComicReaderMode`): `continuousVertical` (a `ListView` of images, the default) and `pageHorizontal` (a `PageView` of single pages, left-to-right; a right-to-left toggle is out of scope for C2).
- Zoom: `InteractiveViewer` per page (min 1.0, max 4.0), double-tap to toggle 1.0/2.5.
- **Preload**: precache the next 3 images ahead of the current page within the chapter, plus the first image of the next chapter (and the last image of the previous chapter when the current page is near the start).
- **Cross-chapter**: scrolling past the last page (continuous) or swiping past the last page (flip) loads the next chapter and continues; the first page backwards loads the previous chapter. The reader reads the chapter list from the detail data so it can compute the neighbours.
- **Chrome**: an auto-hiding top bar (back, title, chapter title) and bottom bar (a chapter list button, the mode toggle, a page indicator); tapping the centre toggles the chrome.
- **History**: on chapter change and on page change (throttled to ~1 s) write a `ComicHistoryEntry` with the current chapter + page.
- **Errors**: an image that fails shows a retry placeholder; a chapter that fails to load shows an inline error + retry.

## 8. Data flow

`comicSourcesProvider` → (发现) `comicExploreProvider(sourceKey)` → `Comic` list → `comicDetailProvider` → `ComicDetails` → `comicEpProvider` → images → `ComicImageProvider` (per-image headers) → the reader. Favorites/history are local providers backed by `AppDatabase`.

## 9. Error Handling

- No sources → the 发现 tab's empty state points at 源管理.
- A source's `explore`/`search`/`loadInfo`/`loadEp` throwing → the provider surfaces an error the UI shows with a 重试 action (never an unhandled exception).
- An image failure → a retry placeholder in the reader.
- A history/favorite entry whose source no longer exists → skipped when resolving, and removed on the next load.
- Reader history writes are fire-and-forget and must not block paging.

## 10. Testing

- Pure-Dart units under `flutter test`: `ComicFavoriteManager`/`ComicHistoryManager` (upsert/dedupe/ordering/clear, JSON round-trip) and the reader's chapter-neighbour + page-index maths.
- Widget tests are not added for the reader; the reader, the home and the detail page are verified in-app (and, where the engine is involved, with an app-level probe).
- Re-run `flutter analyze lib test`, `flutter test`, `flutter build windows --debug`.

## 11. Files

**New**
- `lib/core/comic/comic_favorite.dart`
- `lib/core/comic/comic_history.dart`
- `lib/core/comic/comic_image.dart`
- `lib/modules/comic/comic_providers.dart`
- `lib/modules/comic/comic_home.dart`
- `lib/modules/comic/comic_source_page.dart`
- `lib/modules/comic/comic_search.dart`
- `lib/modules/comic/comic_detail_page.dart`
- `lib/modules/comic/comic_reader_page.dart`
- `test/core/comic/comic_favorite_test.dart`
- `test/core/comic/comic_history_test.dart`

**Modified**
- `lib/shell/main_shell.dart` (replace the 漫画 placeholder; wire the search icon for the comic tab)

## 12. Out of Scope

- Downloading/offline chapters; danmaku; comments; `account`/WebView login; network favorites; `category`/`translation`; a source-settings UI beyond the remote-list URL.
- Right-to-left page flip, webtoon gap trimming, page double-spread rules.
- Syncing comic favorites/history with the B1 backend (the account sync covers anime follows/history only).
- AES-requiring sources (C1's documented limit).
