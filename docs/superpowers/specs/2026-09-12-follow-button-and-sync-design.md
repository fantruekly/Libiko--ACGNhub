# Follow Button and Sync — Design (Sub-project B3)

> Date: 2026-09-12
> Status: Approved (design)
> Scope: the detail-page 追番 button, a 追番 home tab, and two-way sync of follows + history with the B1 backend. B1 (backend) and B2 (client account) are already implemented.

## 1. Goal

1. A boolean 追番 (follow) button in the detail page's header; it works locally whether or not the user is logged in.
2. A 追番 home tab showing followed works.
3. Local-first two-way sync of follows and watch history with the backend, triggered on app start, after login, and after every change.

## 2. Background

- Local stores already exist: `WatchHistoryManager` + `watchHistoryProvider` (JSON list under `watch_history`) and the unused `FavoriteManager` (`favorites`). Neither records a per-item timestamp or tombstone.
- `accountProvider` (B2) exposes `token`, `refreshSession()` and the base URL; `AccountApi` currently only implements the auth endpoints.
- The backend (B1) provides `GET /api/sync?sinceSeq=<n>` → `{follows, history, nextSeq}` (each item carries `deleted` plus its fields), `PUT/DELETE /api/follows`, `PUT/DELETE /api/history`, with last-write-wins on the client-supplied `updatedAt` and tombstones that preserve their payload.
- The detail page header (`_header`) is a `Row` of back button / title / `WindowControls`.

## 3. Local data model

`lib/core/models/follow_record.dart` (new)

```dart
class FollowRecord {
  final Work work;
  final DateTime updatedAt;
  final bool deleted;
  final bool dirty;   // has local changes not yet pushed
  // + fromJson / toJson / copyWith
}
```

`WatchRecord` (`lib/core/models/watch_record.dart`) gains `updatedAt` (ms), `deleted` and `dirty`. `watchedAt` keeps its meaning (when the episode was watched) and `updatedAt` drives LWW (they are set to the same instant when the user watches an episode).

`lib/core/services/follow_manager.dart` (new) — `FollowManager` over `AppDatabase` key `follows`:
- `List<FollowRecord> all()` — non-deleted, `updatedAt` descending.
- `bool isFollowing(String workId)`.
- `Future<void> follow(Work work)` — upsert with `updatedAt = now`, `dirty = true`.
- `Future<void> unfollow(String workId)` — mark `deleted = true`, `updatedAt = now`, `dirty = true` (a tombstone kept until pushed).
- `List<FollowRecord> dirty()` / `Future<void> markSynced(Set<String> workIds)`.
- `Future<void> mergeFromServer(List<FollowRecord> items)` — LWW merge (see §5).
- `@visibleForTesting static List<FollowRecord> upsert(...)` / `merge(...)` pure helpers.

`WatchHistoryManager` gains the same shape: `record()` sets `updatedAt`/`dirty`, `clear()` writes tombstones and a `pendingClear` flag, plus `dirty()`, `markSynced()`, `mergeFromServer()`, and `pendingClear`/`clearPendingClear()`.

**LWW merge rule (both stores):** for each server item, find the local record by `work.id`.
- If none → insert the server record with `dirty = false`.
- If the local record exists and `local.updatedAt.isAfter(server.updatedAt)` → keep the local record (it stays dirty and will be pushed on the next sync).
- Otherwise → overwrite with the server record (`dirty = false`, taking the server's `deleted`).

**Sync cursor:** `AppDatabase` key `sync_cursor` (an int, default 0).

## 4. `AccountApi` extensions

`lib/core/account/account_api.dart` gains (all with `Authorization: Bearer <token>`):

- `Future<SyncPage> sync(String token, int sinceSeq)` → parsed `{follows, history, nextSeq}`.
- `Future<void> putFollow(String token, Map<String, dynamic> work, int updatedAt)`.
- `Future<void> deleteFollow(String token, String workId, int updatedAt)`.
- `Future<void> putHistory(String token, Map<String, dynamic> work, String episodeTitle, int episodeIndex, int watchedAt, int updatedAt)`.
- `Future<void> clearHistory(String token, int updatedAt)`.

New models in `account_models.dart`: `SyncPage { List<FollowItem> follows; List<HistoryItem> history; int nextSeq; }`, `FollowItem { Map<String,dynamic> work; int updatedAt; bool deleted; }`, `HistoryItem { Map<String,dynamic> work; String episodeTitle; int episodeIndex; int watchedAt; int updatedAt; bool deleted; }`.

## 5. Sync service

`lib/core/account/sync_service.dart` (new)

```dart
class SyncService {
  SyncService({
    AccountApi Function(String baseUrl)? apiFactory,
    FollowManager? follows,
    WatchHistoryManager? history,
  });
  Future<void> sync();          // push then pull; silent on network failure
  void schedule();              // debounce + serialise, then sync()
}
final syncProvider = Provider<SyncService>(...);
```

`sync()`:
1. Return immediately when not logged in (`accountProvider` has no token).
2. **Push** the local dirty state:
   - each dirty follow → `putFollow` (or `deleteFollow` when `deleted`), then `markSynced`;
   - if history `pendingClear` → `clearHistory`, clear the flag, mark all history tombstones synced; otherwise each dirty history record → `putHistory`, then `markSynced`.
3. **Pull** `sync(token, cursor)` and `mergeFromServer` into both stores, then store `nextSeq` as the cursor.
4. On an `AccountException` with `statusCode == 401` → `accountProvider.notifier.refreshSession()`; if it returns true, retry the whole `sync()` once; otherwise stop.
5. On any other `AccountException` (network) → return silently; the dirty flags stay set so the next sync retries.

`schedule()` coalesces bursts (e.g. several changes in a row) with a short debounce and never runs two `sync()` calls concurrently.

**Triggers:** `main()`'s startup `load()` completion; a successful login/register (`AccountNotifier._authenticate`); and every local change — `WatchHistoryNotifier.record/clear` and the new `FollowNotifier.toggle` call `syncProvider.notifier.schedule()`.

## 6. UI

**Detail page** (`lib/modules/anime/anime_detail_page.dart`, `_header`): insert, immediately before `WindowControls`, an `IconButton` showing `Icons.favorite_rounded` in `#007AFF` when followed and `Icons.favorite_border_rounded` in `#8E8E93` when not, with a tooltip `追番` / `已追番`. Tapping toggles the follow through the follow notifier and triggers a sync. It works when logged out (local only).

**Home** (`lib/modules/anime/anime_home.dart`): the `TabBar`/`TabBarView` gains a 5th tab `追番` rendering a new `AnimeFollowView` (`lib/modules/anime/anime_follow.dart`): the same grid as `AnimeHistoryView` (`crossAxisCount: 5`, spacing 16, `childAspectRatio: 0.66`), one `WorkCard` per followed work, tapping opens `AnimeDetailPage`, plus an `EmptyState` (`还没有追番`) when empty.

**Follow state provider** (`lib/core/services/follow_manager.dart`): `FollowNotifier extends Notifier<List<FollowRecord>>` with `build()` = `all()`, `toggle(Work)` (follow/unfollow then `state = all()`), and `isFollowing(workId)`; `followProvider`.

## 7. Error Handling

- Not logged in → `sync()` is a no-op; follows/history remain fully usable locally.
- Network failure during a sync → silent; dirty flags persist for the next attempt.
- 401 → refresh once, then give up (the account layer already clears the session when the refresh token is invalid).
- A malformed stored record is skipped (as today).
- A sync never blocks the UI: it runs in the background and updates providers when done.

## 8. Testing

- `test/core/models/follow_record_test.dart`: JSON round-trip.
- `test/core/services/follow_manager_test.dart`: `upsert`/`merge` pure logic (dedupe by work id, LWW keep-local vs take-server, tombstone handling) and the store's `follow`/`unfollow`/`dirty`/`markSynced` via mocked prefs.
- `test/core/services/watch_history_test.dart` (extend): the new `dirty`/tombstone/merge behaviour.
- `test/core/account/sync_service_test.dart`: a fake `AccountApi` + seeded stores covering push (dirty → requests → `markSynced`), pull (merge + cursor advance), the 401 refresh-and-retry path, and a network failure leaving dirty flags set.
- End-to-end probe: with `server/` running locally, follow a work in one probe run, then a second probe run pulls it back.
- Re-run `flutter analyze lib test`, `flutter test`, `flutter build windows --debug`.

## 9. Files

**New**
- `lib/core/models/follow_record.dart`
- `lib/core/services/follow_manager.dart`
- `lib/core/account/sync_service.dart`
- `lib/modules/anime/anime_follow.dart`
- `test/core/models/follow_record_test.dart`
- `test/core/services/follow_manager_test.dart`
- `test/core/account/sync_service_test.dart`

**Modified**
- `lib/core/models/watch_record.dart` (updatedAt/deleted/dirty)
- `lib/core/services/watch_history.dart` (dirty/tombstone/pendingClear/merge)
- `lib/core/account/account_api.dart` + `account_models.dart` (sync/follows/history endpoints + models)
- `lib/core/account/account_service.dart` (trigger a sync after login/register)
- `lib/modules/anime/anime_detail_page.dart` (追番 button)
- `lib/modules/anime/anime_home.dart` (5th tab)
- `lib/main.dart` (trigger a sync after startup `load()`)

## 10. Out of Scope

- Follow statuses (想看 / 在看 / 看过) — 追番 stays a boolean.
- Multi-account, per-account local data, pagination.
- Server push/websockets; sync is pull-on-demand.
- Syncing anything other than follows and history (e.g. settings, playback position).
