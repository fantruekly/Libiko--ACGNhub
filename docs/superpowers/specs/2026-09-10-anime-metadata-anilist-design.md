# Anime Metadata via AniList (with Jikan fallback) — Design

> Date: 2026-09-10
> Status: Approved (design)
> Scope: Anime metadata subsystem only. Video extraction is a separate spec.

## 1. Goal

Replace the Bangumi-based anime metadata layer (images, titles, summaries, tags, scores) with a provider abstraction whose primary source is **AniList** (`https://graphql.anilist.co`) and whose working fallback is **Jikan / MyAnimeList** (`https://api.jikan.moe/v4`). The home, search, and detail pages consume the abstraction and must keep working during the current AniList outage.

## 2. Background / Constraints

- **AniList GraphQL API is currently disabled globally** (returns HTTP 403 `"The AniList API has been temporarily disabled due to severe stability issues."`). `anilist.co/search/anime` is a client-rendered JS shell and cannot be scraped.
- **Jikan v4 works now**: REST, no auth, returns the equivalent metadata.
- Because of this, the design is an abstraction with an automatic fallback, so the app works today and self-heals when AniList returns.
- Windows is the primary target platform.
- No in-app video player is in scope here (the video subsystem is a separate spec).

## 3. Architecture

New package folder `lib/core/metadata/`:

| File | Responsibility |
|---|---|
| `metadata_provider.dart` | `MetadataProvider` interface + `AnimeFeed` enum |
| `anilist_provider.dart` | AniList GraphQL client + response mapping |
| `jikan_provider.dart` | Jikan REST client + response mapping |
| `metadata_service.dart` | Fallback orchestration + in-memory caches |

`MetadataService` exposes the same operations as a provider and is the only thing the UI depends on.

## 4. Interface

```dart
enum AnimeFeed { trending, season, today }

abstract class MetadataProvider {
  String get id; // 'anilist' | 'jikan'

  Future<List<Work>> feed(AnimeFeed feed, {int page = 1});
  Future<List<Work>> search(String keyword, {int page = 1});
  Future<Work> detail(Work work); // returns enriched Work
}
```

`perPage` is fixed at 25 for feeds/search (Jikan's documented max; AniList accepts 25). A returned list shorter than `perPage` signals "no more pages".

## 5. AniList provider

Endpoint: `POST https://graphql.anilist.co` with `Content-Type: application/json`, body `{"query": ..., "variables": {...}}`.

Shared `Media` field selection:

```graphql
id
title { romaji english native }
coverImage { extraLarge large color }
bannerImage
description(asHtml: false)
genres
episodes
duration
status
season
seasonYear
format
averageScore
popularity
nextAiringEpisode { episode airingAt }
studios(isMain: true) { nodes { name } }
startDate { year month day }
```

Queries:

- **trending** — `Page(page:, perPage: 25) { media(type: ANIME, sort: TRENDING_DESC, isAdult: false) { ... } }`
- **season** — compute the current season (`WINTER/SPRING/SUMMER/FALL`) and year from the local date; `media(type: ANIME, season:, seasonYear:, sort: POPULARITY_DESC, isAdult: false)`
- **today** — `Page { airingSchedules(airingAt_greater: <today 00:00 local→epoch>, airingAt_lesser: <tomorrow 00:00 local→epoch>, sort: TIME) { airingAt episode media { ... } } }`
- **search** — `Page { media(type: ANIME, search: $keyword, sort: SEARCH_MATCH, isAdult: false) { ... } }`
- **detail** — `Media(id: $id, type: ANIME) { ... }` (same fields as the shared selection)

Mapping: `extra['anilistId']`, `title` = `native` (fallback `romaji`, `english`), `extra['titleNative']/['titleEnglish']`, `coverUrl` = `coverImage.extraLarge ?? large`, `extra['bannerUrl']` = `bannerImage`, `summary` = `description` (HTML stripped), `tags` = `genres`, `extra['score']` = `averageScore`, `extra['episodes']`, `extra['status']`, `extra['seasonYear']`, `extra['format']`, `extra['studios']`.

## 6. Jikan provider

Base: `https://api.jikan.moe/v4`. Rate limit ≈ 3 req/s — calls are made sequentially.

| Feed | Endpoint |
|---|---|
| trending | `/top/anime?filter=bypopularity&limit=25&page=N` |
| season | `/seasons/now?limit=25&page=N` |
| today | `/schedules?filter=<weekday>&limit=25&page=N` |
| search | `/anime?q=<kw>&sfw=true&limit=25&page=N` |
| detail | `/anime/{mal_id}/full` |

Mapping: `extra['malId']` = `mal_id`, `title` = `title` (fallback `title_english`, `title_japanese`), `extra['titleNative']` = `title_japanese`, `coverUrl` = `images.jpg.large_image_url`, `summary` = `synopsis`, `tags` = `genres[].name`, `extra['score']` = `score`, `extra['episodes']`, `extra['status']` = `status`, `extra['seasonYear']` = `year`, `extra['studios']` = `studios[].name`. `Work.id` = `jikan_<mal_id>`.

## 7. Fallback + caching (`MetadataService`)

- A single `_anilistDisabledUntil` timestamp drives the choice; it starts unset.
- Each call:
  1. If `now < _anilistDisabledUntil` → go straight to Jikan.
  2. Else try AniList; on a transient/network error (`DioException`) → set `_anilistDisabledUntil = now + 10min` and try Jikan. Non-transient errors (e.g. a `StateError` for a Work with no ID) do not disable AniList.
- Provider-level response cache: `Map<String, (DateTime, dynamic)>` keyed by `provider:op:args`, TTL 5 minutes, for feeds and search. Detail cached by id.
- Jikan calls are serialized through a single-flight queue to respect the rate limit.
- If both providers fail, rethrow the last error so the UI can show its error state.

## 8. Model changes

`Work` stays generic (shared by anime/comic/novel/game). Anime-specific fields live in `Work.extra`. Add convenience getters:

```dart
int? get anilistId => extra['anilistId'] as int?;
int? get malId => extra['malId'] as int?;
```

List items need only `id`, `title`, `coverUrl`; the detail page re-fetches the full record via `MetadataService.detail`.

## 9. UI wiring

- **`anime_providers.dart`** — add `metadataServiceProvider`; add `animeFeedProvider = FutureProvider.family<List<Work>, AnimeFeed>((ref, feed) => service.feed(feed))`; remove `trendingAnimeProvider` and `bangumiServiceProvider`; keep `sourceManagerProvider` and `animeSourceListProvider` unchanged (video spec).
- **`anime_home.dart`** — pills `[热门推荐] [本季新番] [今日放送]` map to `AnimeFeed.trending/season/today`. Watch `animeFeedProvider(feed)`; hero = first item; grid = list; `ShimmerLoader` while loading; `EmptyState` + retry on error; append next page on scroll until a short page is returned.
- **`anime_search.dart`** — `_search()` calls `metadataService.search(keyword)`; unchanged skeleton/empty/error states.
- **Detail** — rename `bangumi_detail_page.dart` → `anime_detail_page.dart` and `BangumiDetailPage` → `AnimeDetailPage` (update imports). Fetch `metadataService.detail(work)` on init; hero uses `bannerUrl` else cover; meta chips score/episodes/season+year/format/status; tags = genres; expandable summary; CTA `在 AniList 查看` when `anilistId != null`, else `在 MyAnimeList 查看` when `malId != null`. Keep the "搜索播放资源" button as a placeholder for the video spec.

## 10. Bangumi removal

- Delete `lib/modules/anime/bangumi_service.dart`.
- Delete `assets/bangumi_calendar.json`; remove it from `pubspec.yaml` assets.
- Remove the `'Bangumi'` fallback label in the home hero (show provider name / year instead).

## 11. Testing

- `test/core/metadata/anilist_provider_test.dart` — feed GraphQL JSON fixture → `Work` mapping.
- `test/core/metadata/jikan_provider_test.dart` — REST JSON fixture → `Work` mapping.
- `test/core/metadata/metadata_service_test.dart` — fake providers: AniList failure → Jikan result; verify AniList is skipped for 10 min, then retried; verify response cache.
- Re-run the full suite, `flutter analyze lib`, and `flutter build windows --debug`.

## 12. Files

**New**
- `lib/core/metadata/metadata_provider.dart`
- `lib/core/metadata/anilist_provider.dart`
- `lib/core/metadata/jikan_provider.dart`
- `lib/core/metadata/metadata_service.dart`
- `lib/modules/anime/anime_detail_page.dart` (renamed)
- `test/core/metadata/anilist_provider_test.dart`
- `test/core/metadata/jikan_provider_test.dart`
- `test/core/metadata/metadata_service_test.dart`

**Modified**
- `lib/core/models/work.dart`
- `lib/modules/anime/anime_providers.dart`
- `lib/modules/anime/anime_home.dart`
- `lib/modules/anime/anime_search.dart`
- `pubspec.yaml`

**Deleted**
- `lib/modules/anime/bangumi_service.dart`
- `assets/bangumi_calendar.json`

## 13. Out of scope

- Video source extraction/playback (separate spec).
- Watch history / "继续观看".
- Authentication, user lists, or ratings submission.
- Caching to disk (in-memory only for now).
