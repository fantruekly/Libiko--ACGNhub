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
}
