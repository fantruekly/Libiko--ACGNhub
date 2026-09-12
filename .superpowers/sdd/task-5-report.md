# Task 5 Report: Detail-page playback section

## Summary
Replaced the placeholder `_playSection` in `lib/modules/anime/anime_detail_page.dart` with a real playback section: source chips (AGE动漫 / gimy), search button, result list, episode grid, and resolve-then-play flow.

## Changes
- Added imports: `agedm_source.dart`, `gimy_source.dart`, `stream_resolver.dart`, `video_source.dart`, `video_player_page.dart`.
- Removed the now-unused `anime_search.dart` import (the old `_playSection` was its only consumer in this file). Required to keep analyze clean.
- Added state fields to `_AnimeDetailPageState`: `_sources`, `_sourceIndex`, `_videoResults`, `_videoEpisodes`, `_videoLoading`, `_videoError`.
- Replaced `_playSection(Work w, ColorScheme cs)` and added helper methods `_resultList`, `_episodeGrid`, `_searchVideos`, `_loadEpisodes`, `_playEpisode`, all verbatim from the brief.

## Analyze result
`flutter analyze lib` → `No issues found! (ran in 7.3s)`

## Files changed
- `lib/modules/anime/anime_detail_page.dart` (+146 / -12)

## Commit
- `82562fa` feat(anime): add playback source section to the detail page

## Concerns
- No unit test (UI + native, per brief). Verified only via `flutter analyze`.
- The brief did not mention removing the `anime_search.dart` import, but leaving it would have produced an unused-import warning and violated the `No issues found!` expectation. The file still exists and is used by `main_shell.dart`.

## Final review fixes

### Fix 1 (Critical) — guard `_loadExtras` against disposal
`lib/modules/anime/anime_detail_page.dart`: `_loadExtras` now returns early when `!mounted`, and parallelizes the character/related fetches via `Future.wait<Object>` with a second `mounted` check before `setState`.

### Fix 2 (Important) — route extras through the retry path
`lib/core/metadata/metadata_service.dart`: `characters`/`related` now wrap their Bangumi provider calls in `_withRetry(...)` instead of calling the provider directly, so transient errors are retried.

### Fix 3 (Important) — tests for the Bangumi-only gating
`test/core/metadata/metadata_service_test.dart`: added `dart:typed_data` and `bangumi_provider.dart` imports, a `_StubAdapter` HTTP adapter, and three tests covering no-`bangumiId`, non-Bangumi provider, and successful mapping of a Bangumi characters/related response.

### Fix 4 (Minor) — dedupe the scheme upgrade
`lib/core/metadata/bangumi_provider.dart`: `_cover` now reuses `_https` instead of duplicating the `http→https` logic.

### Verification output
```
$ flutter analyze lib test
Analyzing 2 items...
No issues found! (ran in 1.6s)

$ flutter test
00:05 +49: All tests passed!

$ flutter build windows --debug
√ Built build\windows\x64\runner\Debug\acgnhub.exe
```
