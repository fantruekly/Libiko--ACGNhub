class AccountUser {
  final int id;
  final String username;

  const AccountUser({required this.id, required this.username});

  factory AccountUser.fromJson(Map<String, dynamic> json) => AccountUser(
        id: json['id'] as int,
        username: json['username'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'username': username};
}

class AuthSession {
  final String token;
  final String refreshToken;
  final AccountUser user;

  const AuthSession({
    required this.token,
    required this.refreshToken,
    required this.user,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        token: json['token'] as String,
        refreshToken: json['refreshToken'] as String,
        user: AccountUser.fromJson(json['user'] as Map<String, dynamic>),
      );
}
