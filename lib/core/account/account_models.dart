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

class FollowItem {
  final Map<String, dynamic> work;
  final int updatedAt;
  final bool deleted;
  const FollowItem(
      {required this.work, required this.updatedAt, required this.deleted});

  factory FollowItem.fromJson(Map<String, dynamic> json) => FollowItem(
        work: json['work'] as Map<String, dynamic>? ?? const {},
        updatedAt: json['updatedAt'] as int? ?? 0,
        deleted: json['deleted'] as bool? ?? false,
      );
}

class HistoryItem {
  final Map<String, dynamic> work;
  final String episodeTitle;
  final int episodeIndex;
  final int watchedAt;
  final int updatedAt;
  final bool deleted;
  const HistoryItem({
    required this.work,
    required this.episodeTitle,
    required this.episodeIndex,
    required this.watchedAt,
    required this.updatedAt,
    required this.deleted,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
        work: json['work'] as Map<String, dynamic>? ?? const {},
        episodeTitle: json['episodeTitle'] as String? ?? '',
        episodeIndex: json['episodeIndex'] as int? ?? 0,
        watchedAt: json['watchedAt'] as int? ?? 0,
        updatedAt: json['updatedAt'] as int? ?? 0,
        deleted: json['deleted'] as bool? ?? false,
      );
}

class SyncPage {
  final List<FollowItem> follows;
  final List<HistoryItem> history;
  final int nextSeq;
  const SyncPage(
      {required this.follows, required this.history, required this.nextSeq});

  factory SyncPage.fromJson(Map<String, dynamic> json) => SyncPage(
        follows: (json['follows'] as List<dynamic>? ?? const [])
            .map((e) => FollowItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        history: (json['history'] as List<dynamic>? ?? const [])
            .map((e) => HistoryItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        nextSeq: json['nextSeq'] as int? ?? 0,
      );
}
