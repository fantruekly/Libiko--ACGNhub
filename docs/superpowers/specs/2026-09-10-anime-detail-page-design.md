# Anime Detail Page — Design

> Date: 2026-09-10
> Status: Approved (design)
> Scope: Anime detail page content only. Playback sources are a separate spec.

## 1. Goal

Make the anime detail page reliably show the **summary**, a **rating** (stars + numeric score), and **basic info** (episodes, year, status, format) — including when the app is offline and serving the bundled seed.

## 2. Background

- The detail page already renders `Work.summary` and `Work.extra['score']`, but:
  - AniList stores `averageScore` (0–100) while Jikan stores `score` (0–10), so the displayed number is inconsistent between providers.
  - The bundled offline seed has `summary: null` and no score, so offline detail pages show "暂无简介数据" and no rating.
  - `seasonYear` is displayed twice (an info chip and the "详细信息" card).
  - Status is only translated for AniList enum values; Jikan's English strings render raw.

## 3. Components

### 3.1 `RatingStars` (new)
File: `lib/core/widgets/rating_stars.dart`

```dart
class RatingStars extends StatelessWidget {
  final double? score; // 0–10 scale
  final double size;   // default 18
  const RatingStars({super.key, this.score, this.size = 18});
}
```

- Renders 5 star icons. Let `scaled = score.clamp(0, 10) / 2` (0–5 stars); `full = scaled.floor()`; a half star is shown when `(scaled - full) >= 0.25`; the rest are outlined.
- Appends a numeric label formatted to 1 decimal (e.g. `8.5`).
- When `score == null`, renders `SizedBox.shrink()` (nothing).
- Pure presentational widget; no data access. Testable in isolation.

### 3.2 Detail page
File: `lib/modules/anime/anime_detail_page.dart`

- **Info section**: cover thumbnail (110×154) + title + `RatingStars(score)` + basic-info chips: episodes (`N 话`), year, status (translated), format.
- **Remove** the separate "详细信息" card (it duplicated year/status/format). All basic info lives in the chip row.
- **Summary section**: unchanged behavior (expandable, 4-line clamp); empty text `暂无简介`.
- **Play section**: unchanged placeholder ("搜索播放资源" → `AnimeSearchPage`); replaced in the playback spec.
- **Bottom CTA**: unchanged (AniList / MyAnimeList link).

## 4. Data normalization

- `Work.extra['score']` is always a **0–10** double:
  - Jikan: `score` (already 0–10).
  - AniList: `averageScore / 10` (was storing 0–100).
- `_statusLabel` maps both AniList enums and Jikan strings:
  - `RELEASING` / `Currently Airing` → 连载中
  - `FINISHED` / `Finished Airing` → 已完结
  - `NOT_YET_RELEASED` / `Not yet aired` → 未播出
  - `CANCELLED` → 已取消, `HIATUS` → 停更
  - otherwise → the raw value
- Episodes, year (`seasonYear`), and format already mapped by both providers.

## 5. Offline seed enrichment

- Regenerate `assets/anime_seed.json` so each entry has:
  - `summary`: a short synopsis.
  - `extra.score`: a 0–10 score.
- Source: fetched once from Jikan (search by title, best match) at build time and bundled. Entries that cannot be resolved keep their cover + title and show `暂无简介` / no stars.
- The seed keeps its existing shape (`id`, `sourceId`, `sourceName`, `type`, `title`, `coverUrl`, `summary`, `tags`, `author`, `extra`).

## 6. Testing

- `test/core/widgets/rating_stars_test.dart`:
  - score `8.5` → 4 filled + 1 half + numeric `8.5`.
  - score `null` → `SizedBox.shrink` (nothing rendered).
  - score `0` → 0 filled + numeric `0.0`.
- `test/core/metadata/anilist_provider_test.dart`: add a case asserting `averageScore 88` → `extra['score'] == 8.8`.
- `test/modules/anime/anime_detail_page_test.dart` (widget): given a `Work` with summary + score, the page shows the summary text and the rating; given one without, it shows `暂无简介` and no stars.
- Re-run `flutter analyze lib test`, `flutter test`, and `flutter build windows --debug`.

## 7. Files

**New**
- `lib/core/widgets/rating_stars.dart`
- `test/core/widgets/rating_stars_test.dart`
- `test/modules/anime/anime_detail_page_test.dart`

**Modified**
- `lib/modules/anime/anime_detail_page.dart`
- `lib/core/metadata/anilist_provider.dart` (score normalization)
- `assets/anime_seed.json` (enriched)
- `test/core/metadata/anilist_provider_test.dart`

## 8. Out of scope

- Playback sources / player (separate spec).
- Characters, studios, duration, rank, vote charts.
- Search result cards.
- Comic/novel/game detail pages.
