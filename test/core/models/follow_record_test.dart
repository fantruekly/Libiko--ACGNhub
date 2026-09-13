import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/models/follow_record.dart';
import 'package:acgnhub/core/models/work.dart';

void main() {
  const work = Work(
    id: 'w1',
    sourceId: 'bangumi',
    sourceName: 'Bangumi',
    type: WorkType.anime,
    title: '葬送的芙莉莲',
    extra: {'bangumiId': 1},
  );

  test('round-trips through JSON including dirty/deleted', () {
    final record = FollowRecord(
      work: work,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      dirty: true,
    );
    final restored = FollowRecord.fromJson(record.toJson());
    expect(restored.work.id, 'w1');
    expect(restored.work.bangumiId, 1);
    expect(restored.updatedAt.millisecondsSinceEpoch, 1700000000000);
    expect(restored.deleted, isFalse);
    expect(restored.dirty, isTrue);
  });

  test('copyWith changes only the named flags', () {
    final record = FollowRecord(
        work: work, updatedAt: DateTime.fromMillisecondsSinceEpoch(1));
    final marked = record.copyWith(deleted: true, dirty: true);
    expect(marked.deleted, isTrue);
    expect(marked.dirty, isTrue);
    expect(marked.work.id, 'w1');
    expect(marked.updatedAt.millisecondsSinceEpoch, 1);
  });
}
