enum WorkType { anime, comic, novel, game }

class Work {
  final String id;
  final String sourceId;
  final String sourceName;
  final WorkType type;
  final String title;
  final String? coverUrl;
  final String? summary;
  final List<String> tags;
  final String? author;
  final Map<String, dynamic> extra;

  const Work({
    required this.id,
    required this.sourceId,
    required this.sourceName,
    required this.type,
    required this.title,
    this.coverUrl,
    this.summary,
    this.tags = const [],
    this.author,
    this.extra = const {},
  });

  factory Work.fromJson(Map<String, dynamic> json) => Work(
        id: json['id'] as String,
        sourceId: json['sourceId'] as String,
        sourceName: json['sourceName'] as String,
        type: WorkType.values.byName(json['type'] as String),
        title: json['title'] as String,
        coverUrl: json['coverUrl'] as String?,
        summary: json['summary'] as String?,
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        author: json['author'] as String?,
        extra: json['extra'] as Map<String, dynamic>? ?? {},
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceId': sourceId,
        'sourceName': sourceName,
        'type': type.name,
        'title': title,
        'coverUrl': coverUrl,
        'summary': summary,
        'tags': tags,
        'author': author,
        'extra': extra,
      };

  int? get anilistId => extra['anilistId'] as int?;
  int? get malId => extra['malId'] as int?;
  String? get bannerUrl => extra['bannerUrl'] as String?;
}