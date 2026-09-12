# Account & Sync Backend Implementation Plan (B1)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A self-hosted Dart backend (`server/`) providing username/password accounts (JWT), a boolean follow list, watch history, and an incremental sync endpoint.

**Architecture:** A standalone Dart package using `shelf` + `shelf_router`, a `sqlite3` database layer, `bcrypt` password hashing and `dart_jsonwebtoken` JWTs. Handlers are plain functions driven by a router; tests drive the router directly with `shelf` `Request`s against an in-memory database, so no HTTP server is needed in tests.

**Tech Stack:** Dart 3.9, `shelf`, `shelf_router`, `sqlite3`, `bcrypt`, `dart_jsonwebtoken`, `test`.

## Global Constraints

- The backend is a **separate package** under `server/` with its own `pubspec.yaml`; it is not part of the Flutter app.
- The root `analysis_options.yaml` must exclude `server/**`; the root `.gitignore` must ignore `server/data/`.
- SQLite: `database.dart` must call `open.overrideFor(OperatingSystem.windows, () => DynamicLibrary.open('winsqlite3.dll'))` on Windows.
- Every row carries `client_updated_at` (client millis, LWW only) and `seq` (per-user monotonic counter, sync cursor only).
- LWW: an upsert whose `updatedAt` is **strictly less than** the stored `client_updated_at` is rejected and the stored row returned.
- Deletions are tombstones (`deleted = 1`) and bump `seq`.
- JWT: `HS256`, secret from env `ACGHUB_JWT_SECRET`; access `typ=access` 15 min, refresh `typ=refresh` 30 days.
- Errors: `{"error": "<code>", "message": "<text>"}` with codes `bad_request`(400), `unauthorized`(401), `not_found`(404), `conflict`(409), `internal`(500).
- All server commands run with `workdir` `D:\ACGNhub\server`. Dart is on PATH at `C:\flutter\bin`.
- Commit after every task.

---

### Task 1: `server/` package + database (users, seq)

**Files:**
- Create: `server/pubspec.yaml`
- Create: `server/lib/src/database.dart`
- Test: `server/test/database_test.dart`
- Modify: `analysis_options.yaml`, `.gitignore`

**Interfaces:**
- Produces: `class Database { static Database open(String path); void dispose(); int createUser(String username, String passwordHash); Row? findUserByName(String username); Row? findUserById(int id); int currentSeq(int userId); }` (follows/history queries come in Task 2).

- [ ] **Step 1: Create the package and add dependencies**

Create `server/pubspec.yaml`:

```yaml
name: acgnhub_server
description: ACGNhub account and sync backend
publish_to: none
version: 0.1.0

environment:
  sdk: ^3.6.0
```

Then run (in `server/`):

```
dart pub add shelf shelf_router sqlite3 bcrypt dart_jsonwebtoken
dart pub add dev:test
```

Expected: `Changed N dependencies!` and a `server/pubspec.lock`.

- [ ] **Step 2: Exclude `server/**` from the Flutter analyzer and ignore the DB**

In the root `analysis_options.yaml`, add at the top level (after the `include:` line):

```yaml
analyzer:
  exclude:
    - server/**
```

In the root `.gitignore`, add:

```
# Backend runtime data
/server/data/
```

- [ ] **Step 3: Write the failing test**

Create `server/test/database_test.dart`:

```dart
import 'package:acgnhub_server/src/database.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  late Database db;

  setUp(() => db = Database.open(':memory:'));
  tearDown(() => db.dispose());

  test('creates a user and finds it by name and id', () {
    final id = db.createUser('alice', 'hash');
    expect(id, greaterThan(0));
    expect(db.findUserByName('alice')!['username'], 'alice');
    expect(db.findUserById(id)!['username'], 'alice');
    expect(db.findUserByName('nobody'), isNull);
  });

  test('rejects a duplicate username', () {
    db.createUser('alice', 'hash');
    expect(() => db.createUser('alice', 'other'), throwsA(isA<SqliteException>()));
  });

  test('currentSeq starts at 0 and follows the counter', () {
    final id = db.createUser('alice', 'hash');
    expect(db.currentSeq(id), 0);
  });
}
```

- [ ] **Step 4: Run the test to verify it fails**

Run (workdir `server/`): `dart test test/database_test.dart`
Expected: FAIL — `database.dart` not found.

- [ ] **Step 5: Create `server/lib/src/database.dart`**

```dart
import 'dart:ffi';
import 'dart:io';

import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

class Database {
  Database._(this._db);

  final sqlite3.Database _db;

  static Database open(String path) {
    if (Platform.isWindows) {
      open.overrideFor(
          OperatingSystem.windows, () => DynamicLibrary.open('winsqlite3.dll'));
    }
    final db = sqlite3.open(path);
    _migrate(db);
    return Database._(db);
  }

  static void _migrate(sqlite3.Database db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        username      TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        next_seq      INTEGER NOT NULL DEFAULT 0,
        created_at    INTEGER NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS follows (
        user_id           INTEGER NOT NULL,
        work_id           TEXT NOT NULL,
        work_json         TEXT NOT NULL,
        client_updated_at INTEGER NOT NULL,
        seq               INTEGER NOT NULL,
        deleted           INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (user_id, work_id)
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS history (
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
    ''');
  }

  void dispose() => _db.dispose();

  int createUser(String username, String passwordHash) {
    _db.execute(
      'INSERT INTO users (username, password_hash, created_at) VALUES (?, ?, ?)',
      [username, passwordHash, DateTime.now().millisecondsSinceEpoch],
    );
    return _db.lastInsertRowId;
  }

  Row? findUserByName(String username) {
    final rows = _db.select(
        'SELECT * FROM users WHERE username = ? LIMIT 1', [username]);
    return rows.isEmpty ? null : rows.first;
  }

  Row? findUserById(int id) {
    final rows = _db.select('SELECT * FROM users WHERE id = ? LIMIT 1', [id]);
    return rows.isEmpty ? null : rows.first;
  }

  int currentSeq(int userId) {
    final rows =
        _db.select('SELECT next_seq FROM users WHERE id = ?', [userId]);
    return rows.isEmpty ? 0 : rows.first['next_seq'] as int;
  }

  int _bumpSeq(int userId) {
    _db.execute('UPDATE users SET next_seq = next_seq + 1 WHERE id = ?', [userId]);
    return currentSeq(userId);
  }
}
```

- [ ] **Step 6: Run the test to verify it passes**

Run (workdir `server/`): `dart test test/database_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 7: Analyze**

Run (workdir `server/`): `dart analyze`
Expected: `No issues found!`
Run (repo root): `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!` (the server is excluded)

- [ ] **Step 8: Commit**

```bash
git add server/pubspec.yaml server/pubspec.lock server/lib/src/database.dart server/test/database_test.dart analysis_options.yaml .gitignore
git commit -m "feat(server): add the backend package and database user layer"
```

---

### Task 2: Database follows + history queries

**Files:**
- Modify: `server/lib/src/database.dart`
- Modify: `server/test/database_test.dart`

**Interfaces:**
- Consumes: `Database.open`, `createUser` (Task 1).
- Produces: `Row? getFollow(int userId, String workId)`; `Row upsertFollow({required int userId, required String workId, required Map<String, dynamic> work, required int updatedAt, bool deleted})`; `List<Row> listFollows(int userId)`; `List<Row> followsSince(int userId, int sinceSeq)`; and the same four for history (`getHistory`, `upsertHistory`, `listHistory`, `historySince`) plus `int clearHistory(int userId, int updatedAt)`.

- [ ] **Step 1: Add the failing tests**

Append to `server/test/database_test.dart` (inside `main`, after the existing tests):

```dart
  test('upsertFollow stores and lists, and delete tombstones it', () {
    final id = db.createUser('alice', 'hash');
    db.upsertFollow(
        userId: id, workId: 'w1', work: {'id': 'w1', 'title': 'A'}, updatedAt: 100);
    db.upsertFollow(
        userId: id, workId: 'w2', work: {'id': 'w2', 'title': 'B'}, updatedAt: 200);

    expect(db.listFollows(id).map((r) => r['work_id']).toList(), ['w2', 'w1']);

    db.upsertFollow(
        userId: id, workId: 'w1', work: {'id': 'w1'}, updatedAt: 300, deleted: true);
    expect(db.listFollows(id).map((r) => r['work_id']).toList(), ['w2']);
  });

  test('upsertFollow keeps the newer row on an older write (LWW)', () {
    final id = db.createUser('alice', 'hash');
    db.upsertFollow(
        userId: id, workId: 'w1', work: {'id': 'w1', 'title': 'new'}, updatedAt: 200);
    final stored = db.upsertFollow(
        userId: id, workId: 'w1', work: {'id': 'w1', 'title': 'old'}, updatedAt: 100);

    expect(stored['client_updated_at'], 200);
    expect(stored['work_json'], contains('new'));
    expect(db.currentSeq(id), 1);
  });

  test('followsSince returns rows whose seq is greater, including tombstones', () {
    final id = db.createUser('alice', 'hash');
    db.upsertFollow(userId: id, workId: 'w1', work: {'id': 'w1'}, updatedAt: 100);
    final afterFirst = db.currentSeq(id);
    db.upsertFollow(
        userId: id, workId: 'w1', work: {'id': 'w1'}, updatedAt: 200, deleted: true);

    expect(db.followsSince(id, 0), hasLength(1));
    final delta = db.followsSince(id, afterFirst);
    expect(delta, hasLength(1));
    expect(delta.first['deleted'], 1);
  });

  test('upsertHistory stores and lists by watchedAt desc; clearHistory empties', () {
    final id = db.createUser('alice', 'hash');
    db.upsertHistory(
        userId: id, workId: 'w1', work: {'id': 'w1'}, episodeTitle: '第1集',
        episodeIndex: 0, watchedAt: 100, updatedAt: 100);
    db.upsertHistory(
        userId: id, workId: 'w2', work: {'id': 'w2'}, episodeTitle: '第9集',
        episodeIndex: 8, watchedAt: 300, updatedAt: 300);

    expect(db.listHistory(id).map((r) => r['work_id']).toList(), ['w2', 'w1']);
    expect(db.historySince(id, 0), hasLength(2));

    final cleared = db.clearHistory(id, 400);
    expect(cleared, 2);
    expect(db.listHistory(id), isEmpty);
    expect(db.historySince(id, 0).every((r) => r['deleted'] == 1), isTrue);
  });

  test('upsertHistory keeps the newer row on an older write (LWW)', () {
    final id = db.createUser('alice', 'hash');
    db.upsertHistory(
        userId: id, workId: 'w1', work: {'id': 'w1'}, episodeTitle: '第5集',
        episodeIndex: 4, watchedAt: 200, updatedAt: 200);
    final stored = db.upsertHistory(
        userId: id, workId: 'w1', work: {'id': 'w1'}, episodeTitle: '第1集',
        episodeIndex: 0, watchedAt: 100, updatedAt: 100);

    expect(stored['episode_title'], '第5集');
    expect(stored['client_updated_at'], 200);
  });

  test('rows are scoped per user', () {
    final a = db.createUser('alice', 'hash');
    final b = db.createUser('bob', 'hash');
    db.upsertFollow(userId: a, workId: 'w1', work: {'id': 'w1'}, updatedAt: 100);
    expect(db.listFollows(a), hasLength(1));
    expect(db.listFollows(b), isEmpty);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run (workdir `server/`): `dart test test/database_test.dart`
Expected: FAIL — `upsertFollow` is not defined.

- [ ] **Step 3: Add the queries to `server/lib/src/database.dart`**

Add inside `class Database` (after `_bumpSeq`):

```dart
  Row? getFollow(int userId, String workId) {
    final rows = _db.select(
        'SELECT * FROM follows WHERE user_id = ? AND work_id = ? LIMIT 1',
        [userId, workId]);
    return rows.isEmpty ? null : rows.first;
  }

  Row upsertFollow({
    required int userId,
    required String workId,
    required Map<String, dynamic> work,
    required int updatedAt,
    bool deleted = false,
  }) {
    final existing = getFollow(userId, workId);
    if (existing != null && (existing['client_updated_at'] as int) > updatedAt) {
      return existing;
    }
    final seq = _bumpSeq(userId);
    final json = jsonEncode(work);
    if (existing == null) {
      _db.execute(
        'INSERT INTO follows (user_id, work_id, work_json, client_updated_at, seq, deleted) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        [userId, workId, json, updatedAt, seq, deleted ? 1 : 0],
      );
    } else {
      _db.execute(
        'UPDATE follows SET work_json = ?, client_updated_at = ?, seq = ?, deleted = ? '
        'WHERE user_id = ? AND work_id = ?',
        [json, updatedAt, seq, deleted ? 1 : 0, userId, workId],
      );
    }
    return getFollow(userId, workId)!;
  }

  List<Row> listFollows(int userId) => _db.select(
      'SELECT * FROM follows WHERE user_id = ? AND deleted = 0 '
      'ORDER BY client_updated_at DESC',
      [userId]);

  List<Row> followsSince(int userId, int sinceSeq) => _db.select(
      'SELECT * FROM follows WHERE user_id = ? AND seq > ? ORDER BY seq',
      [userId, sinceSeq]);

  Row? getHistory(int userId, String workId) {
    final rows = _db.select(
        'SELECT * FROM history WHERE user_id = ? AND work_id = ? LIMIT 1',
        [userId, workId]);
    return rows.isEmpty ? null : rows.first;
  }

  Row upsertHistory({
    required int userId,
    required String workId,
    required Map<String, dynamic> work,
    required String episodeTitle,
    required int episodeIndex,
    required int watchedAt,
    required int updatedAt,
    bool deleted = false,
  }) {
    final existing = getHistory(userId, workId);
    if (existing != null && (existing['client_updated_at'] as int) > updatedAt) {
      return existing;
    }
    final seq = _bumpSeq(userId);
    final json = jsonEncode(work);
    if (existing == null) {
      _db.execute(
        'INSERT INTO history (user_id, work_id, work_json, episode_title, episode_index, '
        'watched_at, client_updated_at, seq, deleted) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [userId, workId, json, episodeTitle, episodeIndex, watchedAt, updatedAt, seq,
         deleted ? 1 : 0],
      );
    } else {
      _db.execute(
        'UPDATE history SET work_json = ?, episode_title = ?, episode_index = ?, watched_at = ?, '
        'client_updated_at = ?, seq = ?, deleted = ? WHERE user_id = ? AND work_id = ?',
        [json, episodeTitle, episodeIndex, watchedAt, updatedAt, seq, deleted ? 1 : 0,
         userId, workId],
      );
    }
    return getHistory(userId, workId)!;
  }

  List<Row> listHistory(int userId) => _db.select(
      'SELECT * FROM history WHERE user_id = ? AND deleted = 0 ORDER BY watched_at DESC',
      [userId]);

  List<Row> historySince(int userId, int sinceSeq) => _db.select(
      'SELECT * FROM history WHERE user_id = ? AND seq > ? ORDER BY seq',
      [userId, sinceSeq]);

  int clearHistory(int userId, int updatedAt) {
    final rows = _db.select(
        'SELECT work_id FROM history WHERE user_id = ? AND deleted = 0', [userId]);
    for (final row in rows) {
      upsertHistory(
        userId: userId,
        workId: row['work_id'] as String,
        work: const {},
        episodeTitle: '',
        episodeIndex: 0,
        watchedAt: 0,
        updatedAt: updatedAt,
        deleted: true,
      );
    }
    return rows.length;
  }
```

Add `import 'dart:convert';` at the top of the file.

Note: `clearHistory` reuses `upsertHistory` with `work: const {}` — for a tombstone the payload does not matter, and the client only reads `deleted`.

- [ ] **Step 4: Run the tests to verify they pass**

Run (workdir `server/`): `dart test test/database_test.dart`
Expected: PASS (9 tests).

- [ ] **Step 5: Analyze**

Run (workdir `server/`): `dart analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add server/lib/src/database.dart server/test/database_test.dart
git commit -m "feat(server): add follow and history queries with LWW and tombstones"
```

---

### Task 3: Auth primitives (bcrypt + JWT)

**Files:**
- Create: `server/lib/src/auth.dart`
- Test: `server/test/auth_test.dart`

**Interfaces:**
- Produces: `class Auth { Auth(String secret); String hashPassword(String password); bool verifyPassword(String password, String hash); String issueAccessToken(int userId); String issueRefreshToken(int userId); int? verifyToken(String token, {String type}); }`

- [ ] **Step 1: Write the failing test**

Create `server/test/auth_test.dart`:

```dart
import 'package:acgnhub_server/src/auth.dart';
import 'package:test/test.dart';

void main() {
  final auth = Auth('test-secret');

  test('hashes and verifies a password', () {
    final hash = auth.hashPassword('hunter2');
    expect(hash, isNot('hunter2'));
    expect(auth.verifyPassword('hunter2', hash), isTrue);
    expect(auth.verifyPassword('wrong', hash), isFalse);
  });

  test('verifyPassword returns false for a malformed hash', () {
    expect(auth.verifyPassword('x', 'not-a-hash'), isFalse);
  });

  test('issues and verifies an access token', () {
    final token = auth.issueAccessToken(42);
    expect(auth.verifyToken(token), 42);
  });

  test('a refresh token is not accepted as an access token', () {
    final refresh = auth.issueRefreshToken(42);
    expect(auth.verifyToken(refresh), isNull);
    expect(auth.verifyToken(refresh, type: 'refresh'), 42);
  });

  test('rejects a token signed with another secret', () {
    final other = Auth('other-secret');
    expect(auth.verifyToken(other.issueAccessToken(42)), isNull);
  });

  test('rejects a malformed token', () {
    expect(auth.verifyToken('not.a.jwt'), isNull);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run (workdir `server/`): `dart test test/auth_test.dart`
Expected: FAIL — `auth.dart` not found.

- [ ] **Step 3: Create `server/lib/src/auth.dart`**

```dart
import 'package:bcrypt/bcrypt.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class Auth {
  Auth(this.secret);

  final String secret;

  static const accessTtl = Duration(minutes: 15);
  static const refreshTtl = Duration(days: 30);

  String hashPassword(String password) =>
      BCrypt.hashpw(password, BCrypt.gensalt());

  bool verifyPassword(String password, String hash) {
    try {
      return BCrypt.checkpw(password, hash);
    } catch (_) {
      return false;
    }
  }

  String issueAccessToken(int userId) => _issue(userId, 'access', accessTtl);

  String issueRefreshToken(int userId) => _issue(userId, 'refresh', refreshTtl);

  String _issue(int userId, String typ, Duration ttl) {
    final jwt = JWT({
      'sub': userId,
      'typ': typ,
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    });
    return jwt.sign(SecretKey(secret), expiresIn: ttl);
  }

  /// Returns the token's user id, or `null` when the token is malformed,
  /// expired, signed with another secret, or of the wrong [type].
  int? verifyToken(String token, {String type = 'access'}) {
    try {
      final payload =
          JWT.verify(token, SecretKey(secret)).payload as Map<String, dynamic>;
      if (payload['typ'] != type) return null;
      final sub = payload['sub'];
      if (sub is int) return sub;
      return int.tryParse('$sub');
    } catch (_) {
      return null;
    }
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run (workdir `server/`): `dart test test/auth_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Analyze**

Run (workdir `server/`): `dart analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add server/lib/src/auth.dart server/test/auth_test.dart
git commit -m "feat(server): add bcrypt hashing and JWT issuing/verification"
```

---

### Task 4: API — auth routes

**Files:**
- Create: `server/lib/src/api.dart`
- Test: `server/test/api_test.dart`

**Interfaces:**
- Consumes: `Database` (Tasks 1–2), `Auth` (Task 3).
- Produces: `class Api { Api(Database db, Auth auth); Handler get handler; }` plus `@visibleForTesting static const jsonHeaders`.

- [ ] **Step 1: Write the failing test**

Create `server/test/api_test.dart`:

```dart
import 'dart:convert';

import 'package:acgnhub_server/src/api.dart';
import 'package:acgnhub_server/src/auth.dart';
import 'package:acgnhub_server/src/database.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late Database db;
  late Api api;

  setUp(() {
    db = Database.open(':memory:');
    api = Api(db, Auth('test-secret'));
  });
  tearDown(() => db.dispose());

  Future<Response> call(String method, String path,
      {Object? body, String? token}) {
    return Future.value(api.handler(Request(
      method,
      Uri.parse('http://localhost$path'),
      body: body == null ? null : jsonEncode(body),
      headers: {
        if (body != null) 'content-type': 'application/json',
        if (token != null) 'authorization': 'Bearer $token',
      },
    )));
  }

  Future<Map<String, dynamic>> jsonOf(Response res) async =>
      jsonDecode(await res.readAsString()) as Map<String, dynamic>;

  test('register returns tokens and the user', () async {
    final res = await call('POST', '/api/auth/register',
        body: {'username': 'alice', 'password': 'secret1'});
    expect(res.statusCode, 201);
    final json = await jsonOf(res);
    expect(json['user'], {'id': 1, 'username': 'alice'});
    expect(json['token'], isA<String>());
    expect(json['refreshToken'], isA<String>());
  });

  test('register rejects a duplicate username with 409', () async {
    await call('POST', '/api/auth/register',
        body: {'username': 'alice', 'password': 'secret1'});
    final res = await call('POST', '/api/auth/register',
        body: {'username': 'alice', 'password': 'secret1'});
    expect(res.statusCode, 409);
    expect((await jsonOf(res))['error'], 'conflict');
  });

  test('register validates username and password with 400', () async {
    final short = await call('POST', '/api/auth/register',
        body: {'username': 'ab', 'password': 'secret1'});
    expect(short.statusCode, 400);
    final badChars = await call('POST', '/api/auth/register',
        body: {'username': 'a b', 'password': 'secret1'});
    expect(badChars.statusCode, 400);
    final shortPw = await call('POST', '/api/auth/register',
        body: {'username': 'alice', 'password': '123'});
    expect(shortPw.statusCode, 400);
  });

  test('login succeeds and rejects a wrong password', () async {
    await call('POST', '/api/auth/register',
        body: {'username': 'alice', 'password': 'secret1'});
    final ok = await call('POST', '/api/auth/login',
        body: {'username': 'alice', 'password': 'secret1'});
    expect(ok.statusCode, 200);
    final bad = await call('POST', '/api/auth/login',
        body: {'username': 'alice', 'password': 'nope'});
    expect(bad.statusCode, 401);
  });

  test('refresh issues a new access token', () async {
    final reg = await jsonOf(await call('POST', '/api/auth/register',
        body: {'username': 'alice', 'password': 'secret1'}));
    final res = await call('POST', '/api/auth/refresh',
        body: {'refreshToken': reg['refreshToken']});
    expect(res.statusCode, 200);
    final token = (await jsonOf(res))['token'] as String;
    expect(api.auth.verifyToken(token), 1);
  });

  test('protected routes reject a missing or invalid token', () async {
    expect((await call('GET', '/api/me')).statusCode, 401);
    expect((await call('GET', '/api/me', token: 'garbage')).statusCode, 401);
  });

  test('me returns the current user', () async {
    final reg = await jsonOf(await call('POST', '/api/auth/register',
        body: {'username': 'alice', 'password': 'secret1'}));
    final res = await call('GET', '/api/me', token: reg['token'] as String);
    expect(res.statusCode, 200);
    expect(await jsonOf(res), {'id': 1, 'username': 'alice'});
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run (workdir `server/`): `dart test test/api_test.dart`
Expected: FAIL — `api.dart` not found.

- [ ] **Step 3: Create `server/lib/src/api.dart`**

```dart
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'auth.dart';
import 'database.dart';

class Api {
  Api(this.db, this.auth);

  final Database db;
  final Auth auth;

  static final _usernameRe = RegExp(r'^[A-Za-z0-9_-]{3,32}$');

  Handler get handler {
    final router = Router()
      ..post('/api/auth/register', _register)
      ..post('/api/auth/login', _login)
      ..post('/api/auth/refresh', _refresh)
      ..get('/api/me', _auth(_me));
    return Pipeline().addHandler(_guard(router.call));
  }

  Response _json(int status, Object body) => Response(
        status,
        body: jsonEncode(body),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  Response _error(int status, String code, String message) =>
      _json(status, {'error': code, 'message': message});

  Future<Map<String, dynamic>?> _readJson(Request req) async {
    try {
      final decoded = jsonDecode(await req.readAsString());
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Converts an unexpected exception into a 500 without leaking details.
  Handler _guard(Handler inner) {
    return (Request req) async {
      try {
        return await inner(req);
      } catch (e, st) {
        // ignore: avoid_print
        print('Unhandled error on ${req.method} ${req.requestedUri.path}: $e\n$st');
        return _error(500, 'internal', 'Internal server error');
      }
    };
  }

  /// Requires a valid access token and injects the user id into the context.
  Future<Response> Function(Request) _auth(
      Future<Response> Function(Request) inner) {
    return (Request req) async {
      final userId = _userId(req);
      if (userId == null) {
        return _error(401, 'unauthorized', 'Missing or invalid token');
      }
      return inner(req.change(context: {'userId': userId}));
    };
  }

  int? _userId(Request req) {
    final header = req.headers['authorization'];
    if (header == null || !header.startsWith('Bearer ')) return null;
    return auth.verifyToken(header.substring(7));
  }

  int _ctxUserId(Request req) => req.context['userId'] as int;

  Future<Response> _register(Request req) async {
    final body = await _readJson(req);
    if (body == null) return _error(400, 'bad_request', 'Expected a JSON object');

    final username = body['username'];
    final password = body['password'];
    if (username is! String || !_usernameRe.hasMatch(username)) {
      return _error(400, 'bad_request',
          'username must be 3-32 characters of A-Z a-z 0-9 _ -');
    }
    if (password is! String || password.length < 6) {
      return _error(400, 'bad_request', 'password must be at least 6 characters');
    }
    if (db.findUserByName(username) != null) {
      return _error(409, 'conflict', 'Username already taken');
    }

    final id = db.createUser(username, auth.hashPassword(password));
    return _json(201, {
      'token': auth.issueAccessToken(id),
      'refreshToken': auth.issueRefreshToken(id),
      'user': {'id': id, 'username': username},
    });
  }

  Future<Response> _login(Request req) async {
    final body = await _readJson(req);
    if (body == null) return _error(400, 'bad_request', 'Expected a JSON object');

    final username = body['username'];
    final password = body['password'];
    if (username is! String || password is! String) {
      return _error(400, 'bad_request', 'username and password are required');
    }

    final user = db.findUserByName(username);
    if (user == null ||
        !auth.verifyPassword(password, user['password_hash'] as String)) {
      return _error(401, 'unauthorized', 'Invalid username or password');
    }

    final id = user['id'] as int;
    return _json(200, {
      'token': auth.issueAccessToken(id),
      'refreshToken': auth.issueRefreshToken(id),
      'user': {'id': id, 'username': user['username']},
    });
  }

  Future<Response> _refresh(Request req) async {
    final body = await _readJson(req);
    if (body == null) return _error(400, 'bad_request', 'Expected a JSON object');

    final refreshToken = body['refreshToken'];
    if (refreshToken is! String) {
      return _error(400, 'bad_request', 'refreshToken is required');
    }
    final userId = auth.verifyToken(refreshToken, type: 'refresh');
    if (userId == null) {
      return _error(401, 'unauthorized', 'Invalid or expired refresh token');
    }
    return _json(200, {'token': auth.issueAccessToken(userId)});
  }

  Future<Response> _me(Request req) async {
    final user = db.findUserById(_ctxUserId(req));
    if (user == null) return _error(401, 'unauthorized', 'Unknown user');
    return _json(200, {'id': user['id'], 'username': user['username']});
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run (workdir `server/`): `dart test test/api_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Analyze**

Run (workdir `server/`): `dart analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add server/lib/src/api.dart server/test/api_test.dart
git commit -m "feat(server): add register, login, refresh and me routes"
```

---

### Task 5: API — follows + history routes

**Files:**
- Modify: `server/lib/src/api.dart`
- Modify: `server/test/api_test.dart`

**Interfaces:**
- Consumes: `Database.upsertFollow`/`listFollows`/`upsertHistory`/`listHistory`/`clearHistory` (Task 2); `_auth`/`_json`/`_error`/`_readJson`/`_ctxUserId` (Task 4).
- Produces: routes `GET/PUT/DELETE /api/follows[...]` and `GET/PUT/DELETE /api/history`.

- [ ] **Step 1: Add the failing tests**

Append to `server/test/api_test.dart` (inside `main`; add a helper that registers and returns the token):

```dart
  Future<String> registerToken(String username) async {
    final json = await jsonOf(await call('POST', '/api/auth/register',
        body: {'username': username, 'password': 'secret1'}));
    return json['token'] as String;
  }

  test('follows: put, list, delete', () async {
    final token = await registerToken('alice');
    final put = await call('PUT', '/api/follows',
        token: token,
        body: {
          'work': {'id': 'w1', 'title': 'A'},
          'updatedAt': 100,
        });
    expect(put.statusCode, 200);

    final list = await jsonOf(await call('GET', '/api/follows', token: token));
    expect((list['items'] as List), hasLength(1));
    expect((list['items'] as List).first['work']['id'], 'w1');

    final del = await call('DELETE', '/api/follows/w1?updatedAt=200', token: token);
    expect(del.statusCode, 200);
    final after = await jsonOf(await call('GET', '/api/follows', token: token));
    expect(after['items'], isEmpty);
  });

  test('follows: an older put does not overwrite a newer one (LWW)', () async {
    final token = await registerToken('alice');
    await call('PUT', '/api/follows',
        token: token, body: {'work': {'id': 'w1', 'title': 'new'}, 'updatedAt': 200});
    final stale = await jsonOf(await call('PUT', '/api/follows',
        token: token, body: {'work': {'id': 'w1', 'title': 'old'}, 'updatedAt': 100}));
    expect(stale['work']['title'], 'new');
    expect(stale['updatedAt'], 200);
  });

  test('history: put, list by watchedAt desc, clear', () async {
    final token = await registerToken('alice');
    await call('PUT', '/api/history', token: token, body: {
      'work': {'id': 'w1'}, 'episodeTitle': '第1集', 'episodeIndex': 0,
      'watchedAt': 100, 'updatedAt': 100,
    });
    await call('PUT', '/api/history', token: token, body: {
      'work': {'id': 'w2'}, 'episodeTitle': '第9集', 'episodeIndex': 8,
      'watchedAt': 300, 'updatedAt': 300,
    });

    final list = await jsonOf(await call('GET', '/api/history', token: token));
    final items = list['items'] as List;
    expect(items.map((e) => e['work']['id']).toList(), ['w2', 'w1']);
    expect(items.first['episodeTitle'], '第9集');

    final cleared = await call('DELETE', '/api/history?updatedAt=400', token: token);
    expect(cleared.statusCode, 200);
    expect((await jsonOf(await call('GET', '/api/history', token: token)))['items'],
        isEmpty);
  });

  test('follows and history reject a missing body field with 400', () async {
    final token = await registerToken('alice');
    expect((await call('PUT', '/api/follows',
            token: token, body: {'updatedAt': 1}))
        .statusCode, 400);
    expect((await call('PUT', '/api/history',
            token: token, body: {'work': {'id': 'w1'}}))
        .statusCode, 400);
  });

  test('one user cannot see another user\'s follows', () async {
    final a = await registerToken('alice');
    final b = await registerToken('bob');
    await call('PUT', '/api/follows',
        token: a, body: {'work': {'id': 'w1'}, 'updatedAt': 1});
    final list = await jsonOf(await call('GET', '/api/follows', token: b));
    expect(list['items'], isEmpty);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run (workdir `server/`): `dart test test/api_test.dart`
Expected: FAIL — the `/api/follows` routes 404.

- [ ] **Step 3: Add the routes and handlers to `server/lib/src/api.dart`**

In `handler`, add before `..get('/api/me', ...)`:

```dart
      ..get('/api/follows', _auth(_listFollows))
      ..put('/api/follows', _auth(_putFollow))
      ..delete('/api/follows/<workId>', _deleteFollowRoute)
      ..get('/api/history', _auth(_listHistory))
      ..put('/api/history', _auth(_putHistory))
      ..delete('/api/history', _auth(_clearHistory))
```

Add these handlers (before the closing brace of `class Api`):

```dart
  /// `shelf_router` passes the path parameter as a second argument.
  Future<Response> _deleteFollowRoute(Request req, String workId) =>
      _auth((r) => _deleteFollow(r, workId))(req);

  Future<Response> _listFollows(Request req) async {
    final items = db.listFollows(_ctxUserId(req)).map((row) {
      return {
        'work': jsonDecode(row['work_json'] as String),
        'updatedAt': row['client_updated_at'],
      };
    }).toList();
    return _json(200, {'items': items});
  }

  Future<Response> _putFollow(Request req) async {
    final body = await _readJson(req);
    if (body == null) return _error(400, 'bad_request', 'Expected a JSON object');
    final work = body['work'];
    final updatedAt = body['updatedAt'];
    if (work is! Map<String, dynamic> || work['id'] is! String) {
      return _error(400, 'bad_request', 'work.id is required');
    }
    if (updatedAt is! int) {
      return _error(400, 'bad_request', 'updatedAt must be an integer');
    }
    final row = db.upsertFollow(
      userId: _ctxUserId(req),
      workId: work['id'] as String,
      work: work,
      updatedAt: updatedAt,
    );
    return _json(200, {
      'work': jsonDecode(row['work_json'] as String),
      'updatedAt': row['client_updated_at'],
    });
  }

  Future<Response> _deleteFollow(Request req, String workId) async {
    final updatedAt =
        int.tryParse(req.url.queryParameters['updatedAt'] ?? '');
    if (updatedAt == null) {
      return _error(400, 'bad_request', 'updatedAt query parameter is required');
    }
    final row = db.upsertFollow(
      userId: _ctxUserId(req),
      workId: workId,
      work: const {},
      updatedAt: updatedAt,
      deleted: true,
    );
    return _json(200, {'workId': workId, 'updatedAt': row['client_updated_at']});
  }

  Future<Response> _listHistory(Request req) async {
    final items = db.listHistory(_ctxUserId(req)).map((row) {
      return {
        'work': jsonDecode(row['work_json'] as String),
        'episodeTitle': row['episode_title'],
        'episodeIndex': row['episode_index'],
        'watchedAt': row['watched_at'],
        'updatedAt': row['client_updated_at'],
      };
    }).toList();
    return _json(200, {'items': items});
  }

  Future<Response> _putHistory(Request req) async {
    final body = await _readJson(req);
    if (body == null) return _error(400, 'bad_request', 'Expected a JSON object');
    final work = body['work'];
    final episodeTitle = body['episodeTitle'];
    final episodeIndex = body['episodeIndex'];
    final watchedAt = body['watchedAt'];
    final updatedAt = body['updatedAt'];
    if (work is! Map<String, dynamic> || work['id'] is! String) {
      return _error(400, 'bad_request', 'work.id is required');
    }
    if (episodeTitle is! String ||
        episodeIndex is! int ||
        watchedAt is! int ||
        updatedAt is! int) {
      return _error(400, 'bad_request',
          'episodeTitle, episodeIndex, watchedAt and updatedAt are required');
    }
    final row = db.upsertHistory(
      userId: _ctxUserId(req),
      workId: work['id'] as String,
      work: work,
      episodeTitle: episodeTitle,
      episodeIndex: episodeIndex,
      watchedAt: watchedAt,
      updatedAt: updatedAt,
    );
    return _json(200, {
      'work': jsonDecode(row['work_json'] as String),
      'episodeTitle': row['episode_title'],
      'episodeIndex': row['episode_index'],
      'watchedAt': row['watched_at'],
      'updatedAt': row['client_updated_at'],
    });
  }

  Future<Response> _clearHistory(Request req) async {
    final updatedAt = int.tryParse(req.url.queryParameters['updatedAt'] ?? '');
    if (updatedAt == null) {
      return _error(400, 'bad_request', 'updatedAt query parameter is required');
    }
    final count = db.clearHistory(_ctxUserId(req), updatedAt);
    return _json(200, {'deleted': count});
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run (workdir `server/`): `dart test test/api_test.dart`
Expected: PASS (12 tests).

- [ ] **Step 5: Analyze**

Run (workdir `server/`): `dart analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add server/lib/src/api.dart server/test/api_test.dart
git commit -m "feat(server): add follow and history routes"
```

---

### Task 6: API — sync route

**Files:**
- Modify: `server/lib/src/api.dart`
- Modify: `server/test/api_test.dart`

**Interfaces:**
- Consumes: `Database.followsSince`/`historySince`/`currentSeq` (Task 2).
- Produces: `GET /api/sync?sinceSeq=<n>` → `{"follows": [...], "history": [...], "nextSeq": <n>}` where each item carries `deleted`.

- [ ] **Step 1: Add the failing tests**

Append to `server/test/api_test.dart` (inside `main`):

```dart
  test('sync returns changes after the given seq and a nextSeq cursor', () async {
    final token = await registerToken('alice');
    await call('PUT', '/api/follows',
        token: token, body: {'work': {'id': 'w1'}, 'updatedAt': 100});

    final first = await jsonOf(await call('GET', '/api/sync?sinceSeq=0', token: token));
    expect((first['follows'] as List), hasLength(1));
    expect((first['follows'] as List).first['deleted'], false);
    final next = first['nextSeq'] as int;
    expect(next, greaterThan(0));

    final second =
        await jsonOf(await call('GET', '/api/sync?sinceSeq=$next', token: token));
    expect(second['follows'], isEmpty);
    expect(second['history'], isEmpty);
  });

  test('sync surfaces tombstones with deleted true', () async {
    final token = await registerToken('alice');
    await call('PUT', '/api/follows',
        token: token, body: {'work': {'id': 'w1'}, 'updatedAt': 100});
    await call('DELETE', '/api/follows/w1?updatedAt=200', token: token);

    final sync = await jsonOf(await call('GET', '/api/sync?sinceSeq=0', token: token));
    final follows = sync['follows'] as List;
    expect(follows, hasLength(1));
    expect(follows.first['deleted'], true);
    expect(follows.first['work']['id'], 'w1');
  });

  test('sync includes history with its fields', () async {
    final token = await registerToken('alice');
    await call('PUT', '/api/history', token: token, body: {
      'work': {'id': 'w1'}, 'episodeTitle': '第3集', 'episodeIndex': 2,
      'watchedAt': 100, 'updatedAt': 100,
    });
    final sync = await jsonOf(await call('GET', '/api/sync?sinceSeq=0', token: token));
    final history = sync['history'] as List;
    expect(history, hasLength(1));
    expect(history.first['episodeTitle'], '第3集');
    expect(history.first['deleted'], false);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run (workdir `server/`): `dart test test/api_test.dart`
Expected: FAIL — `/api/sync` 404s.

- [ ] **Step 3: Add the sync route and handler to `server/lib/src/api.dart`**

In `handler`, add after the history routes:

```dart
      ..get('/api/sync', _auth(_sync))
```

Add the handler (before the closing brace of `class Api`):

```dart
  Future<Response> _sync(Request req) async {
    final userId = _ctxUserId(req);
    final sinceSeq = int.tryParse(req.url.queryParameters['sinceSeq'] ?? '0') ?? 0;

    final follows = db.followsSince(userId, sinceSeq).map((row) {
      return {
        'work': jsonDecode(row['work_json'] as String),
        'updatedAt': row['client_updated_at'],
        'deleted': (row['deleted'] as int) == 1,
      };
    }).toList();

    final history = db.historySince(userId, sinceSeq).map((row) {
      return {
        'work': jsonDecode(row['work_json'] as String),
        'episodeTitle': row['episode_title'],
        'episodeIndex': row['episode_index'],
        'watchedAt': row['watched_at'],
        'updatedAt': row['client_updated_at'],
        'deleted': (row['deleted'] as int) == 1,
      };
    }).toList();

    return _json(200, {
      'follows': follows,
      'history': history,
      'nextSeq': db.currentSeq(userId),
    });
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run (workdir `server/`): `dart test test/api_test.dart`
Expected: PASS (15 tests).

- [ ] **Step 5: Analyze**

Run (workdir `server/`): `dart analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add server/lib/src/api.dart server/test/api_test.dart
git commit -m "feat(server): add the incremental sync route"
```

---

### Task 7: Entrypoint, Docker, and manual smoke

**Files:**
- Create: `server/bin/server.dart`
- Create: `server/Dockerfile`

**Interfaces:**
- Consumes: `Database.open`, `Auth`, `Api.handler`.
- Produces: a runnable server reading `ACGHUB_JWT_SECRET`, `PORT`, `ACGHUB_DB_PATH`.

- [ ] **Step 1: Create `server/bin/server.dart`**

```dart
import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:acgnhub_server/src/api.dart';
import 'package:acgnhub_server/src/auth.dart';
import 'package:acgnhub_server/src/database.dart';

Future<void> main() async {
  final secret = Platform.environment['ACGHUB_JWT_SECRET'];
  if (secret == null || secret.isEmpty) {
    stderr.writeln('ACGHUB_JWT_SECRET is required');
    exit(1);
  }
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final dbPath = Platform.environment['ACGHUB_DB_PATH'] ?? 'data/acgnhub.db';

  final dir = Directory(File(dbPath).parent.path);
  if (!dir.existsSync()) dir.createSync(recursive: true);

  final db = Database.open(dbPath);
  final handler = Api(db, Auth(secret)).handler;

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln('acgnhub-server listening on http://${server.address.host}:${server.port}');
}
```

- [ ] **Step 2: Create `server/Dockerfile`**

```dockerfile
FROM dart:stable AS build
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get
COPY . .
RUN dart pub get --offline

FROM dart:stable
WORKDIR /app
COPY --from=build /app /app
ENV PORT=8080
ENV ACGHUB_DB_PATH=/data/acgnhub.db
VOLUME /data
EXPOSE 8080
CMD ["dart", "run", "bin/server.dart"]
```

- [ ] **Step 3: Analyze**

Run (workdir `server/`): `dart analyze`
Expected: `No issues found!`

- [ ] **Step 4: Manual smoke test (report the exact output)**

Start the server in the background and exercise it with `curl` (workdir `server/`):

```powershell
$env:ACGHUB_JWT_SECRET = "dev-secret"
$env:ACGHUB_DB_PATH = "data/smoke.db"
$p = Start-Process -FilePath "dart" -ArgumentList "run","bin/server.dart" -PassThru -NoNewWindow
Start-Sleep -Seconds 6
$reg = curl.exe -s -X POST http://127.0.0.1:8080/api/auth/register -H "content-type: application/json" -d '{"username":"smoke","password":"secret1"}'
Write-Output "REGISTER=$reg"
$token = ($reg | ConvertFrom-Json).token
Write-Output "ME=$(curl.exe -s http://127.0.0.1:8080/api/me -H "authorization: Bearer $token")"
Write-Output "PUT=$(curl.exe -s -X PUT http://127.0.0.1:8080/api/follows -H "content-type: application/json" -H "authorization: Bearer $token" -d '{"work":{"id":"w1","title":"A"},"updatedAt":100}')"
Write-Output "SYNC=$(curl.exe -s "http://127.0.0.1:8080/api/sync?sinceSeq=0" -H "authorization: Bearer $token")"
Stop-Process -Id $p.Id -Force
Remove-Item -LiteralPath "data/smoke.db" -Force -ErrorAction SilentlyContinue
```

Expected: `REGISTER` contains a `token` and `"id":1`; `ME` returns the user; `PUT` returns the follow; `SYNC` contains it with `"nextSeq":1`.

- [ ] **Step 5: Commit**

```bash
git add server/bin/server.dart server/Dockerfile
git commit -m "feat(server): add the server entrypoint and Dockerfile"
```

---

### Task 8: Final verification

**Files:** none (verification only).

- [ ] **Step 1: Server tests + analyze**

Run (workdir `server/`): `dart analyze` → `No issues found!`
Run (workdir `server/`): `dart test` → all tests pass.

- [ ] **Step 2: Flutter side unaffected**

Run (repo root): `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run (repo root): `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → all tests pass.

- [ ] **Step 3: Record the results**

Write the observed output into the task report.

---

## Self-Review

- **Spec coverage:** §3 package layout → Tasks 1, 7; §4 data model → Tasks 1–2; §5 auth routes → Task 4, follows/history → Task 5, sync → Task 6; §6 LWW + tombstones + seq cursor → Task 2; §7 JWT/bcrypt/secret → Task 3, 7; §8 errors → Task 4 (`_guard`, `_error`); §9 tests → Tasks 1–6, 8; §10 files → Tasks 1, 7; §10 root config → Task 1.
- **Placeholders:** none — every step has complete code or an exact command.
- **Type consistency:** `Database.open/createUser/findUserByName/findUserById/currentSeq/getFollow/upsertFollow/listFollows/followsSince/getHistory/upsertHistory/listHistory/historySince/clearHistory`; `Auth(secret)/hashPassword/verifyPassword/issueAccessToken/issueRefreshToken/verifyToken`; `Api(db, auth).handler` — used consistently across tasks.
