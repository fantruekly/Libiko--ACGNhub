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
}
