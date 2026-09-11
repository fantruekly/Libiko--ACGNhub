# Bangumi Chinese Metadata Source — Design

> Date: 2026-09-10
> Status: Approved (design)
> Scope: Anime metadata source. Playback is a separate spec.

## 1. Goal

Make anime metadata **Chinese** (names, summaries, scores, tags, episodes) and show **current-season** anime on the home, by using **Bangumi** as the primary metadata source. Remove the on-card source label. Regenerate the offline seed from Bangumi.

## 2. Background / Why Bangumi works now

- Earlier attempts to reach `api.bgm.tv` failed — but that was **Windows Schannel's certificate-revocation check** (`CRYPT_E_REVOCATION_OFFLINE`) failing in curl/.NET, not a network block. Browsers soft-fail revocation, which is why the site opened in a browser.
- **Dart/BoringSSL does not perform revocation checks**, so the app reaches Bangumi directly. Verified from Dart: `/calendar` 200, `/search/subject/...` 200, `/v0/subjects/{id}` 200, `/v0/search/subjects` 200, and cover images (`lain.bgm.tv`) 200.
- Bangumi provides `name_cn` (Chinese name), `summary`, `rating.score` (0–10), `tags`, `eps`, `date`, and a weekly `/calendar` of the current season.
- No proxy support is needed.

## 3. Bangumi API

Base: `https://api.bgm.tv`. Headers on every request: `User-Agent: ACGNhub/0.1 (https://github.com/acgnhub)`, `Accept: application/json`.

| Purpose | Endpoint |
|---|---|
| Calendar (current season) | `GET /calendar` |
| Search | `GET /search/subject/<url-encoded keyword>?type=2&responseGroup=small` |
| Detail | `GET /v0/subjects/<id>` |

Field notes:
- **Calendar** `[ { weekday, items: [...] } ]`; item: `id`, `name`, `name_cn`, `summary`, `air_date`, `air_weekday`, `rating { score, total, count }`, `rank`, `images { large, common, medium, ... }`, `collection`.
- **Search** `{ results, list: [...] }`; list item: `id`, `name`, `name_cn`, `images`, `type`.
- **Detail** `result`: `id`, `name`, `name_cn`, `summary`, `date`, `eps`, `images`, `rating { score, ... }`, `tags [ { name, count } ]`, `platform`, `total_episodes`.

## 4. BangumiProvider

New file `lib/core/metadata/bangumi_provider.dart`, implementing `MetadataProvider`:

- `feed(AnimeFeed.season)` → all `/calendar` items (current season).
- `feed(AnimeFeed.today)` → the calendar day whose `weekday.id` matches today's ISO weekday (`DateTime.now().weekday`).
- `feed(AnimeFeed.trending)` → all `/calendar` items sorted by `rating.score` descending (热门 among the current season).
- `search(keyword)` → `/search/subject/<kw>?type=2&responseGroup=small`.
- `detail(work)` → `/v0/subjects/<bangumiId>`; throws `StateError` if `bangumiId` is absent.

Mapping to `Work`:
- `id = 'bangumi_<id>'`; `sourceId = 'bangumi'`; `sourceName = 'Bangumi'`; `type = anime`.
- `title` = `name_cn` when non-empty, else `name`.
- `coverUrl` = `images.large` with `http://` → `https://`.
- `summary` = `summary`.
- `tags` = `tags[].name` (detail) / `[]` (calendar/search).
- `extra` = `{ 'bangumiId': id, 'score': rating.score (0–10 double, null when absent), 'episodes': eps, 'airDate': date/air_date, 'rank': rank }`.

Static parse helpers (`@visibleForTesting`): `parseCalendar`, `parseSearch`, `parseDetail`.

## 5. MetadataService integration

- Provider order becomes **`bangumi → anilist → jikan`**.
- Generalize the transient-failure breaker: replace the single `_anilistDisabledUntil` with `Map<String, DateTime> _disabledUntil` keyed by provider id; on a transient (`DioException`) failure, disable that provider for 1 minute; skip disabled providers in the order.
- `_intervals` default gains `'bangumi': Duration(milliseconds: 300)`.
- Disk cache + seed fallback unchanged.

## 6. Offline seed

- Regenerate `assets/anime_seed.json` from Bangumi's `/calendar` (all current-season items, capped at ~40).
- Each entry already carries `name_cn`, `summary`, and `rating.score` — no per-item detail fetch needed.
- Seed entries use `id = 'bangumi_<id>'`, `sourceId = 'bangumi'`, `sourceName = 'Bangumi'`, `coverUrl` = `images.large` (https), and `extra = {bangumiId, score, episodes, airDate}` so the detail page can enrich them online.

## 7. UI

- Remove the `subtitle` field and the source-name line from `WorkCard` (`lib/core/widgets/work_card.dart`), so cards no longer show `离线推荐` or any source label.

## 8. Testing

- `test/core/metadata/bangumi_provider_test.dart`: fixtures for calendar/search/detail → `Work` (Chinese title via `name_cn`, https cover, summary, score, `bangumiId`); `feed(today)` picks the right weekday.
- `test/core/metadata/metadata_service_test.dart`: update for the new provider order and the generalized disable map.
- Re-run `flutter analyze lib test`, `flutter test`, `flutter build windows --debug`.

## 9. Files

**New**
- `lib/core/metadata/bangumi_provider.dart`
- `test/core/metadata/bangumi_provider_test.dart`
- `tool/gen_seed.ps1` (rewritten to use Bangumi)

**Modified**
- `lib/core/metadata/metadata_service.dart` (provider order, generalized breaker)
- `lib/core/widgets/work_card.dart` (remove source label)
- `assets/anime_seed.json` (regenerated from Bangumi)
- `test/core/metadata/metadata_service_test.dart`

## 10. Out of scope

- Playback / video URLs (separate spec).
- AniList/Jikan removal (they stay as fallbacks).
- Proxy support (not needed — Dart reaches Bangumi directly).
- Comic/novel/game modules.
