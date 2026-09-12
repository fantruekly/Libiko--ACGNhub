# Task 5 Report: Detail-page resource section

## What I implemented

Replaced the anime detail page's per-source 播放源 block with an aggregated 播放资源 section, applying the brief's edits verbatim to `lib/modules/anime/anime_detail_page.dart`.

- **Imports**: removed `agedm_source.dart` / `gimy_source.dart`; added `stream_resolver.dart` and `video_sources.dart` alongside the existing `video_source.dart`.
- **Top-level types**: added `_SourceStatus { loading, done, failed }` and `_SourceResult` (source, status, items, seq).
- **State fields**: removed `_sources`, `_sourceIndex`, `_videoResults`, `_videoEpisodes`, `_videoLoading`, `_videoError`, `_videoGen`, `_selectedItem`, `_retry`; added `_sourceResults`, `_searchGen`, `_searchSeq`, `_expandedItem`, `_expandedSource`, `_episodes`, `_episodesLoading`, `_episodesError`.
- **Auto-search**: `_load()` now calls `_scheduleSearch()`, which after a 300 ms delay invokes `_searchAllSources()`. That reads `videoSourcesProvider`, resets per-source result state, and fans out across all sources with a concurrency cap of 3 workers. Each `_searchOne` applies a 25 s timeout, guards with `mounted` + generation, and records done/failed plus a completion sequence.
- **Flattening**: `_flatResults` yields `(VideoItem, VideoSource)` tuples ordered by source completion sequence.
- **Expansion**: `_expandItem` toggles a card, lazily loads episodes, and supports retry; `_playEpisode` shows a modal spinner, resolves via `StreamResolver`, surfaces `无法解析播放地址` on failure, and pushes `VideoPlayerPage`.
- **UI**: `_playSection` renders a GlassSurface header (`播放资源`, live `搜索中 n/total` or `共 n 条` counter, refresh button) and the aggregated cards. `_resourceCard` renders a 52 px bar (matched title left, source-name chip right) that expands to `_episodeArea`, which shows loading / error+retry / empty / episode-button states.

Old `_playSection`, `_resultList`, `_episodeGrid`, `_searchVideos`, `_loadEpisodes`, `_playEpisode` (and all old state fields) were fully removed.

## What I verified

- `flutter analyze lib` → `No issues found! (ran in 1.5s)`
- `flutter build windows --debug` → `√ Built build\windows\x64\runner\Debug\acgnhub.exe` (14.4 s; only a pre-existing CMake CMP0175 dev warning from `webview_windows`)
- Grep confirmed no remaining references to any removed field/method (`_sources`, `_sourceIndex`, `_videoResults`, `_videoEpisodes`, `_videoLoading`, `_videoError`, `_videoGen`, `_selectedItem`, `_retry`, `_searchVideos`, `_loadEpisodes`, `_resultList`, `_episodeGrid`, `AgedmSource`, `GimySource`) outside the `video_sources.dart` import substring.

## Files changed

- `lib/modules/anime/anime_detail_page.dart` (328 insertions, 193 deletions)

## Self-review findings

- No dead code: every new method/field is referenced (`_scheduleSearch`, `_searchAllSources`, `_searchOne`, `_flatResults`, `_expandItem`, `_playEpisode`, `_playSection`, `_resourceCard`, `_episodeArea`, `_expandedSource`, `_searchSeq`, `_SourceResult.seq`).
- Removed the now-unused `Work w` usage only where appropriate; `_playSection` keeps its `(Work w, ColorScheme cs)` signature (called from `_overviewTab`).
- Concurrency, generation-guard, and mounted-guard patterns match the brief and existing conventions.
- 2-space indentation and no added comments, per project convention.

## Concerns

- If `videoSourcesProvider` throws (e.g. rule store failure), `_searchAllSources` returns silently and the section shows `正在准备播放源…` indefinitely with no retry affordance. This matches the brief's code exactly; noting it as a minor UX edge case for a future task.

## Fix report

### What changed

Fixed a review finding where the episode error UI's `重试` button called `_expandItem(item, source)` with `item` already equal to `_expandedItem`. `_expandItem` begins with `if (identical(_expandedItem, item))` and takes the toggle-**collapse** branch, so the retry cleared the error and collapsed the card instead of re-fetching episodes.

- Extracted the episode fetch into a new `_loadEpisodes(VideoItem item, VideoSource source)` method that sets `_expandedSource`, clears `_episodes`/`_episodesError`, sets `_episodesLoading = true`, awaits `source.episodes(item.detailUrl)`, and applies the existing `mounted` + `identical(_expandedItem, item)` guards on both the success and error paths.
- Rewrote `_expandItem` to: collapse (clearing `_expandedItem`, `_expandedSource`, `_episodes`, `_episodesError`, `_episodesLoading`) when the tapped item is already expanded; otherwise `setState(() => _expandedItem = item)` and `await _loadEpisodes(item, source)`.
- Changed the episode-area retry `TextButton`'s `onPressed` to call `_loadEpisodes(item, source)` instead of `_expandItem(item, source)`.
- In `_searchAllSources`, the results reset now also sets `_expandedSource = null;` alongside the existing `_expandedItem = null;`.

No other behavior changed.

### Commands run and output

`$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib`

```
Analyzing lib...
No issues found! (ran in 1.5s)
```

`$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug`

```
Building Windows application...                                    13.2s
√ Built build\windows\x64\runner\Debug\acgnhub.exe
```

(Only the pre-existing CMake CMP0175 dev warning from `webview_windows` was emitted.)

### Control-flow trace

**Retry button while expanded and in the error state:**

1. `_episodeArea` renders the error branch because `_episodesError != null`.
2. User taps `重试`; `onPressed` reads `final item = _expandedItem; final source = _expandedSource;`. Both are non-null (the card is expanded and `_loadEpisodes` previously set `_expandedSource`), so the null guard does not return.
3. `_loadEpisodes(item, source)` is called directly. It does **not** inspect `identical(_expandedItem, item)` to collapse — it unconditionally clears the error and starts loading, then calls `source.episodes(item.detailUrl)`.
4. On success, `setState` sets `_episodes = eps` and `_episodesLoading = false`; on failure, it sets `_episodesError = '获取剧集失败，请重试'`. Either way the card stays expanded and a fresh fetch reached `source.episodes(...)`.

**Tapping the card again (collapse):**

1. `_resourceCard`'s `InkWell.onTap` calls `_expandItem(item, source)`.
2. Because `identical(_expandedItem, item)` is true for the currently expanded card, `_expandItem` takes the collapse branch: it sets `_expandedItem = null`, `_expandedSource = null`, `_episodes = null`, `_episodesError = null`, `_episodesLoading = false`, and returns before any fetch.
3. `_resourceCard` recomputes `expanded = identical(_expandedItem, item)` as false, so `_episodeArea()` is not rendered — the card collapses.

The retry path and the collapse path are now distinct: retry always reaches `source.episodes(...)` while expanded, and re-tapping the card always collapses without fetching.
