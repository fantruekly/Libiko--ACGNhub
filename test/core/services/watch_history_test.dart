import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/models/watch_record.dart';
import 'package:acgnhub/core/models/work.dart';
import 'package:acgnhub/core/services/watch_history.dart';

Work _work(String id) => Work(
      id: id,
      sourceId: 'bangumi',
      sourceName: 'Bangumi',
      type: WorkType.anime,
      title: 'Title $id',
    );

WatchRecord _record(String id, String ep, int ms) => WatchRecord(
      work: _work(id),
      episodeTitle: ep,
      episodeIndex: 0,
      watchedAt: DateTime.fromMillisecondsSinceEpoch(ms),
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
}
