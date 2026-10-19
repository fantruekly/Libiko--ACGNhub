import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../models/work.dart';

/// The only personal collections eligible for export; settings and account or
/// source credentials are deliberately outside this database and snapshot.
const personalCollections = <String>{
  'watch_history',
  'follows',
  'favorites',
  'comic_history',
  'comic_favorites',
  'novel_history',
  'novel_favorites',
};

class RestoreReport {
  final int imported;
  final int skipped;
  final Map<String, int> importedByCollection;
  const RestoreReport(this.imported, this.skipped, this.importedByCollection);
}

/// One row per collection and typed/source-qualified work identity. JSON keeps
/// model-specific progress fields without making settings part of the backup.
class CollectionStore {
  CollectionStore(this._db) {
    _db.execute('PRAGMA busy_timeout = 5000');
    _db.execute('''CREATE TABLE IF NOT EXISTS personal_records (
      collection TEXT NOT NULL,
      record_key TEXT NOT NULL,
      content_type TEXT NOT NULL,
      payload TEXT NOT NULL,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (collection, record_key)
    )''');
    _db.execute('''CREATE INDEX IF NOT EXISTS personal_records_recent
      ON personal_records(collection, updated_at DESC)''');
    _db.execute('''CREATE TABLE IF NOT EXISTS local_migrations (
      name TEXT PRIMARY KEY, completed_at INTEGER NOT NULL,
      skipped_records INTEGER NOT NULL DEFAULT 0)''');
  }

  factory CollectionStore.open(String path) => _create(sqlite3.open(path));
  factory CollectionStore.memory() => _create(sqlite3.openInMemory());

  static CollectionStore _create(Database database) {
    try {
      return CollectionStore(database);
    } catch (_) {
      database.dispose();
      rethrow;
    }
  }

  final Database _db;
  bool _disposed = false;
  static const _migration = 'prefs_personal_collections_v1';

  int get migrationSkippedRecords {
    final rows = _db.select(
        'SELECT skipped_records FROM local_migrations WHERE name = ?',
        [_migration]);
    return rows.isEmpty ? 0 : rows.first['skipped_records'] as int;
  }

  bool get legacyMigrationComplete => _db.select(
      'SELECT 1 FROM local_migrations WHERE name = ?', [_migration]).isNotEmpty;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _db.dispose();
  }

  void _checkCollection(String collection) {
    if (!personalCollections.contains(collection)) {
      throw FormatException('Unknown personal collection: $collection');
    }
  }

  List<Map<String, dynamic>> all(String collection) {
    _checkCollection(collection);
    return _db
        .select(
            'SELECT payload FROM personal_records WHERE collection = ? ORDER BY rowid',
            [
              collection
            ])
        .map((row) =>
            jsonDecode(row['payload'] as String) as Map<String, dynamic>)
        .toList();
  }

  Map<String, dynamic>? get(String collection, String recordKey) {
    _checkCollection(collection);
    final rows = _db.select(
        'SELECT payload FROM personal_records WHERE collection = ? AND record_key = ?',
        [collection, recordKey]);
    return rows.isEmpty
        ? null
        : jsonDecode(rows.first['payload'] as String) as Map<String, dynamic>;
  }

  String recordKey(String collection, Map<String, dynamic> row) {
    _checkCollection(collection);
    if (collection.startsWith('comic_')) {
      return jsonEncode(['comic', row['sourceKey'], row['comicId']]);
    }
    if (collection.startsWith('novel_')) {
      return jsonEncode(['novel', row['sourceKey'], row['novelId']]);
    }
    final work =
        collection == 'favorites' ? row : row['work'] as Map<String, dynamic>;
    return jsonEncode([work['type'], work['id']]);
  }

  int _timestamp(String collection, Map<String, dynamic> row) =>
      (row['updatedAt'] ?? row['readAt'] ?? row['watchedAt'] ?? row['addedAt'])
          as int? ??
      0;

  String _contentType(String collection, Map<String, dynamic> row) =>
      collection.startsWith('comic_')
          ? 'comic'
          : collection.startsWith('novel_')
              ? 'novel'
              : (collection == 'favorites'
                  ? row['type']
                  : (row['work'] as Map)['type']) as String;

  void upsert(String collection, Map<String, dynamic> row) {
    _validate(collection, row);
    final key = recordKey(collection, row);
    final payload = jsonEncode(row);
    // Conditional UPSERT makes an unchanged row a true no-op (including when a
    // caller reconciles a full collection after a sync response).
    _db.execute('''INSERT INTO personal_records
      (collection, record_key, content_type, payload, updated_at) VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(collection, record_key) DO UPDATE SET
        payload = excluded.payload, content_type = excluded.content_type,
        updated_at = excluded.updated_at
      WHERE personal_records.payload != excluded.payload''', [
      collection,
      key,
      _contentType(collection, row),
      payload,
      _timestamp(collection, row)
    ]);
  }

  void remove(String collection, Map<String, dynamic> row) {
    _validate(collection, row);
    _db.execute(
        'DELETE FROM personal_records WHERE collection = ? AND record_key = ?',
        [collection, recordKey(collection, row)]);
  }

  void clear(String collection) {
    _checkCollection(collection);
    _db.execute(
        'DELETE FROM personal_records WHERE collection = ?', [collection]);
  }

  /// Applies only changed/deleted rows; never clears and rewrites a collection.
  void replace(String collection, List<Map<String, dynamic>> rows) {
    _checkCollection(collection);
    for (final row in rows) {
      _validate(collection, row);
    }
    _transaction(() => _replace(collection, rows));
  }

  void _replace(String collection, List<Map<String, dynamic>> rows) {
    final keys = rows.map((row) => recordKey(collection, row)).toSet();
    if (keys.length != rows.length) {
      throw const FormatException('Duplicate record identity');
    }
    for (final old in _db.select(
        'SELECT record_key FROM personal_records WHERE collection = ?',
        [collection])) {
      if (!keys.contains(old['record_key'])) {
        _db.execute(
            'DELETE FROM personal_records WHERE collection = ? AND record_key = ?',
            [collection, old['record_key']]);
      }
    }
    for (final row in rows) {
      upsert(collection, row);
    }
  }

  /// Every valid old entry and the completion marker commit together. A SQL or
  /// IO failure rolls everything back, leaving migration retryable next launch.
  /// Malformed rows are counted; original preference values are never deleted.
  void migrateLegacy(Map<String, List<String>> legacy) {
    if (legacyMigrationComplete) return;
    _transaction(() {
      var skipped = 0;
      for (final collection in personalCollections) {
        for (final raw in legacy[collection] ?? const <String>[]) {
          Map<String, dynamic> row;
          try {
            final decoded = jsonDecode(raw);
            if (decoded is! Map<String, dynamic>) {
              throw const FormatException('Expected record');
            }
            row = decoded;
            _validate(collection, row);
          } catch (_) {
            skipped++;
            continue;
          }
          final key = recordKey(collection, row);
          final current = get(collection, key);
          if (current == null ||
              _timestamp(collection, row) > _timestamp(collection, current)) {
            upsert(collection, row);
          }
        }
      }
      _db.execute(
          'INSERT INTO local_migrations(name, completed_at, skipped_records) VALUES (?, ?, ?)',
          [_migration, DateTime.now().millisecondsSinceEpoch, skipped]);
    });
  }

  Map<String, dynamic> exportSnapshot({bool includeDeleted = false}) => {
        'version': 1,
        'collections': {
          for (final collection in personalCollections)
            collection: all(collection)
                .where((row) => includeDeleted || row['deleted'] != true)
                .toList()
        },
      };

  /// Merge is the default: older backups cannot overwrite more recent reading
  /// progress. Every collection is validated before any mutation occurs.
  RestoreReport restoreSnapshot(Map<String, dynamic> snapshot,
          {bool replace = false}) =>
      _restore(snapshot,
          replace: replace, includeDeleted: false, markDirty: true);

  /// Only for local compensation/rollback, never for importing user backups.
  /// Includes tombstones and restores their dirty flags exactly.
  RestoreReport restoreExactSnapshot(Map<String, dynamic> snapshot) =>
      _restore(snapshot, replace: true, includeDeleted: true, markDirty: false);

  RestoreReport _restore(
    Map<String, dynamic> snapshot, {
    required bool replace,
    required bool includeDeleted,
    required bool markDirty,
  }) {
    if (snapshot['version'] != 1 ||
        snapshot['collections'] is! Map<String, dynamic>) {
      throw const FormatException('Unsupported personal collection backup');
    }
    final collections = snapshot['collections'] as Map<String, dynamic>;
    final validated = <String, List<Map<String, dynamic>>>{};
    for (final entry in collections.entries) {
      _checkCollection(entry.key);
      if (entry.value is! List) {
        throw const FormatException('Expected collection list');
      }
      final records = <Map<String, dynamic>>[];
      final seen = <String>{};
      for (final item in entry.value as List) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Expected record object');
        }
        _validate(entry.key, item);
        if (!seen.add(recordKey(entry.key, item))) {
          throw const FormatException('Duplicate record identity');
        }
        records.add(Map<String, dynamic>.from(item));
      }
      validated[entry.key] = records;
    }
    var imported = 0;
    var skipped = 0;
    final counts = <String, int>{};
    _transaction(() {
      for (final entry in validated.entries) {
        if (replace) clear(entry.key);
        for (final row in entry.value) {
          if (!includeDeleted && row['deleted'] == true) {
            skipped++;
            continue;
          }
          final current = get(entry.key, recordKey(entry.key, row));
          if (current != null &&
              _timestamp(entry.key, current) >= _timestamp(entry.key, row)) {
            skipped++;
            continue;
          }
          if (markDirty &&
              (entry.key == 'watch_history' || entry.key == 'follows')) {
            row['dirty'] = true;
          }
          upsert(entry.key, row);
          imported++;
          counts.update(entry.key, (value) => value + 1, ifAbsent: () => 1);
        }
      }
    });
    return RestoreReport(imported, skipped, Map.unmodifiable(counts));
  }

  void _transaction(void Function() action) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      action();
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void _validate(String collection, Map<String, dynamic> row) {
    _checkCollection(collection);
    bool nonempty(Object? value) => value is String && value.trim().isNotEmpty;
    void fail() => throw FormatException('Invalid record in $collection');
    if (collection.startsWith('comic_') || collection.startsWith('novel_')) {
      final idField = collection.startsWith('comic_') ? 'comicId' : 'novelId';
      if (!nonempty(row['sourceKey']) ||
          !nonempty(row[idField]) ||
          row['title'] is! String) {
        fail();
      }
      if (collection.endsWith('_history') &&
          (!nonempty(row['chapterId']) || row['chapterTitle'] is! String)) {
        fail();
      }
    } else {
      final work = collection == 'favorites' ? row : row['work'];
      if (work is! Map<String, dynamic>) fail();
      try {
        Work.fromJson(work as Map<String, dynamic>);
      } catch (_) {
        fail();
      }
      if (!nonempty((work as Map)['id'])) fail();
      final tags = work['tags'];
      if (tags != null &&
          (tags is! List || tags.any((tag) => tag is! String))) {
        fail();
      }
      if (collection == 'watch_history' &&
          (row['episodeTitle'] is! String || row['episodeIndex'] is! int)) {
        fail();
      }
    }
    for (final field in [
      'updatedAt',
      'readAt',
      'watchedAt',
      'addedAt',
      'page',
      'positionMs',
      'durationMs',
      'episodeIndex',
      'blockIndex',
      'characterOffset'
    ]) {
      if (row[field] != null &&
          (row[field] is! int || (row[field] as int) < 0)) {
        fail();
      }
    }
    for (final field in ['deleted', 'dirty', 'completed']) {
      if (row[field] != null && row[field] is! bool) fail();
    }
    for (final field in ['updatedAt', 'readAt', 'watchedAt', 'addedAt']) {
      final value = row[field];
      if (value != null && (value as int) > 8640000000000000) {
        fail();
      }
    }
    for (final field in [
      'sourceId',
      'lineId',
      'episodeKey',
      'cover',
      'anchorText'
    ]) {
      if (row[field] != null && row[field] is! String) fail();
    }
    final fraction = row['scrollFraction'];
    if (fraction != null &&
        (fraction is! num ||
            !fraction.isFinite ||
            fraction < 0 ||
            fraction > 1)) {
      fail();
    }
    jsonEncode(row); // Reject values that cannot be safely restored as JSON.
  }
}
