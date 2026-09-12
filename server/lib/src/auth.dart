import 'package:bcrypt/bcrypt.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class Auth {
  Auth(this.secret);

  final String secret;

  static const accessTtl = Duration(minutes: 15);
  static const refreshTtl = Duration(days: 30);

  String hashPassword(String password) =>
      BCrypt.hashpw(password, BCrypt.gensalt());

  bool verifyPassword(String password, String hash) {
    try {
      return BCrypt.checkpw(password, hash);
    } catch (_) {
      return false;
    }
  }

  String issueAccessToken(int userId) => _issue(userId, 'access', accessTtl);

  String issueRefreshToken(int userId) => _issue(userId, 'refresh', refreshTtl);

  String _issue(int userId, String typ, Duration ttl) {
    final jwt = JWT({
      'sub': userId,
      'typ': typ,
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    });
    return jwt.sign(SecretKey(secret), expiresIn: ttl);
  }

  /// Returns the token's user id, or `null` when the token is malformed,
  /// expired, signed with another secret, or of the wrong [type].
  int? verifyToken(String token, {String type = 'access'}) {
    try {
      final payload =
          JWT.verify(token, SecretKey(secret)).payload as Map<String, dynamic>;
      if (payload['typ'] != type) return null;
      final sub = payload['sub'];
      if (sub is int) return sub;
      return int.tryParse('$sub');
    } catch (_) {
      return null;
    }
  }
}
