# SDD Progress Ledger

Plan: docs/superpowers/plans/2026-09-12-follow-button-and-sync.md
Base commit: 552757f (before Task 1)

Task 1: complete (commits 552757f..39861b0, review clean)
Task 2: complete (commits 39861b0..b0ddce8, review clean)
Task 3: complete (commits b0ddce8..7796fcb, review clean after adjudication)
Task 4: complete (commits 7796fcb..4839dfe, review clean)
Task 5: complete (commits 4839dfe..ebf9ef7, review clean)
Task 6: complete (commits ebf9ef7..4e0e5bf, review clean)
Task 7: verification complete (analyze clean, 115/115 tests, build OK, e2e probe passed)
Final whole-branch review: complete; 1 Critical + 4 Important fixed in 6a58b2c, one follow-up fixed in 5f2defa

## Task 7 evidence

- `flutter analyze lib test` clean; `flutter test` 115/115; `flutter build windows --debug` built.
- End-to-end sync probe (`.superpowers/sdd/sync_probe.dart`, `flutter run -d windows -t`, against a
  locally started `server/`): after following a work and recording history the dirty sets were 1/1;
  `SyncService.sync()` cleared both, advanced `sync_cursor` to 2, and a second `sync()` was a no-op
  (`SERVER follows=0 history=0 nextSeq=2`).

## Final-review fixes (`6a58b2c`, `5f2defa`)

- `merge` preserves `dirty` in the kept-local branch (the design spec says it stays dirty); `markSynced`
  is version-guarded (`Map<String, DateTime> pushedUpdatedAt`), so a local write during a sync is not
  silently marked clean.
- A history clear stores its timestamp (`watch_history_clear_at`); `_push` sends `clearHistory` with it
  and still pushes records made after the clear.
- `FollowManager` gained a `_pending` chain; the history sync mutations join the existing one.
- `schedule()` during a running sync sets `_rerun` and re-runs once.
- `_run` catches broadly, including on the 401 refresh/retry path.

## Notes

- Briefs are extracted with an inline fence-aware script (`.superpowers/sdd/make-brief.ps1` is flaky on
  the longer plans); always check the brief's first line names the right task.
- **Task 3 adjudication:** `all()` ordering by `watchedAt` (not `updatedAt`) is intended — the plan says
  to keep the existing `sortDescending`, and sub-project A's spec pins the history tab to `watchedAt` desc.

## Deferred Minor findings (not required before merge)

- `lib/core/services/follow_manager.dart` / `watch_history.dart` — the version guard compares millisecond-truncated `DateTime`s (a same-millisecond write during a push compares equal); `_pending` is per-instance, not process-wide (production wires separate manager instances for the UI and the sync service).
- `lib/core/services/watch_history.dart` — `clear()` sets `pendingClear` when nothing is live and is O(n²) I/O; tombstones are never pruned; a legacy `pendingClear` without `clearAt` falls back to push time.
- `lib/core/models/follow_record.dart:18-19` — a missing `updatedAt` defaults to epoch 0; a stale doc comment on `merge`.
- `lib/core/account/account_api.dart` — `deleteFollow` interpolates an unencoded `workId`; `sync` builds its query by string interpolation.
- `lib/core/account/sync_service.dart` — duplicated storage-key literals; `_debounce` never cancelled; `catch (_)` hides programming errors.
- `lib/modules/anime/video_player_page.dart:82-83` — `schedule()` is called outside the `gen == _gen` guard.
- `lib/core/account/account_service.dart:8` ↔ `lib/core/account/sync_service.dart:12` — a legal, benign import cycle.
- Test gaps: no widget tests for the follow button / 追番 tab; no `schedule()` debounce/concurrency test.

(previous plans are complete; their history is in git)
