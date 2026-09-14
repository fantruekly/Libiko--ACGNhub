List<String> _stringList(dynamic raw) {
  if (raw is List) {
    return raw.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
  }
  return const [];
}

class Novel {
  final String id;
  final String title;
  final String? author;
  final String? coverUrl;
  final List<String> tags;
  final String? summary;
  final Map<String, dynamic> extra;

  const Novel({
    required this.id,
    required this.title,
    this.author,
    this.coverUrl,
    this.tags = const [],
    this.summary,
    this.extra = const {},
  });

  factory Novel.fromJson(Map<String, dynamic> json) => Novel(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        author: json['author']?.toString(),
        coverUrl: json['coverUrl']?.toString(),
        tags: _stringList(json['tags']),
        summary: json['summary']?.toString(),
        extra: (json['extra'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (author != null) 'author': author,
        if (coverUrl != null) 'coverUrl': coverUrl,
        if (tags.isNotEmpty) 'tags': tags,
        if (summary != null) 'summary': summary,
        if (extra.isNotEmpty) 'extra': extra,
      };
}

class NovelSection {
  final String title;
  final List<Novel> items;
  const NovelSection({required this.title, required this.items});
}

class NovelHome {
  final List<NovelSection> sections;
  const NovelHome({required this.sections});
}

class NovelList {
  final List<Novel> items;
  final int page;
  final bool hasMore;
  const NovelList({required this.items, required this.page, required this.hasMore});
}

enum NovelBrowseKind { ranking, bunko }

class NovelBrowse {
  final NovelBrowseKind kind;
  final String key;
  const NovelBrowse(this.kind, this.key);
}

class NovelDetail {
  final Novel novel;
  final Map<String, String> chapters;
  const NovelDetail({required this.novel, required this.chapters});
}

class NovelChapter {
  final String title;
  final String content;
  const NovelChapter({required this.title, required this.content});
}
