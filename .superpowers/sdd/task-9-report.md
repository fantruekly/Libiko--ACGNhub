# Task 9 Report: Remove Bangumi entirely

## Status: DONE_WITH_CONCERNS

## Summary
Removed all Bangumi integration from the Flutter app code as specified in the brief.

## Changes
### Deleted
- `lib/modules/anime/bangumi_service.dart`
- `assets/bangumi_calendar.json`

### Modified
- `lib/modules/anime/anime_providers.dart` — rewritten to the exact brief content: removed `import 'bangumi_service.dart';`, the `_stableCoverUrl` helper, `trendingAnimeProvider`, and `bangumiServiceProvider`. Kept `sourceManagerProvider`, `animeSourceListProvider`, `metadataServiceProvider`, `animeFeedProvider`.
- `pubspec.yaml` — removed `    - assets/bangumi_calendar.json` under `assets:`.

## Verification
- `flutter analyze lib` → `No issues found! (ran in 1.4s)`
- `git grep -i bangumi -- lib` → no output (NO_MATCHES)
- `git grep -n "trendingAnimeProvider\|bangumiServiceProvider\|_stableCoverUrl" -- . ":(exclude).superpowers" ":(exclude)docs"` → only matches in `opendesign/2026-09-10-ui-redesign.md` (design mockup, not app code).

## Commit
- `9a63a64 chore: remove Bangumi metadata integration` (4 files changed, 1 insertion, 175 deletions; includes both deletions)

Note: Staged only the task-scoped code files (not the unrelated `.superpowers/` brief/report/progress edits or untracked `docs/` files present in the working tree), per the "stage only intended files" guidance. The brief said `git add -A`, but committing unrelated orchestration docs would have polluted the task commit.

## Self-Review
- Verified the rewritten `anime_providers.dart` matches the brief verbatim.
- Confirmed the deleted files no longer exist on disk.
- Confirmed no remaining `bangumi` references in `lib/` and no remaining provider symbol references outside `opendesign/` design docs.
- `pubspec.yaml` asset list remains valid.

## Concerns
- `opendesign/2026-09-10-ui-redesign.md` and `opendesign/assets/app.js` / `index.html` still reference Bangumi/`trendingAnimeProvider`/`bangumiServiceProvider`. These are static design mockups, not compiled app code, so `flutter analyze` is unaffected and the brief's `lib` grep is clean. If "entirely" is intended to include the `opendesign/` mockups, that would be out of scope for this brief's stated files.
- `git add -A` from the brief was not followed literally; only task-relevant files were committed.
