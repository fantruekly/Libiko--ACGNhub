import 'package:libiko_server/src/auth.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:test/test.dart';

void main() {
  final auth = Auth('test-secret');

  test('hashes and verifies a password', () {
    final hash = auth.hashPassword('hunter2');
    expect(hash, isNot('hunter2'));
    expect(auth.verifyPassword('hunter2', hash), isTrue);
    expect(auth.verifyPassword('wrong', hash), isFalse);
  });

  test('verifyPassword returns false for a malformed hash', () {
    expect(auth.verifyPassword('x', 'not-a-hash'), isFalse);
  });

  test('issues and verifies an access token', () {
    final token = auth.issueAccessToken(42);
    expect(auth.verifyToken(token), 42);
  });

  test('a refresh token is not accepted as an access token', () {
    final refresh = auth.issueRefreshToken(42);
    expect(auth.verifyToken(refresh), isNull);
    expect(auth.verifyToken(refresh, type: 'refresh'), 42);
  });

  test('rejects a token signed with another secret', () {
    final other = Auth('other-secret');
    expect(auth.verifyToken(other.issueAccessToken(42)), isNull);
  });

  test('rejects a malformed token', () {
    expect(auth.verifyToken('not.a.jwt'), isNull);
  });

  test('rejects an expired token', () {
    final expired = JWT({'sub': 1, 'typ': 'access'}).sign(
      SecretKey('test-secret'),
      expiresIn: const Duration(seconds: -1),
    );
    expect(auth.verifyToken(expired), isNull);
  });
}
