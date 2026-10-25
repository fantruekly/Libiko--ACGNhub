import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/storage/collection_store.dart';
import 'package:libiko/core/storage/personal_backup.dart';
import 'package:libiko/core/sources/source_preferences.dart';

Map<String, dynamic> history(int time, int page) => {
      'sourceKey': 's',
      'comicId': 'c',
      'title': '书',
      'chapterId': 'ch',
      'chapterTitle': '第一章',
      'readAt': time,
      'page': page,
    };

void main() {
  late CollectionStore store;
  late SourcePreferences sources;
  late PersonalBackupService backup;
  setUp(() {
    store = CollectionStore.memory();
    sources = const SourcePreferences();
    backup = PersonalBackupService(
        store: store,
        readSources: () => sources,
        writeSources: (value) async => sources = value,
        clock: () => DateTime.utc(2026));
  });
  tearDown(() => store.dispose());

  test('exports typed collections and source settings with a preview', () {
    store.upsert('comic_history', history(10, 2));
    sources = const SourcePreferences(disabled: {
      SourceKind.comic: {'s'}
    });
    final raw = backup.exportText();
    final preview = backup.preview(raw);
    expect(preview.records, 1);
    expect(preview.sources!.enabled(SourceKind.comic, 's'), false);
    final json = jsonDecode(raw) as Map;
    expect(json.keys.toSet(),
        {'application', 'version', 'createdAt', 'personal', 'sources'});
    expect(raw, isNot(contains('account_token')));
    expect(raw, isNot(contains('comic_source_data')));
  });

  test('merges old backups without overwriting newer local reading progress',
      () async {
    store.upsert('comic_history', history(10, 2));
    final old = backup.preview(backup.exportText());
    store.upsert('comic_history', history(20, 8));
    final report = await backup.restore(old);
    expect(report.skipped, 1);
    expect(store.all('comic_history').single['page'], 8);
  });

  test('rejects malformed or credential collection backups before writing', () {
    final json = jsonDecode(backup.exportText()) as Map<String, dynamic>;
    (json['personal']['collections'] as Map)['account_token'] = ['secret'];
    expect(() => backup.preview(jsonEncode(json)), throwsFormatException);
    expect(store.all('comic_history'), isEmpty);
  });

  test('a source setting write failure leaves personal records unchanged',
      () async {
    store.upsert('comic_history', history(10, 2));
    final preview = backup.preview(backup.exportText());
    store.clear('comic_history');
    var calls = 0;
    final failing = PersonalBackupService(
        store: store,
        readSources: () => sources,
        writeSources: (value) async {
          if (calls++ == 0) throw StateError('disk full');
          sources = value;
        });
    await expectLater(failing.restore(preview), throwsStateError);
    expect(store.all('comic_history'), isEmpty);
  });

  test('source preferences are rolled back if the SQLite transaction fails',
      () async {
    final incoming = const SourcePreferences(disabled: {
      SourceKind.anime: {'x'}
    });
    final raw = jsonDecode(backup.exportText()) as Map<String, dynamic>;
    raw['sources'] = incoming.toJson();
    final preview = backup.preview(jsonEncode(raw));
    final closed = CollectionStore.memory()..dispose();
    final failing = PersonalBackupService(
        store: closed,
        readSources: () => sources,
        writeSources: (value) async => sources = value);
    await expectLater(failing.restore(preview), throwsA(anything));
    expect(sources.enabled(SourceKind.anime, 'x'), true);
  });
}
