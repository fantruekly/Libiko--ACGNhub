Map<String, String> _chapters(dynamic raw) {
  final out = <String, String>{};
  void add(dynamic value) {
    if (value is! Map) return;
    for (final entry in value.entries) {
      final child = entry.value;
      if (child is Map) {
        add(child);
      } else {
        out[entry.key.toString()] = child?.toString() ?? '';
      }
    }
  }

  add(raw);
  return out;
}

List<String> _stringList(dynamic raw) {
  final out = <String>[];
  void add(dynamic value) {
    if (value is List) {
      for (final item in value) {
        add(item);
      }
    } else if (value is Map) {
      for (final item in value.values) {
        add(item);
      }
    } else if (value != null) {
      final text = value.toString();
      if (text.isNotEmpty) out.add(text);
    }
  }

  add(raw);
  return out;
}

class Comic {
  final String id;
  final String title;
  final String? subtitle;
  final String? cover;
  final List<String> tags;
  final String? description;

  const Comic({
    required this.id,
    required this.title,
    this.subtitle,
    this.cover,
    this.tags = const [],
    this.description,
  });

  factory Comic.fromJs(Map<dynamic, dynamic> json) => Comic(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        subtitle: (json['subtitle'] ?? json['subTitle'])?.toString(),
        cover: json['cover']?.toString(),
        tags: _stringList(json['tags']),
        description: json['description']?.toString(),
      );

  factory Comic.fromJson(Map<String, dynamic> json) => Comic(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        subtitle: json['subtitle']?.toString(),
        cover: json['cover']?.toString(),
        tags: _stringList(json['tags']),
        description: json['description']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (subtitle != null) 'subtitle': subtitle,
        if (cover != null) 'cover': cover,
        if (tags.isNotEmpty) 'tags': tags,
        if (description != null) 'description': description,
      };
}

class ComicDetails {
  final String id;
  final String title;
  final String? subtitle;
  final String? cover;
  final List<String> tags;
  final String? description;
  final Map<String, String> chapters;
  final List<String> recommendIds;

  const ComicDetails({
    required this.id,
    required this.title,
    this.subtitle,
    this.cover,
    this.tags = const [],
    this.description,
    this.chapters = const {},
    this.recommendIds = const [],
  });

  factory ComicDetails.fromJs(Map<dynamic, dynamic> json) => ComicDetails(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        subtitle: (json['subtitle'] ?? json['subTitle'])?.toString(),
        cover: json['cover']?.toString(),
        tags: _stringList(json['tags']),
        description: json['description']?.toString(),
        chapters: _chapters(json['chapters']),
        recommendIds: _stringList(json['recommend']),
      );
}

class ComicEp {
  final List<String> images;
  const ComicEp({required this.images});

  factory ComicEp.fromJs(Map<dynamic, dynamic> json) => ComicEp(
        images:
            (json['images'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
      );
}

class ImageLoadingConfig {
  final String? url;
  final String? method;
  final dynamic data;
  final Map<String, String>? headers;

  const ImageLoadingConfig({this.url, this.method, this.data, this.headers});

  factory ImageLoadingConfig.fromJs(Map<dynamic, dynamic> json) =>
      ImageLoadingConfig(
        url: json['url']?.toString(),
        method: json['method']?.toString(),
        data: json['data'],
        headers: (json['headers'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        ),
      );
}
