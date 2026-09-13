import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acgnhub/core/models/watch_record.dart';
import 'package:acgnhub/core/models/work.dart';
import 'package:acgnhub/core/services/watch_history.dart';
import 'package:acgnhub/core/storage/database.dart';
import 'package:acgnhub/core/video/video_source.dart';

Work _work(String id) => Work(
      id: id,
      sourceId: 'bangumi',
      sourceName: 'Bangumi',
      type: WorkType.anime,
      title: 'Title $id',
    );

WatchRecord _record(String id, String ep, int ms, {bool dirty = false}) =>
    WatchRecord(
      work: _work(id),
      episodeTitle: ep,
      episodeIndex: 0,
      watchedAt: DateTime.fromMillisecondsSinceEpoch(ms),
      dirty: dirty,
    );

void main() {
  test('upsert dedupes by work id and puts the new record first', () {
    final existing = [_record('a', '第1集', 1000), _record('b', '第1集', 2000)];
    final result = WatchHistoryManager.upsert(existing, _record('a', '第5集', 3000));

    expect(result, hasLength(2));
    expect(result.first.work.id, 'a');
    expect(result.first.episodeTitle, '第5集');
    expect(result.last.work.id, 'b');
  });

  test('upsert inserts a new work at the front', () {
    final result = WatchHistoryManager.upsert([_record('a', '第1集', 1000)], _record('c', '第2集', 2000));
    expect(result.map((r) => r.work.id).toList(), ['c', 'a']);
  });

  test('sortDescending orders by watchedAt newest first', () {
    final sorted = WatchHistoryManager.sortDescending(
        [_record('a', 'e', 1000), _record('b', 'e', 3000), _record('c', 'e', 2000)]);
    expect(sorted.map((r) => r.work.id).toList(), ['b', 'c', 'a']);
  });

  test('persists, dedupes, clears, and skips malformed stored entries', () async {
    SharedPreferences.setMockInitialValues({});
    await AppDatabase.init();

    final manager = WatchHistoryManager();
    expect(manager.all(), isEmpty);

    const ep1 = VideoEpisode(id: 'e1', title: '第1集', index: 0, playUrl: 'u1');
    const ep5 = VideoEpisode(id: 'e5', title: '第5集', index: 4, playUrl: 'u5');

    await manager.record(_work('a'), ep1);
    await manager.record(_work('b'), ep1);
    await manager.record(_work('a'), ep5);

    final all = manager.all();
    expect(all.map((r) => r.work.id).toList(), ['a', 'b']);
    expect(all.first.episodeTitle, '第5集');

    // A malformed stored entry must be skipped, not fail the whole list.
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getKeys().firstWhere((k) => k.endsWith('watch_history'));
    final raw = prefs.getStringList(key)!;
    await prefs.setStringList(key, ['not json', ...raw]);
    expect(manager.all().map((r) => r.work.id).toList(), ['a', 'b']);

    await manager.clear();
    expect(manager.all(), isEmpty);
  });

  test('merge keeps a newer local record and takes a newer server record', () {
    final merged = WatchHistoryManager.merge(
      [_record('a', '第1集', 300, dirty: true), _record('b', '第1集', 100)],
      [_record('a', '第0集', 200), _record('b', '第9集', 500)],
    );
    final byId = {for (final r in merged) r.work.id: r};
    expect(byId['a']!.episodeTitle, '第1集');
    expect(byId['a']!.dirty, isTrue); // kept local stays dirty
    expect(byId['b']!.episodeTitle, '第9集');
    expect(byId['b']!.dirty, isFalse);
  });

  test('record marks dirty and clear writes tombstones plus pendingClear', () async {
    SharedPreferences.setMockInitialValues({});
    await AppDatabase.init();
    final manager = WatchHistoryManager();

    const ep = VideoEpisode(id: 'e1', title: '第1集', index: 0, playUrl: 'u');
    await manager.record(_work('a'), ep);
    expect(manager.dirty().single.work.id, 'a');

    await manager.clear();
    expect(manager.all(), isEmpty);
    expect(manager.pendingClear, isTrue);
    expect(manager.clearAt, isNotNull);
    expect(manager.dirty().single.deleted, isTrue);

    await manager.clearPendingClear();
    expect(manager.pendingClear, isFalse);
    expect(manager.clearAt, isNull);
  });

  test('markSynced ignores a stale pushed timestamp', () async {
    SharedPreferences.setMockInitialValues({});
    await AppDatabase.init();
    final manager = WatchHistoryManager();
    const ep = VideoEpisode(id: 'e1', title: '第1集', index: 0, playUrl: 'u');
    await manager.record(_work('a'), ep);
    final current = manager.dirty().single;

    await manager.markSynced({
      'a': current.updatedAt.subtract(const Duration(seconds: 1)),
    });
    expect(manager.dirty(), isNotEmpty);

    await manager.markSynced({'a': current.updatedAt});
    expect(manager.dirty(), isEmpty);
  });
}
