# Rule-based Playback Sources — Design

> Date: 2026-09-12
> Status: Approved (design)
> Scope: Rule-based video sources + the detail-page resource section. Metadata is a separate spec.

## 1. Goal

Add **rule sources** so users can watch from more sites, and make the detail page auto-discover resources:

1. **Rule source engine**: Kazumi-compatible JSON rules (XPath) plus a headless WebView that renders the page and extracts data. Bundle a few rules and let users import Kazumi plugin JSON.
2. **Detail-page resource section** (bottom of 概览): on entering the page, search all sources in parallel; each result is a **long bar card** (left: matched title, right: source name); tapping a card expands that item's **episodes as small buttons**; tapping an episode plays it.

## 2. Background / Constraints

- The existing `VideoSource` implementations (`agedm`, `gimy`) use HTTP GET + `package:html` parsing.
- Most reachable Chinese anime sites are **JS-rendered** (search/episodes are loaded by JS), so HTTP + HTML parsing fails. Verified from this machine:
  - `agedm.io`, `gimy.tv`: HTTP-parseable (current sources work).
  - `libvio.me`, `girigiri.love`, `dm233.tv`, `omofun.link`, `mgnacg.com`: JS shells (search URLs 404 or return no rows over plain HTTP).
  - `dmbus.cc`: origin down (HTTP 522).
  - `7sefun.top`: search page is server-rendered (a rule can fetch it).
- Kazumi's sources are JSON rules with XPath and `useWebview: true`: it renders the page in a WebView and evaluates XPath **inside the page**. This is the approach adopted here.
- The `webview_windows` fork (Predidit) provides `HeadlessWebview` with `run()`, `loadUrl()`, `setUserAgent()`, `executeScript()` (result is JSON-decoded), and a `loadingState` stream (`none` / `loading` / `navigationCompleted`). Confirmed from the package source.
- All site HTTP requests need a browser `User-Agent`.

## 3. Architecture

New files in `lib/core/video/`:

| File | Responsibility |
|---|---|
| `source_rule.dart` | `SourceRule` model + `fromJson` (Kazumi-compatible fields) |
| `webview_scraper.dart` | Generic fetch: load a URL in a headless WebView, wait for navigation, run an extraction script, return JSON. Polls/retries for SPA content. |
| `rule_source.dart` | `RuleVideoSource implements VideoSource` — `search` / `episodes` via `SourceRule` + `WebviewScraper` |
| `rule_store.dart` | Loads built-in rules from `assets/rules/*.json` and user-imported rules from the app data dir; saves imports |
| `video_sources.dart` | Source registry: `allSources()` = hand-written sources + rule sources; Riverpod provider |

Bundled rules live in `assets/source_rules/*.json` (a new asset dir, declared in `pubspec.yaml`). The existing `assets/rules/*.json` belongs to the legacy `AnimeRule` scaffolding and is a **different format** — it must not be read by the rule store.

Reused: `VideoSource` / `VideoItem` / `VideoEpisode` (`video_source.dart`), `StreamResolver` (`stream_resolver.dart`).

## 4. Rule Format (Kazumi-compatible)

A rule is a JSON object. Recognized fields:

| Field | Required | Meaning |
|---|---|---|
| `name` | yes | Source display name |
| `baseURL` | yes | Base used to resolve relative URLs |
| `searchURL` | yes | Search URL; `@keyword` is replaced with the URL-encoded keyword |
| `searchList` | yes | XPath; one node per result row |
| `searchName` | yes | XPath evaluated within a row; its text is the title |
| `searchResult` | yes | XPath evaluated within a row; the first node's `href` is the detail URL |
| `chapterRoads` | yes | XPath; the episode-road containers |
| `chapterResult` | yes | XPath evaluated within a road; the episode links |
| `userAgent` | no | Overrides the default browser UA |

Unknown keys (`api`, `type`, `version`, `muliSources`, `useWebview`, `useNativePlayer`, `adBlocker`, …) are ignored — accepted so Kazumi plugin JSON imports cleanly.

Only the **first** road is used (matching the existing sources).

Example (`assets/source_rules/7sefun.json`):

```json
{
  "name": "七色番",
  "baseURL": "https://www.7sefun.top/",
  "searchURL": "https://www.7sefun.top/vodsearch/-------------.html?wd=@keyword",
  "searchList": "//div[2]/div[2]/div[2]/div[2]/div",
  "searchName": "//div[2]/text()",
  "searchResult": "//a",
  "chapterRoads": "//div[2]/div[2]/div[2]/div/div[2]/div[1]//div",
  "chapterResult": "//a"
}
```

`fromJson` throws `FormatException` if a required field is missing or not a string.

## 5. WebView Scraper

```dart
class WebviewScraper {
  static const defaultUserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  Future<dynamic> fetchJson({
    required String url,
    required String script,
    String? userAgent,
    Duration timeout = const Duration(seconds: 20),
    int attempts = 3,
  });
}
```

Behavior:

1. Create a `HeadlessWebview`; `run()`; `setUserAgent(userAgent ?? defaultUserAgent)`; `setPopupWindowPolicy(deny)`.
2. `loadUrl(url)`; wait until `loadingState == navigationCompleted` (or `timeout` → return `null`).
3. `executeScript(script)`. If the result is an empty list, wait ~600 ms and retry, up to `attempts` times (SPA content often renders after navigation completes).
4. Return the JSON-decoded result, or `null` on timeout/failure.
5. Always `dispose()` the webview in `finally`.

The extraction script is generated in Dart (pure functions, unit-testable). It uses `document.evaluate` and returns `JSON.stringify(...)`:

- `buildSearchScript(rule)` → for each node in `searchList`:
  `{ "name": text(searchName, row), "href": attr(searchResult, row, "href") }`.
- `buildEpisodesScript(rule)` → first node in `chapterRoads`, then for each link in `chapterResult`:
  `{ "title": text(chapterResult, road), "href": attr(chapterResult, road, "href") }`.

`RuleVideoSource` resolves each `href` against `baseURL` and upgrades `http://` → `https://` (same normalization as the existing sources). Rows with an empty title or href are dropped. `VideoItem.id` = the detail path; `VideoEpisode.index` = 0-based order; `VideoEpisode.playUrl` = the resolved episode URL.

## 6. Rule Store & Import

- **Built-in rules**: `rootBundle.loadString('assets/source_rules/<name>.json')` for each bundled file; parsed once and cached.
- **Imported rules**: stored as `<app support dir>/rules/<name>.json` via `path_provider`; loaded on startup and merged with built-ins (dedupe by `name`, imported wins).
- **Import flow**: a "导入规则" button in the resource section header opens a file picker (`file_selector`) filtered to `.json`; parse + validate (`SourceRule.fromJson`); on success write to the rules dir and refresh the registry; on failure show an error snackbar and do not write.
- `ruleStoreProvider` exposes `Future<List<SourceRule>> rules()`; `videoSourcesProvider` builds `allSources()` = `[AgedmSource(), GimySource(), ...ruleSources]`.

New dependency: `file_selector: ^1.0.3` (Flutter-team plugin, supports Windows).

## 7. Detail-page Resource Section

Replaces the current 播放源 block (`_playSection` / `_resultList` / `_episodeGrid`) in `lib/modules/anime/anime_detail_page.dart`.

State (in `_AnimeDetailPageState`):

```dart
class SourceSearchState {
  final VideoSource source;
  final SourceSearchStatus status; // pending, loading, done, failed
  final List<VideoItem> items;
}
```

Flow:

- After `_load()` completes, schedule `_searchAllSources(_work.title)` (300 ms delay).
- `_searchAllSources`: for every source in `allSources()`, run `source.search(title)` through a **concurrency limiter (max 3)**; each source's state updates independently as it finishes (`done` with items, or `failed`).
- Results append to the list in arrival order. Each result row carries its `VideoSource`.

UI (all inside the existing 概览 tab, at the bottom):

- Header: title `播放资源`; right side shows `搜索中 n/m` while pending, else `共 N 条`; a refresh icon re-runs the search; an `导入规则` button.
- Result cards: long bar cards (~52 px high, radius 12, 1 px border `#E5E5EA`, white surface):
  - left: matched title (single line, ellipsis), 14 px, `#1C1C1E`;
  - right: source name in a small accent-tinted pill (12 px, `#007AFF` on `#007AFF` 8 %);
  - tap toggles expansion of that card (only one expanded at a time).
- Expanded: the item's episodes as small buttons — `Wrap(spacing: 10, runSpacing: 10)`, each 104×44, radius 10, `#007AFF` 6 % fill, 30 % border, label = episode title. Loaded lazily on first expand (`source.episodes(detailUrl)`); a small spinner while loading; an inline error + retry on failure.
- Episode tap: `StreamResolver().resolve(ep.playUrl)` (existing loading dialog) → push `VideoPlayerPage(title, episodes, initialIndex)`; on `null` show a snackbar `无法解析播放地址`.
- Footer: if any sources returned no results or failed, a muted line `N 个源无结果或失败（A、B、C）`.
- If every source fails or returns nothing: the existing `EmptyState` with a 重试 action.

## 8. Error Handling

- Each source is independent: one failure/timeout never blocks the others; the UI marks that source as failed.
- Scraper timeout: 20 s per page, 3 attempts for empty SPA results.
- Invalid imported JSON: error snackbar, nothing written.
- `StreamResolver` failure: snackbar `无法解析播放地址`.

## 9. Testing

- `test/core/video/source_rule_test.dart`: `SourceRule.fromJson` — valid Kazumi JSON (including unknown keys) parses; missing/invalid required fields throw `FormatException`.
- `test/core/video/xpath_js_test.dart`: `buildSearchScript` / `buildEpisodesScript` contain the rule's XPath and produce valid JS (pure string checks).
- `WebviewScraper`, `RuleVideoSource`, and the resource section are **integration/manual**: a headless WebView and native video cannot run in `flutter test`. Each bundled rule is verified in-app (search + episodes + playback) and removed or fixed if broken; the manual check is recorded in the report.
- Re-run `flutter analyze lib test`, `flutter test`, `flutter build windows --debug`.

## 10. Files

**New**

- `lib/core/video/source_rule.dart`
- `lib/core/video/webview_scraper.dart`
- `lib/core/video/rule_source.dart`
- `lib/core/video/rule_store.dart`
- `lib/core/video/video_sources.dart`
- `assets/source_rules/7sefun.json` (plus any other verified rules)
- `test/core/video/source_rule_test.dart`
- `test/core/video/xpath_js_test.dart`

**Modified**

- `lib/modules/anime/anime_detail_page.dart` (resource section)
- `pubspec.yaml` (`file_selector`; declare the `assets/source_rules/` asset dir)

## 11. Out of Scope

- An online rule repository / one-click source subscriptions.
- Migrating `agedm` / `gimy` to rules (they stay hand-written HTTP sources — faster).
- Danmaku, subtitles, downloads, casting.
- Multiple play roads per source (only the first road is used).
- Removing the legacy `AnimeRule` / `assets/rules/` scaffolding (dead code — left in place).
