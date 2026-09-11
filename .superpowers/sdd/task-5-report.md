# Task 5 Report: Add metadata Riverpod providers

## Status
DONE

## What I implemented
Added two new Riverpod providers to `lib/modules/anime/anime_providers.dart`, exactly as specified in the brief, while leaving all existing providers untouched:

- Imports added:
  - `../../core/metadata/metadata_provider.dart` (for `AnimeFeed`)
  - `../../core/metadata/metadata_service.dart` (for `MetadataService`)
- `metadataServiceProvider` (`Provider<MetadataService>`) — constructs a `MetadataService`.
- `animeFeedProvider` (`FutureProvider.family<List<Work>, AnimeFeed>`) — watches `metadataServiceProvider` and calls `feed(feed)`.

Both new providers were inserted immediately after `animeSourceListProvider`. Existing `sourceManagerProvider`, `animeSourceListProvider`, `trendingAnimeProvider`, and `bangumiServiceProvider` are unchanged (to be removed in Task 9).

## Verification
Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib/modules/anime/anime_providers.dart
```
Result:
```
Analyzing anime_providers.dart...
No issues found! (ran in 0.7s)
```

## Files changed
- `lib/modules/anime/anime_providers.dart` (+8 lines)

## Commit
- `afc67b7` feat(anime): expose metadata service and feed provider

Only the specified file was staged/committed. Other pre-existing working-tree modifications (`.superpowers/sdd/*`, untracked docs) were left untouched.

## Self-review findings
- Imports match the brief verbatim.
- Provider signatures match the interfaces: `Provider<MetadataService>` and `FutureProvider.family<List<Work>, AnimeFeed>`.
- `Work` was already imported, so no duplicate import.
- `AnimeFeed` is correctly sourced from `metadata_provider.dart`; `flutter analyze` reports no unused-import warnings.
- Placement after `animeSourceListProvider` is as requested.
- Existing providers untouched.

## Concerns
- None. No unit test is required for this task; `flutter analyze` is clean.

## Final review fixes

Applied three code-review fixes for the anime detail-page feature.

1. **Fix 1 (Important) — basic-info chips + status translation test.**
   Added `shows basic-info chips including translated status` to
   `test/modules/anime/anime_detail_page_test.dart`, asserting `12 话`, `2024`,
   `已完结` (from `Finished Airing`), and `TV` render.

2. **Fix 2 (Minor) — RatingStars boundary tests.**
   Added `clamps scores above 10` (score 20 → 5 full stars, label `10.0`) and
   `below the half threshold shows no half star` (score 8.4 → 4 full, 0 half,
   1 outline) to `test/core/widgets/rating_stars_test.dart`.

3. **Fix 3 (Minor) — strip HTML from seed synopsis.**
   In `tool/gen_seed.ps1`, the loop now computes
   `$summary = $it.synopsis; if ($summary) { $summary = ($summary -replace '<[^>]+>', '').Trim() }`
   and the `summary` field writes `$summary`. Generator was not re-run.

### Verification

Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test
```
Output:
```
Analyzing 2 items...
No issues found! (ran in 1.2s)
```

Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test
```
Output:
```
00:01 +32: All tests passed!
```

## Final review fixes

Applied four code-review fixes for the Bangumi metadata feature.

1. **Fix 1 (Critical) — stop feed pagination.** In
   `lib/core/metadata/bangumi_provider.dart`, `feed` now returns `const []`
   for `page > 1`, so the non-paginated `/calendar` endpoint no longer repeats
   the same list forever under infinite scroll.

2. **Fix 2 (Important) — inject a clock and test `feed`.** Added a
   `DateTime Function() _now` field/param to `BangumiProvider` (defaults to
   `DateTime.now`) and used `_now().weekday` in the `AnimeFeed.today` case.
   Added a `_FakeAdapter` (dio `HttpClientAdapter`) plus a `feed(...)` test to
   `test/core/metadata/bangumi_provider_test.dart` covering injected-weekday
   filtering, `page > 1` being empty, and trending score sort.

3. **Fix 3 (Important) — transient-only disable.** In
   `lib/core/metadata/metadata_service.dart`, `_run`'s catch now disables a
   provider only when `_isTransient(e)` (5xx/429/timeouts/connection errors)
   instead of on any `DioException`.

4. **Fix 4 (Important) — normalize 0 to null for score/episodes.** In
   `bangumi_provider.dart` `_parseItem`, `score`/`episodes` of `0` now map to
   `null`; the same normalization was applied in `tool/gen_seed.dart`'s `extra`
   map, and the seed was regenerated.

Two existing tests were also adjusted to the new semantics:
- `test/core/metadata/bangumi_provider_test.dart` gained the
  `metadata_provider.dart` import (for `AnimeFeed`).
- `test/core/metadata/metadata_service_test.dart`'s `_FakeProvider` gained a
  `transient` flag (503 response) so the "skips AniList" test exercises
  transient-only disabling; call-count assertions account for the
  `_maxAttempts` retries.

### Verification

Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; dart run tool/gen_seed.dart
```
Output:
```
wrote 40 entries
```

Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test
```
Output:
```
Analyzing 2 items...
No issues found! (ran in 1.8s)
```

Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test
```
Output:
```
00:05 +38: All tests passed!
```
