import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/account/account_models.dart';

void main() {
  test('AccountUser round-trips through JSON', () {
    const user = AccountUser(id: 7, username: 'alice');
    final restored = AccountUser.fromJson(user.toJson());
    expect(restored.id, 7);
    expect(restored.username, 'alice');
  });

  test('AuthSession parses the backend response', () {
    final session = AuthSession.fromJson({
      'token': 'access-1',
      'refreshToken': 'refresh-1',
      'user': {'id': 3, 'username': 'bob'},
    });
    expect(session.token, 'access-1');
    expect(session.refreshToken, 'refresh-1');
    expect(session.user.id, 3);
    expect(session.user.username, 'bob');
  });
}
