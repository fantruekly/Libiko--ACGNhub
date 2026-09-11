### Task 10 Report: Create first built-in anime rule

**Status:** Complete

**Files created:**
- `assets/rules/yhdm.json` — 樱花动漫 source rule with search, detail, and video extraction XPaths

**Commits:**
- `df705d2` feat(anime): add built-in anime source rule

## Final review fixes

Applied all four code-review fixes to the anime metadata feature:

1. **Pull-to-refresh cache bypass** — added `MetadataService.invalidate(prefix)` which removes cache entries by key prefix; `AnimeHomePage` `onRefresh` now calls `invalidate('feed:${_feed.name}:')` before invalidating the provider.
2. **AniList `today` pagination** — the `AnimeFeed.today` GraphQL query now takes `$page`/`$perPage` variables and passes the requested `page` instead of hardcoding `perPage`.
3. **Stale `_loadMore` race** — added a `_generation` counter incremented in `_selectFeed` and `onRefresh`; `_loadMore` captures the generation/feed and discards results if the generation changed.
4. **Jikan single-flight serialization** — added a `_jikanChain` future so Jikan calls run one at a time (no overlap), used by `_run` when the provider is Jikan.

**Files changed:**
- `lib/core/metadata/metadata_service.dart`
- `lib/core/metadata/anilist_provider.dart`
- `lib/modules/anime/anime_home.dart`
- `test/core/metadata/metadata_service_test.dart`

**Test command and output:**
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/metadata/
...
00:00 +7: All tests passed!
```

**Analyze command and output:**
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib
Analyzing lib...
No issues found! (ran in 1.4s)
```