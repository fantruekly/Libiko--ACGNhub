import 'package:acgnhub_server/src/database.dart';
import 'package:sqlite3/sqlite3.dart' hide Database;
import 'package:test/test.dart';

void main() {
  late Database db;

  setUp(() => db = Database.open(':memory:'));
  tearDown(() => db.dispose());

  test('creates a user and finds it by name and id', () {
    final id = db.createUser('alice', 'hash');
    expect(id, greaterThan(0));
    expect(db.findUserByName('alice')!['username'], 'alice');
    expect(db.findUserById(id)!['username'], 'alice');
    expect(db.findUserByName('nobody'), isNull);
  });

  test('rejects a duplicate username', () {
    db.createUser('alice', 'hash');
    expect(() => db.createUser('alice', 'other'), throwsA(isA<SqliteException>()));
  });

  test('currentSeq starts at 0 and follows the counter', () {
    final id = db.createUser('alice', 'hash');
    expect(db.currentSeq(id), 0);
  });

  test('upsertFollow stores and lists, and delete tombstones it', () {
    final id = db.createUser('alice', 'hash');
    db.upsertFollow(
        userId: id, workId: 'w1', work: {'id': 'w1', 'title': 'A'}, updatedAt: 100);
    db.upsertFollow(
        userId: id, workId: 'w2', work: {'id': 'w2', 'title': 'B'}, updatedAt: 200);

    expect(db.listFollows(id).map((r) => r['work_id']).toList(), ['w2', 'w1']);

    db.upsertFollow(
        userId: id, workId: 'w1', work: {'id': 'w1'}, updatedAt: 300, deleted: true);
    expect(db.listFollows(id).map((r) => r['work_id']).toList(), ['w2']);
  });

  test('upsertFollow keeps the newer row on an older write (LWW)', () {
    final id = db.createUser('alice', 'hash');
    db.upsertFollow(
        userId: id, workId: 'w1', work: {'id': 'w1', 'title': 'new'}, updatedAt: 200);
    final stored = db.upsertFollow(
        userId: id, workId: 'w1', work: {'id': 'w1', 'title': 'old'}, updatedAt: 100);

    expect(stored['client_updated_at'], 200);
    expect(stored['work_json'], contains('new'));
    expect(db.currentSeq(id), 1);
  });

  test('followsSince returns rows whose seq is greater, including tombstones', () {
    final id = db.createUser('alice', 'hash');
    db.upsertFollow(userId: id, workId: 'w1', work: {'id': 'w1'}, updatedAt: 100);
    final afterFirst = db.currentSeq(id);
    db.upsertFollow(
        userId: id, workId: 'w1', work: {'id': 'w1'}, updatedAt: 200, deleted: true);

    expect(db.followsSince(id, 0), hasLength(1));
    final delta = db.followsSince(id, afterFirst);
    expect(delta, hasLength(1));
    expect(delta.first['deleted'], 1);
  });

  test('upsertHistory stores and lists by watchedAt desc; clearHistory empties', () {
    final id = db.createUser('alice', 'hash');
    db.upsertHistory(
        userId: id, workId: 'w1', work: {'id': 'w1'}, episodeTitle: '第1集',
        episodeIndex: 0, watchedAt: 100, updatedAt: 100);
    db.upsertHistory(
        userId: id, workId: 'w2', work: {'id': 'w2'}, episodeTitle: '第9集',
        episodeIndex: 8, watchedAt: 300, updatedAt: 300);

    expect(db.listHistory(id).map((r) => r['work_id']).toList(), ['w2', 'w1']);
    expect(db.historySince(id, 0), hasLength(2));

    final cleared = db.clearHistory(id, 400);
    expect(cleared, 2);
    expect(db.listHistory(id), isEmpty);
    expect(db.historySince(id, 0).every((r) => r['deleted'] == 1), isTrue);
  });

  test('upsertHistory keeps the newer row on an older write (LWW)', () {
    final id = db.createUser('alice', 'hash');
    db.upsertHistory(
        userId: id, workId: 'w1', work: {'id': 'w1'}, episodeTitle: '第5集',
        episodeIndex: 4, watchedAt: 200, updatedAt: 200);
    final stored = db.upsertHistory(
        userId: id, workId: 'w1', work: {'id': 'w1'}, episodeTitle: '第1集',
        episodeIndex: 0, watchedAt: 100, updatedAt: 100);

    expect(stored['episode_title'], '第5集');
    expect(stored['client_updated_at'], 200);
  });

  test('rows are scoped per user', () {
    final a = db.createUser('alice', 'hash');
    final b = db.createUser('bob', 'hash');
    db.upsertFollow(userId: a, workId: 'w1', work: {'id': 'w1'}, updatedAt: 100);
    expect(db.listFollows(a), hasLength(1));
    expect(db.listFollows(b), isEmpty);
  });
}
