List<String> _stringList(dynamic raw) {
  if (raw is List) {
    return raw
        .map((e) => e?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return const [];
}

class Game {
  final String id;
  final String title;
  final String? coverUrl;
  final String? summary;
  final String? category;
  final List<String> tags;
  final DateTime? publishedAt;
  final int? views;
  final Map<String, dynamic> extra;

  const Game({
    required this.id,
    required this.title,
    this.coverUrl,
    this.summary,
    this.category,
    this.tags = const [],
    this.publishedAt,
    this.views,
    this.extra = const {},
  });

  factory Game.fromJson(Map<String, dynamic> json) => Game(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        coverUrl: json['coverUrl']?.toString(),
        summary: json['summary']?.toString(),
        category: json['category']?.toString(),
        tags: _stringList(json['tags']),
        publishedAt: json['publishedAt'] == null
            ? null
            : DateTime.tryParse(json['publishedAt'].toString()),
        views: json['views'] is int
            ? json['views'] as int
            : int.tryParse('${json['views']}'),
        extra: (json['extra'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (coverUrl != null) 'coverUrl': coverUrl,
        if (summary != null) 'summary': summary,
        if (category != null) 'category': category,
        if (tags.isNotEmpty) 'tags': tags,
        if (publishedAt != null) 'publishedAt': publishedAt!.toIso8601String(),
        if (views != null) 'views': views,
        if (extra.isNotEmpty) 'extra': extra,
      };
}

class GameBrowseOption {
  final String key;
  final String label;
  const GameBrowseOption({required this.key, required this.label});
}

class GameList {
  final List<Game> items;
  final int page;
  final bool hasMore;
  const GameList({required this.items, required this.page, required this.hasMore});
}

class GameDetail {
  final Game game;
  final String? size;
  final String? platform;
  final DateTime? updatedAt;
  final List<String> paragraphs;
  final List<String> screenshots;
  final String sourceUrl;

  const GameDetail({
    required this.game,
    this.size,
    this.platform,
    this.updatedAt,
    this.paragraphs = const [],
    this.screenshots = const [],
    required this.sourceUrl,
  });
}
