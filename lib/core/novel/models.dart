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

class NovelBrowseOption {
  final String key;
  final String label;
  const NovelBrowseOption({required this.key, required this.label});
}

class NovelBrowseGroup {
  final String label;
  final List<NovelBrowseOption> options;
  const NovelBrowseGroup({required this.label, required this.options});
}

class NovelChapterRef {
  final String id;
  final String title;
  const NovelChapterRef({required this.id, required this.title});
}

class NovelVolume {
  final String? id;
  final String title;
  final String? url;
  final List<NovelChapterRef> chapters;
  const NovelVolume({
    this.id,
    required this.title,
    this.url,
    this.chapters = const [],
  });
}

class NovelDetail {
  final Novel novel;
  final List<NovelVolume> volumes;
  const NovelDetail({required this.novel, required this.volumes});
}

sealed class NovelBlock {
  const NovelBlock();
}

class NovelText extends NovelBlock {
  final String text;
  const NovelText(this.text);
}

class NovelImage extends NovelBlock {
  final String url;
  const NovelImage(this.url);
}

class NovelChapter {
  final String title;
  final List<NovelBlock> blocks;
  const NovelChapter({required this.title, this.blocks = const []});
}
