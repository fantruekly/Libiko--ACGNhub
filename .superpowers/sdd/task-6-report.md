# Task 6 Report: Rewrite anime home to use feeds

## Status: DONE

## What was implemented
Replaced the entire contents of `lib/modules/anime/anime_home.dart` with the code specified verbatim in the task brief. The new `AnimeHomePage`:

- Watches `animeFeedProvider(_feed)` (the family provider added in Task 5) for the three pills 热门推荐 (`AnimeFeed.trending`), 本季新番 (`AnimeFeed.season`), and 今日放送 (`AnimeFeed.today`).
- Renders a hero banner for the first item, a pill selector, a section title matching the active feed label, and a 5-column `SliverGrid` of `WorkCard`s.
- Implements infinite scroll via a `ScrollController` listener that calls `MetadataService.feed(feed, page: _page + 1)` when within 400px of the bottom, appending to `_extra` and tracking `_hasMore` with `_perPage = 25`.
- Shows `ShimmerLoader` while loading, `EmptyState` with a 重试 action on error, and an empty-content `EmptyState` when a feed returns no items.
- Supports pull-to-refresh via `RefreshIndicator`, clearing `_extra` and invalidating the provider.
- Still imports `bangumi_detail_page.dart` and navigates to `BangumiDetailPage` as required at this stage (Task 8 renames it).

## Analyze command + result
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib/modules/anime/anime_home.dart
Analyzing anime_home.dart...
No issues found! (ran in 1.1s)
```

## Test command + result
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test
...
00:02 +19: All tests passed!
```
All 19 tests passed; no regressions.

## Files changed
- `lib/modules/anime/anime_home.dart` (modified; 144 insertions, 101 deletions)

## Commit
- `907249f` feat(anime): drive home from AniList/Jikan feeds

Only `lib/modules/anime/anime_home.dart` was staged for this commit. Other pre-existing working-tree modifications (`.superpowers/sdd/*`, new `docs/superpowers/*` files) were intentionally left uncommitted.

## Self-review findings
- Verified the written file byte-for-byte against the brief's code block using `Compare-Object`: zero differences, both 302 lines.
- Confirmed all consumed interfaces exist and match usage: `AnimeFeed` enum (`metadata_provider.dart:3`), `MetadataService.feed` (`metadata_service.dart:27`), `metadataServiceProvider` / `animeFeedProvider` (`anime_providers.dart:29,31`), and the `WorkCard` / `ShimmerLoader` / `EmptyState` constructors.
- Confirmed `_perPage = 25` as required.
- Confirmed `BangumiDetailPage` import retained per the task note.
- `flutter analyze` reports no issues; full test suite green.

## Concerns
None. The provider and metadata service were already in place from Task 5, so no cross-task breakage was observed.
