class Chapter {
  final String id;
  final String workId;
  final String title;
  final int index;
  final String? url;
  final Map<String, dynamic> extra;

  const Chapter({
    required this.id,
    required this.workId,
    required this.title,
    required this.index,
    this.url,
    this.extra = const {},
  });

  factory Chapter.fromJson(Map<String, dynamic> json) => Chapter(
        id: json['id'] as String,
        workId: json['workId'] as String,
        title: json['title'] as String,
        index: json['index'] as int,
        url: json['url'] as String?,
        extra: json['extra'] as Map<String, dynamic>? ?? {},
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'workId': workId,
        'title': title,
        'index': index,
        'url': url,
        'extra': extra,
      };
}