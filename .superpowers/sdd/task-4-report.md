# Task 4 Report: Regenerate the offline seed from Bangumi

## Status
DONE_WITH_CONCERNS

## Summary
Replaced the English (Jikan) offline seed with one regenerated from Bangumi's `/calendar`
(current season). Per the brief, the generator is Dart (`tool/gen_seed.dart`, Dio/BoringSSL)
rather than PowerShell, because curl/.NET fail on Bangumi's TLS revocation check. The generator
was created verbatim from the brief and produced 40 entries with Chinese titles, https covers,
and `extra = {bangumiId, score, episodes, airDate}`. `flutter test` passes and the change is
committed.

## What was done
1. Created `tool/gen_seed.dart` exactly as specified in the brief (verbatim).
2. Ran it from the repo root: `$env:Path = "C:\flutter\bin;$env:Path"; dart run tool/gen_seed.dart`
   — succeeded on the first attempt.
3. Verified the asset: 40 `bangumi_*` entries, 0 `http://` covers (all https), valid `Work` shape.
4. Ran the full `flutter test` suite (37 tests) — all passed.
5. Committed `tool/gen_seed.dart` and `assets/anime_seed.json`.

## Exact generator output
```
wrote 40 entries
```
N = 40, which satisfies the brief's expectation of N >= 30.

## Asset verification
```
ids=40            (number of "id": "bangumi_*" entries)
httpCovers=0      (no insecure covers; all covers are https://lain.bgm.tv/...)
nonEmptySummary=0 (see Concerns)
```
Spot check of the first entry:
```json
{
  "id": "bangumi_456080",
  "sourceId": "bangumi",
  "sourceName": "Bangumi",
  "type": "anime",
  "title": "转学后班上的清纯可爱美少女，竟是小时候玩在一起的哥们儿",
  "coverUrl": "https://lain.bgm.tv/pic/cover/l/ce/e2/456080_C4q4C.jpg",
  "summary": "",
  "tags": [],
  "author": null,
  "extra": {
    "bangumiId": 456080,
    "score": 5,
    "episodes": null,
    "airDate": "2026-07-06"
  }
}
```
The shape matches `Work.fromJson` in `lib/core/models/work.dart` and the loader in
`lib/core/metadata/metadata_service.dart:242`.

## Flutter test result
Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test
```
Output (tail):
```
00:03 +37: All tests passed!
```
37/37 passed.

## Files changed
- `tool/gen_seed.dart` — new (committed)
- `assets/anime_seed.json` — replaced with the regenerated 40-entry Bangumi seed (committed)

## Commit
```
76c3a04 chore(seed): regenerate offline seed from Bangumi calendar
```
2 files changed, 742 insertions(+), 548 deletions(-).

## Concerns
- **Empty summaries.** All 40 entries have `"summary": ""`. Bangumi's `/calendar` endpoint does
  not return a `summary` field, so the generator's `(m['summary'] as String?)?.trim()` yields
  null/empty. The brief's interface mentioned Chinese `summary`, but that field is simply absent
  from this endpoint. The app can still hydrate full summaries on demand via the Bangumi detail
  provider (`lib/core/metadata/bangumi_provider.dart`). If non-empty seed summaries are required,
  the generator would need a follow-up per-work `/v0/subjects/{id}` fetch.
- **`episodes` is also null** for every entry (same reason: `/calendar` omits `eps`). `score` and
  `airDate` are populated.
- The generator was used verbatim per the brief; I did not add extra fetches to fill these gaps.
- `tool/gen_seed.ps1` shows as a pre-existing unstaged deletion in the working tree. It was not
  part of this task's commit (the brief stages only `tool/gen_seed.dart` and
  `assets/anime_seed.json`).

## Fix: seed summaries

### Change
Replaced the generator body so it no longer trusts the `/calendar` items for detail fields.
`tool/gen_seed.dart` now collects up to 40 unique ids from `/calendar`, then fetches
`GET /v0/subjects/{id}` for each id (300 ms apart) and maps the richer subject payload:
`name_cn`/`name` for the title, `images.large`/`images.common` for the cover, `summary` for the
summary, `tags[].name` for tags, `rating.score` for the score, `eps`/`total_episodes` for the
episode count, and `date` for the air date. Per-id failures are logged to stderr and skipped.

### Generator output
```
wrote 40 entries
```

### Summary count
```
total=40
withSummary=39
```
39 of 40 entries now carry a non-empty summary (> 10 chars); previously it was 0.

### Test result
Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test
```
Output (tail):
```
00:02 +37: All tests passed!
```
37/37 passed.

### Commit
```
fix(seed): fetch subject details so seed entries have summaries
```
