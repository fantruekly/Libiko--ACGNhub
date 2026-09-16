import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/models/watch_record.dart';
import 'package:libiko/core/models/work.dart';

void main() {
  const work = Work(
    id: 'bangumi_123',
    sourceId: 'bangumi',
    sourceName: 'Bangumi',
    type: WorkType.anime,
    title: '葬送的芙莉莲',
    coverUrl: 'https://img/x.jpg',
    summary: 'A summary.',
    tags: ['奇幻'],
    extra: {'bangumiId': 123},
  );

  test('toJson/fromJson round-trips the record and its Work', () {
    final record = WatchRecord(
      work: work,
      episodeTitle: '第3集',
      episodeIndex: 2,
      watchedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    );

    final restored = WatchRecord.fromJson(record.toJson());

    expect(restored.work.id, 'bangumi_123');
    expect(restored.work.title, '葬送的芙莉莲');
    expect(restored.work.coverUrl, 'https://img/x.jpg');
    expect(restored.work.tags, ['奇幻']);
    expect(restored.work.bangumiId, 123);
    expect(restored.episodeTitle, '第3集');
    expect(restored.episodeIndex, 2);
    expect(restored.watchedAt, DateTime.fromMillisecondsSinceEpoch(1700000000000));
  });

  test('carries updatedAt/deleted/dirty with defaults', () {
    final record = WatchRecord(
      work: work,
      episodeTitle: '第1集',
      episodeIndex: 0,
      watchedAt: DateTime.fromMillisecondsSinceEpoch(100),
    );
    expect(record.updatedAt, record.watchedAt);
    expect(record.deleted, isFalse);
    expect(record.dirty, isFalse);

    final restored = WatchRecord.fromJson(record.copyWith(dirty: true).toJson());
    expect(restored.dirty, isTrue);
    expect(restored.updatedAt.millisecondsSinceEpoch, 100);
  });
}
