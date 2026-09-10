# Task 8 Report: Rename and rewrite the detail page

## Summary
Implemented exactly per the brief. Created `lib/modules/anime/anime_detail_page.dart`
with `class AnimeDetailPage extends ConsumerStatefulWidget`, deleted the old
`bangumi_detail_page.dart`, and updated `anime_home.dart` / `anime_search.dart` to
import and use `AnimeDetailPage`. The new page enriches the passed `Work` via
`metadataServiceProvider.detail(work)` on init, shows a banner/cover hero with gradient,
cover + meta chips (score/episodes/seasonYear), tags wrap, expandable summary, a
详细信息 card, and a bottom CTA to AniList or MyAnimeList depending on `anilistId`/`malId`.

## Deviations from brief (required to compile / keep analyze clean)
The brief's "verbatim" code produced 1 error and 1 warning under `flutter analyze lib`:

1. **Error** `not_initialized_non_nullable_instance_field` at
   `anime_detail_page.dart:18` — `Work _work;` is non-nullable and assigned in
   `initState`, which the analyzer does not treat as initialization.
   **Fix:** changed to `late Work _work;` (minimal, behavior-preserving).
2. **Warning** `unused_import` for `import 'anime_search.dart';` — the verbatim code
   never references `AnimeSearchPage`.
   **Fix:** removed the unused import.

No other changes; all logic matches the brief.

## Verification
Command (workdir `D:\ACGNhub`):

```
$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib
```

Result (final):

```
Analyzing lib...
No issues found! (ran in 1.2s)
```

The first run before the two fixes reported:
- `warning - Unused import: 'anime_search.dart' ... unused_import`
- `error - Non-nullable instance field '_work' must be initialized ... not_initialized_non_nullable_instance_field`

## Files changed
- Added: `lib/modules/anime/anime_detail_page.dart`
- Deleted: `lib/modules/anime/bangumi_detail_page.dart`
- Modified: `lib/modules/anime/anime_home.dart` (import + 3 × `BangumiDetailPage(` → `AnimeDetailPage(`)
- Modified: `lib/modules/anime/anime_search.dart` (import + 1 × `BangumiDetailPage(` → `AnimeDetailPage(`)

Git rename detection recorded it as
`lib/modules/anime/{bangumi_detail_page.dart => anime_detail_page.dart}` (69% similarity).

## Commit
- `0075ea3` feat(anime): rename detail page and drive it from metadata service
  - 3 files changed, 83 insertions(+), 73 deletions(-)

## Self-review
- Confirmed no remaining `BangumiDetailPage` / `bangumi_detail_page` references under
  `lib/` (grep clean). Remaining matches are only in `docs/` planning artifacts, out of scope.
- `metadataServiceProvider` is defined in `anime_providers.dart` and is a
  `Provider<MetadataService>`; `MetadataService.detail(Work)` returns `Future<Work>` — matches usage.
- `Work.anilistId`, `Work.malId`, `Work.bannerUrl` getters exist in `core/models/work.dart`.
- `anime_providers.dart` still imports `bangumi_service.dart` (Task 9); left untouched as instructed.
- Only the four intended files were staged; `.superpowers/*` and `docs/*` changes were left uncommitted.

## Concerns
- None blocking. The two brief deviations are documented above and were necessary for a clean analyze.
- The brief's interface note listed `AnimeSearchPage` as consumed, but the provided code does not use it;
  the unused import was removed rather than inventing a feature. If a "search playback resources" entry
  point is intended here, it belongs to the future video spec.

## Fix: restore play-resources button
Re-added the spec-required "搜索播放资源" placeholder entry point that the brief omitted:
- Added `import 'anime_search.dart';` to `lib/modules/anime/anime_detail_page.dart`.
- Added `_playSection(w, cs)` between `_summarySection(...)` and `_metaSection(...)` in the
  `CustomScrollView` slivers list.
- Added the `_playSection` method before `_metaSection`, rendering a 播放 card with an
  `OutlinedButton.icon` that pushes `AnimeSearchPage(initialKeyword: w.extra['keyword'] as String? ?? w.title)`.

Verification command (workdir `D:\ACGNhub`):

```
$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib
```

Output:

```
Analyzing lib...
No issues found! (ran in 1.2s)
```
