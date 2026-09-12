import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acgnhub/core/models/follow_record.dart';
import 'package:acgnhub/core/models/work.dart';
import 'package:acgnhub/core/services/follow_manager.dart';
import 'package:acgnhub/core/storage/database.dart';

Work _work(String id) => Work(
      id: id,
      sourceId: 'bangumi',
      sourceName: 'Bangumi',
      type: WorkType.anime,
      title: 'Title $id',
    );

FollowRecord _record(String id, int ms, {bool dirty = false}) => FollowRecord(
      work: _work(id),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(ms),
      dirty: dirty,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('merge keeps a newer local record and takes a newer server record', () {
    final merged = FollowManager.merge(
      [_record('a', 300, dirty: true), _record('b', 100, dirty: true)],
      [_record('a', 200), _record('b', 500), _record('c', 400)],
    );
    final byId = {for (final r in merged) r.work.id: r};
    expect(byId['a']!.updatedAt.millisecondsSinceEpoch, 300); // local newer
    expect(byId['a']!.dirty, isTrue); // kept local stays dirty
    expect(byId['b']!.updatedAt.millisecondsSinceEpoch, 500); // server newer
    expect(byId['b']!.dirty, isFalse);
    expect(byId['c']!.updatedAt.millisecondsSinceEpoch, 400); // new
  });

  test('merge applies a server tombstone', () {
    final merged = FollowManager.merge(
      [_record('a', 100)],
      [
        FollowRecord(
            work: _work('a'),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(200),
            deleted: true)
      ],
    );
    expect(merged.single.deleted, isTrue);
  });

  test('follow/unfollow/dirty/markSynced round-trip through storage', () async {
    await AppDatabase.init();
    final manager = FollowManager();

    await manager.follow(_work('a'));
    expect(manager.isFollowing('a'), isTrue);
    expect(manager.dirty().map((r) => r.work.id), ['a']);

    await manager.markSynced({
      for (final r in manager.dirty()) r.work.id: r.updatedAt,
    });
    expect(manager.dirty(), isEmpty);
    expect(manager.all().single.dirty, isFalse);

    await manager.unfollow('a');
    expect(manager.isFollowing('a'), isFalse);
    expect(manager.dirty().single.deleted, isTrue);
    expect(manager.all(), isEmpty);
  });

  test('markSynced ignores a stale pushed timestamp', () async {
    await AppDatabase.init();
    final manager = FollowManager();
    await manager.follow(_work('a'));
    final current = manager.dirty().single;

    await manager.markSynced({
      'a': current.updatedAt.subtract(const Duration(seconds: 1)),
    });
    expect(manager.dirty(), isNotEmpty);

    await manager.markSynced({'a': current.updatedAt});
    expect(manager.dirty(), isEmpty);
  });

  test('all() orders by updatedAt descending', () async {
    await AppDatabase.init();
    final manager = FollowManager();
    await manager.follow(_work('a'));
    await Future.delayed(const Duration(milliseconds: 2));
    await manager.follow(_work('b'));
    expect(manager.all().map((r) => r.work.id), ['b', 'a']);
  });
}
