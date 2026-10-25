import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/models/work.dart';
import 'package:libiko/core/services/watch_history.dart';
import 'package:libiko/core/storage/database.dart';
import 'package:libiko/core/video/video_source.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

Map<String, dynamic> _work(String id, {WorkType type = WorkType.anime}) => Work(
      id: id,
      sourceId: 'source',
      sourceName: 'Source',
      type: type,
      title: 'Title $id',
    ).toJson();

Map<String, dynamic> _watch(String id, int time) => {
      'work': _work(id),
      'episodeTitle': '第1集',
      'episodeIndex': 0,
      'watchedAt': time,
      'updatedAt': time,
      'positionMs': time,
      'durationMs': 90000,
      'sourceId': 's',
      'lineId': 'road:0',
      'episodeKey': 'episode:1',
      'dirty': false,
      'deleted': false,
    };

Map<String, dynamic> _reading(String kind, String id, int time) => {
      'sourceKey': 's',
      '${kind}Id': id,
      'title': 'Title $id',
      'chapterId': 'chapter',
      'chapterTitle': '第一章',
      if (kind == 'comic') ...{'page': 3, 'readAt': time},
      if (kind == 'novel') ...{
        'updatedAt': time,
        'blockIndex': 5,
        'characterOffset': 12,
        'scrollFraction': .4,
        'anchorText': '前文锚点'
      },
    };

Map<String, dynamic> _snapshot(Map<String, dynamic> collections) =>
    {'version': 1, 'collections': collections};

void main() {
  late Database native;
  late CollectionStore store;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    native = sqlite3.openInMemory();
    store = CollectionStore(native);
  });
  tearDown(() => store.dispose());

  test(
      'migration handles all seven collections and retains progress and sync flags',
      () {
    final legacy = <String, List<String>>{
      'watch_history': [
        jsonEncode({..._watch('a', 100), 'dirty': true, 'deleted': true})
      ],
      'follows': [
        jsonEncode({
          'work': _work('a'),
          'updatedAt': 10,
          'deleted': true,
          'dirty': true
        })
      ],
      'favorites': [jsonEncode(_work('a'))],
      'comic_history': [jsonEncode(_reading('comic', 'a', 20))],
      'comic_favorites': [
        jsonEncode(
            {'sourceKey': 's', 'comicId': 'a', 'title': 'A', 'addedAt': 20})
      ],
      'novel_history': [jsonEncode(_reading('novel', 'a', 30))],
      'novel_favorites': [
        jsonEncode(
            {'sourceKey': 's', 'novelId': 'a', 'title': 'A', 'addedAt': 30})
      ],
    };
    store.migrateLegacy(legacy);
    for (final collection in personalCollections) {
      expect(store.all(collection), hasLength(1), reason: collection);
    }
    expect(store.all('watch_history').single['dirty'], true);
    expect(store.all('watch_history').single['deleted'], true);
    expect(store.all('novel_history').single['characterOffset'], 12);
    expect(store.all('novel_history').single['anchorText'], '前文锚点');
    expect(store.legacyMigrationComplete, true);
    expect(store.migrationSkippedRecords, 0);
  });

  test(
      'migration is idempotent, chooses latest duplicate and skips malformed rows',
      () {
    store.migrateLegacy({
      'watch_history': [
        'bad json',
        '[]',
        '{}',
        jsonEncode(_watch('a', 100)),
        jsonEncode(_watch('a', 200))
      ]
    });
    expect(store.migrationSkippedRecords, 3);
    expect(store.all('watch_history').single['positionMs'], 200);
    store.clear('watch_history');
    store.migrateLegacy({
      'watch_history': [jsonEncode(_watch('a', 500))]
    });
    expect(store.all('watch_history'),
        isEmpty); // Old prefs cannot resurrect cleared rows.
  });

  test('SQL migration failure rolls rows and marker back and can be retried',
      () {
    native.execute(
        """CREATE TRIGGER reject_novel BEFORE INSERT ON personal_records
      WHEN NEW.collection = 'novel_history'
      BEGIN SELECT RAISE(ABORT, 'simulated full disk'); END""");
    final legacy = {
      'watch_history': [jsonEncode(_watch('a', 100))],
      'novel_history': [jsonEncode(_reading('novel', 'a', 100))]
    };
    expect(() => store.migrateLegacy(legacy), throwsA(isA<SqliteException>()));
    expect(store.all('watch_history'), isEmpty);
    expect(store.legacyMigrationComplete, false);
    native.execute('DROP TRIGGER reject_novel');
    store.migrateLegacy(legacy);
    expect(store.all('watch_history'), hasLength(1));
    expect(store.all('novel_history'), hasLength(1));
  });

  test('AppDatabase migration preserves old preferences and settings APIs',
      () async {
    final old = ['malformed', jsonEncode(_watch('a', 100))];
    SharedPreferences.setMockInitialValues({
      'watch_history': old,
      'theme_mode': 'dark',
      'account_token': 'private-token'
    });
    final db = await AppDatabase.init();
    expect(db.collections.all('watch_history'), hasLength(1));
    expect(
        (await SharedPreferences.getInstance()).getStringList('watch_history'),
        old);
    expect(db.getString('theme_mode'), 'dark');
    await db.setString('theme_mode', 'light');
    expect(db.getString('theme_mode'), 'light');
    await db.setStringList('source-list', ['source']);
    expect(db.getStringList('source-list'), ['source']);
    expect(jsonEncode(db.collections.exportSnapshot()),
        isNot(contains('private-token')));
  });

  test('file database survives reopening without reimporting stale preferences',
      () {
    final directory =
        Directory.systemTemp.createTempSync('libiko-personal-test-');
    final file = '${directory.path}/personal.sqlite';
    try {
      var disk = CollectionStore.open(file);
      disk.migrateLegacy({
        'watch_history': [jsonEncode(_watch('a', 100))]
      });
      disk.upsert('watch_history', _watch('a', 200));
      disk.dispose();
      disk = CollectionStore.open(file);
      try {
        disk.migrateLegacy({
          'watch_history': [jsonEncode(_watch('a', 100))]
        });
        expect(disk.all('watch_history').single['positionMs'], 200);
      } finally {
        disk.dispose();
      }
    } finally {
      directory.deleteSync(recursive: true);
    }
  });

  test('one changed record changes one row, unchanged upsert changes none', () {
    store.upsert('watch_history', _watch('a', 100));
    store.upsert('watch_history', _watch('b', 100));
    int changes() =>
        native.select('SELECT total_changes() AS n').single['n'] as int;
    var before = changes();
    store.upsert('watch_history', _watch('a', 200));
    expect(changes() - before, 1);
    before = changes();
    store.upsert('watch_history', _watch('a', 200));
    expect(changes() - before, 0);
    before = changes();
    store.replace('watch_history', [_watch('a', 300), _watch('b', 100)]);
    expect(changes() - before, 1);
    expect(store.all('watch_history').last['positionMs'], 100);
  });

  test('history manager writes exactly one row per progress update', () async {
    await AppDatabase.init(collections: store);
    final manager = WatchHistoryManager();
    const episode =
        VideoEpisode(id: 'ep', title: '第1集', index: 0, playUrl: 'url');
    await manager.record(Work.fromJson(_work('a')), episode, positionMs: 100);
    await manager.record(Work.fromJson(_work('b')), episode, positionMs: 200);
    final before =
        native.select('SELECT total_changes() AS n').single['n'] as int;
    await manager.record(Work.fromJson(_work('a')), episode, positionMs: 300);
    final after =
        native.select('SELECT total_changes() AS n').single['n'] as int;
    expect(after - before, 1);
    final records = {
      for (final record in manager.all()) record.work.id: record
    };
    expect(records['a']!.positionMs, 300);
    expect(records['b']!.positionMs, 200);
  });

  test('AppDatabase migration failure retains old prefs and allows retry',
      () async {
    final old = [jsonEncode(_watch('a', 100))];
    SharedPreferences.setMockInitialValues({'watch_history': old});
    native.execute(
        """CREATE TRIGGER reject_writes BEFORE INSERT ON personal_records
      BEGIN SELECT RAISE(ABORT, 'simulated full disk'); END""");
    await expectLater(
        AppDatabase.init(collections: store), throwsA(isA<SqliteException>()));
    expect(
        (await SharedPreferences.getInstance()).getStringList('watch_history'),
        old);
    expect(store.legacyMigrationComplete, false);
    native.execute('DROP TRIGGER reject_writes');
    await AppDatabase.init(collections: store);
    expect(store.all('watch_history'), hasLength(1));
    expect(
        (await SharedPreferences.getInstance()).getStringList('watch_history'),
        old);
  });

  test(
      'typed work identity and source-qualified reading identity do not collide',
      () {
    store.upsert('favorites', _work('1'));
    store.upsert('favorites', _work('1', type: WorkType.game));
    store.upsert('comic_history', _reading('comic', '1', 100));
    store.upsert('comic_history',
        {..._reading('comic', '1', 200), 'sourceKey': 'other'});
    expect(store.all('favorites'), hasLength(2));
    expect(store.all('comic_history'), hasLength(2));
  });

  test(
      'merge restore keeps newer local progress and returns per-collection counts',
      () {
    store.upsert('watch_history', _watch('a', 200));
    final report = store.restoreSnapshot(_snapshot({
      'watch_history': [_watch('a', 100), _watch('b', 300)],
      'novel_history': [_reading('novel', 'n', 400)],
    }));
    expect(report.imported, 2);
    expect(report.skipped, 1);
    expect(
        report.importedByCollection, {'watch_history': 1, 'novel_history': 1});
    final a = store.get(
        'watch_history', store.recordKey('watch_history', _watch('a', 0)))!;
    final b = store.get(
        'watch_history', store.recordKey('watch_history', _watch('b', 0)))!;
    expect(a['positionMs'], 200);
    expect(a['dirty'], false);
    expect(b['dirty'], true);
    expect(b['updatedAt'], 300);
  });

  test(
      'user backups exclude tombstones and importing them does not revive records',
      () {
    store.upsert(
        'watch_history', {..._watch('a', 200), 'deleted': true, 'dirty': true});
    expect((store.exportSnapshot()['collections'] as Map)['watch_history'],
        isEmpty);
    final report = store.restoreSnapshot(_snapshot({
      'watch_history': [
        {..._watch('a', 300), 'deleted': true}
      ]
    }));
    expect(report.imported, 0);
    expect(report.skipped, 1);
    expect(store.all('watch_history').single['updatedAt'], 200);
  });

  test('exact internal restore preserves sync flags and tombstones', () {
    final original = {..._watch('a', 200), 'deleted': true, 'dirty': false};
    store.upsert('watch_history', original);
    final snapshot = store.exportSnapshot(includeDeleted: true);
    store.upsert('watch_history', _watch('a', 500));
    store.upsert('novel_history', _reading('novel', 'b', 100));
    store.restoreExactSnapshot(snapshot);
    expect(store.all('watch_history').single, original);
    expect(store.all('novel_history'), isEmpty);
  });

  test('invalid backup record is rejected before modifying any collection', () {
    store.upsert('watch_history', _watch('original', 100));
    final before = store.exportSnapshot(includeDeleted: true);
    expect(
        () => store.restoreSnapshot(
            _snapshot({
              'watch_history': [_watch('new', 200)],
              'novel_history': [
                {..._reading('novel', 'bad', 200), 'scrollFraction': 2}
              ],
            }),
            replace: true),
        throwsFormatException);
    expect(store.exportSnapshot(includeDeleted: true), before);
    expect(() => store.restoreSnapshot(_snapshot({'account_token': []})),
        throwsFormatException);
    expect(
        () => store.restoreSnapshot(_snapshot({
              'watch_history': [
                {..._watch('new', 200), 'updatedAt': 8640000000000001}
              ]
            })),
        throwsFormatException);
    expect(() => store.restoreSnapshot({'version': 99, 'collections': {}}),
        throwsFormatException);
  });

  test(
      'restore SQL failure rolls back every collection including replaced rows',
      () {
    store.upsert('watch_history', _watch('original', 100));
    final before = store.exportSnapshot(includeDeleted: true);
    native.execute(
        """CREATE TRIGGER reject_novel BEFORE INSERT ON personal_records
      WHEN NEW.collection = 'novel_history'
      BEGIN SELECT RAISE(ABORT, 'simulated write failure'); END""");
    expect(
        () => store.restoreSnapshot(
            _snapshot({
              'watch_history': [_watch('new', 200)],
              'novel_history': [_reading('novel', 'bad', 200)],
            }),
            replace: true),
        throwsA(isA<SqliteException>()));
    expect(store.exportSnapshot(includeDeleted: true), before);
  });
}
