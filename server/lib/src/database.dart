import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:sqlite3/common.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart' hide Database;

void _overrideWindowsSqlite() {
  if (Platform.isWindows) {
    open.overrideFor(
        OperatingSystem.windows, () => DynamicLibrary.open('winsqlite3.dll'));
  }
}

class Database {
  Database._(this._db);

  final CommonDatabase _db;

  static Database open(String path) {
    _overrideWindowsSqlite();
    final db = sqlite3.open(path);
    _migrate(db);
    return Database._(db);
  }

  static void _migrate(CommonDatabase db) {
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
}
