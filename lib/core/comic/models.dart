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
        subtitle: json['subtitle']?.toString(),
        cover: json['cover']?.toString(),
        tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        description: json['description']?.toString(),
      );
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
        subtitle: json['subtitle']?.toString(),
        cover: json['cover']?.toString(),
        tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        description: json['description']?.toString(),
        chapters: (json['chapters'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            ) ??
            const {},
        recommendIds:
            (json['recommend'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
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
