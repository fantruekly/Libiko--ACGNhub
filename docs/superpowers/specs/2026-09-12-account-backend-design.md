# Account & Sync Backend — Design (Sub-project B1)

> Date: 2026-09-12
> Status: Approved (design)
> Scope: the self-hosted backend only. The client account UI, the 追番 button and sync wiring are B2/B3.

## 1. Goal

A self-hosted account + data-sync backend for ACGNhub: username/password accounts, a boolean 追番 (follow) list, watch history, and an incremental sync endpoint. Delivered as a standalone Dart package under `server/`, deployable with Docker.

## 2. Background

- The repo currently has no server code. The Flutter app already depends on `dio` for HTTP.
- `server/` is a **separate Dart package** (its own `pubspec.yaml`), not part of the Flutter app. The root `analysis_options.yaml` must exclude `server/**` so `flutter analyze` does not try to resolve the server's dependencies.
- SQLite's native library: on Windows the `sqlite3` Dart package cannot find `sqlite3.dll` by default, but `C:\Windows\System32\winsqlite3.dll` is present. The server therefore calls `open.overrideFor(OperatingSystem.windows, () => 'winsqlite3.dll')` at startup. On Linux (Docker) the default `libsqlite3` is used.

## 3. Package layout

```
server/
  pubspec.yaml
  bin/server.dart          # entrypoint: read env, open DB, start HTTP server
  lib/src/database.dart    # SQLite open + schema + all queries
  lib/src/auth.dart        # bcrypt hashing, JWT issue/verify, auth middleware
  lib/src/api.dart         # shelf_router routes + handlers
  test/auth_test.dart      # unit tests for hashing + JWT
  test/api_test.dart       # integration tests driving the router directly
  Dockerfile
```

Dependencies: `shelf`, `shelf_router`, `sqlite3`, `bcrypt`, `dart_jsonwebtoken`; dev: `test`.

## 4. Data model (SQLite)

```sql
CREATE TABLE users (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  username      TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  next_seq      INTEGER NOT NULL DEFAULT 0,
  created_at    INTEGER NOT NULL
);

CREATE TABLE follows (
  user_id           INTEGER NOT NULL,
  work_id           TEXT NOT NULL,
  work_json         TEXT NOT NULL,
  client_updated_at INTEGER NOT NULL,
  seq               INTEGER NOT NULL,
  deleted           INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, work_id)
);

CREATE TABLE history (
  user_id           INTEGER NOT NULL,
  work_id           TEXT NOT NULL,
  work_json         TEXT NOT NULL,
  episode_title     TEXT NOT NULL,
  episode_index     INTEGER NOT NULL,
  watched_at        INTEGER NOT NULL,
  client_updated_at INTEGER NOT NULL,
  seq               INTEGER NOT NULL,
  deleted           INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, work_id)
);
```

`work_json` is the client's `Work.toJson()` as a string, so a client can render the follow/history lists without re-fetching metadata.

Two timestamps per row:
- `client_updated_at` — the client's millisecond timestamp, used only for last-write-wins conflict resolution.
- `seq` — a per-user monotonic counter (drawn from `users.next_seq`), used only as the sync cursor. This keeps the cursor immune to client/server clock skew.

## 5. API

All routes are under `/api`. Requests and responses are JSON (`Content-Type: application/json`). Errors use `{"error": "<code>", "message": "<text>"}` with these codes: `bad_request` (400), `unauthorized` (401), `not_found` (404), `conflict` (409), `internal` (500).

### Auth

- `POST /api/auth/register` — body `{"username": "...", "password": "..."}`.
  - Validation: username 3–32 chars matching `^[A-Za-z0-9_-]+$`; password at least 6 chars.
  - `201` → `{"token": "<access>", "refreshToken": "<refresh>", "user": {"id": 1, "username": "..."}}`
  - `409 conflict` if the username is taken.
- `POST /api/auth/login` — same body; `200` with the same shape; `401 unauthorized` on a wrong username or password.
- `POST /api/auth/refresh` — body `{"refreshToken": "..."}`; `200` → `{"token": "<access>"}`; `401` if the refresh token is invalid/expired or not a refresh token.
- `GET /api/me` — auth; `200` → `{"id": 1, "username": "..."}`.

### Follows (boolean 追番)

- `GET /api/follows` — auth; `200` → `{"items": [{"work": {...}, "updatedAt": 1730000000000}]}` (deleted rows excluded).
- `PUT /api/follows` — auth; body `{"work": {...}, "updatedAt": 1730000000000}`; upsert with LWW (see §6); `200` → `{"work": {...}, "updatedAt": <stored>}`.
- `DELETE /api/follows/<workId>?updatedAt=<ms>` — auth; writes a tombstone; `200` → `{"workId": "...", "updatedAt": <stored>}`.

### History

- `GET /api/history` — auth; `200` → `{"items": [{"work": {...}, "episodeTitle": "...", "episodeIndex": 0, "watchedAt": 1730000000000, "updatedAt": 1730000000000}]}` (deleted rows excluded, ordered by `watchedAt` descending).
- `PUT /api/history` — auth; body `{"work": {...}, "episodeTitle": "...", "episodeIndex": 0, "watchedAt": 1730000000000, "updatedAt": 1730000000000}`; upsert with LWW; `200` → the stored item.
- `DELETE /api/history?updatedAt=<ms>` — auth; tombstones every history row of the user; `200` → `{"deleted": <count>}`.

### Sync

- `GET /api/sync?sinceSeq=<n>` — auth; `sinceSeq` defaults to 0.
  - `200` → `{"follows": [...], "history": [...], "nextSeq": <n>}`.
  - Each list contains every row (including tombstones) with `seq > sinceSeq`, each item carrying `"deleted": true|false` plus its normal fields (`work`, `updatedAt` for follows; the history fields for history).
  - `nextSeq` is the user's current `next_seq`; the client passes it back as `sinceSeq` next time.

## 6. Sync / conflict strategy

- **Last-write-wins** on `client_updated_at`: an upsert whose `updatedAt` is **strictly less than** the stored `client_updated_at` is rejected and the stored row is returned unchanged. Otherwise the incoming data is written and `seq` is bumped.
- **Tombstones**: deletions set `deleted = 1` and bump `seq`, so a delete propagates to other devices via `/api/sync`.
- A client pushes its local changes with `PUT`/`DELETE`, then pulls `GET /api/sync?sinceSeq=<nextSeq>`.

## 7. Auth details

- Passwords hashed with `bcrypt` (`hashpw`), verified with `checkpw`.
- JWTs signed `HS256` with the secret from the environment variable `ACGHUB_JWT_SECRET`. The server exits with a clear error if it is unset.
- Access token: claims `{"sub": <userId>, "typ": "access", "iat": ..., "exp": ...}`, 15-minute lifetime.
- Refresh token: claims `{"sub": <userId>, "typ": "refresh", "iat": ..., "exp": ...}`, 30-day lifetime.
- Auth middleware reads `Authorization: Bearer <access>`, verifies signature + expiry + `typ == "access"`, and puts the user id in the request context. Any failure → `401 unauthorized`.
- Every write is scoped by the token's user id; a client can never read or modify another user's rows.
- `bin/server.dart` reads `PORT` (default 8080) and `ACGHUB_DB_PATH` (default `data/acgnhub.db`) as well as `ACGHUB_JWT_SECRET`.

## 8. Error handling

- Malformed JSON body → `400 bad_request`.
- Missing/invalid field types → `400 bad_request` with a message naming the field.
- Unknown routes → `404 not_found`.
- An unexpected exception in a handler → `500 internal` (logged to stderr; the response never leaks a stack trace).
- `bin/server.dart` creates the DB directory if missing and fails fast on an unreadable DB or an unset secret.

## 9. Testing

- `test/auth_test.dart`: `hashpw`/`checkpw` round-trip and rejection; `issueAccessToken`/`verifyToken` round-trip; an expired token is rejected; a refresh token fails access-token verification.
- `test/api_test.dart`: drives `api.dart`'s router directly with `shelf` `Request` objects and an in-memory SQLite (`:memory:`), asserting:
  - register → 201 and returns tokens; duplicate username → 409; short password / bad username → 400;
  - login success → 200; wrong password → 401;
  - a protected route without a token → 401; with a valid token → 200;
  - follows: `PUT` then `GET` returns it; `DELETE` removes it from `GET`; `sync?sinceSeq=0` includes it and a subsequent `sync` with the returned `nextSeq` does not;
  - a tombstone appears in `sync` output with `deleted: true`;
  - history: `PUT` then `GET` ordered by `watchedAt` desc; `DELETE /api/history` clears it; `sync` reflects both;
  - **LWW**: a `PUT` with an older `updatedAt` does not overwrite a newer stored value (both for follows and history);
  - isolation: user B cannot see user A's follows.
- Manual: `dart run bin/server.dart` then `curl` a register/login/follow round-trip.
- `dart analyze` and `dart test` inside `server/`.

## 10. Files

**New**
- `server/pubspec.yaml`
- `server/bin/server.dart`
- `server/lib/src/database.dart`
- `server/lib/src/auth.dart`
- `server/lib/src/api.dart`
- `server/test/auth_test.dart`
- `server/test/api_test.dart`
- `server/Dockerfile`

**Modified**
- `analysis_options.yaml` (exclude `server/**`)
- `.gitignore` (ignore `server/data/` and `server/.dart_tool/`)

## 11. Out of Scope

- Client-side account UI, token storage, the 追番 button and sync wiring (B2/B3).
- Email, email verification, password reset.
- Rate limiting, captcha, account deletion.
- HTTPS termination (a reverse proxy's job); the server speaks plain HTTP.
- Multi-device presence, sharing, or any social feature.
