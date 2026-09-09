import 'dart:convert';

class RuleSection {
  final String url;
  final String list;
  final String title;
  final String cover;
  final String link;
  final String? nextPage;

  const RuleSection({
    required this.url,
    required this.list,
    required this.title,
    required this.cover,
    required this.link,
    this.nextPage,
  });

  factory RuleSection.fromJson(Map<String, dynamic> json) => RuleSection(
        url: json['url'] as String,
        list: json['list'] as String,
        title: json['title'] as String,
        cover: json['cover'] as String,
        link: json['link'] as String,
        nextPage: json['nextPage'] as String?,
      );
}

class DetailRule {
  final String summary;
  final String? tags;
  final String? cover;
  final String? author;
  final String chapters;
  final String chapterTitle;
  final String chapterLink;

  const DetailRule({
    required this.summary,
    this.tags,
    this.cover,
    this.author,
    required this.chapters,
    required this.chapterTitle,
    required this.chapterLink,
  });

  factory DetailRule.fromJson(Map<String, dynamic> json) => DetailRule(
        summary: json['summary'] as String,
        tags: json['tags'] as String?,
        cover: json['cover'] as String?,
        author: json['author'] as String?,
        chapters: json['chapters'] as String,
        chapterTitle: json['chapterTitle'] as String,
        chapterLink: json['chapterLink'] as String,
      );
}

class VideoRule {
  final String playUrl;
  final String? resolutions;

  const VideoRule({required this.playUrl, this.resolutions});

  factory VideoRule.fromJson(Map<String, dynamic> json) => VideoRule(
        playUrl: json['playUrl'] as String,
        resolutions: json['resolutions'] as String?,
      );
}

class AnimeRule {
  final String name;
  final String baseUrl;
  final RuleSection search;
  final DetailRule detail;
  final VideoRule video;

  const AnimeRule({
    required this.name,
    required this.baseUrl,
    required this.search,
    required this.detail,
    required this.video,
  });

  factory AnimeRule.fromJson(Map<String, dynamic> json) => AnimeRule(
        name: json['name'] as String,
        baseUrl: json['baseUrl'] as String,
        search: RuleSection.fromJson(json['search'] as Map<String, dynamic>),
        detail: DetailRule.fromJson(json['detail'] as Map<String, dynamic>),
        video: VideoRule.fromJson(json['video'] as Map<String, dynamic>),
      );

  factory AnimeRule.fromJsonString(String jsonString) {
    return AnimeRule.fromJson(json.decode(jsonString) as Map<String, dynamic>);
  }

  String toJsonString() {
    return json.encode({
      'name': name,
      'baseUrl': baseUrl,
      'search': {
        'url': search.url,
        'list': search.list,
        'title': search.title,
        'cover': search.cover,
        'link': search.link,
        if (search.nextPage != null) 'nextPage': search.nextPage,
      },
      'detail': {
        'summary': detail.summary,
        if (detail.tags != null) 'tags': detail.tags,
        if (detail.cover != null) 'cover': detail.cover,
        if (detail.author != null) 'author': detail.author,
        'chapters': detail.chapters,
        'chapterTitle': detail.chapterTitle,
        'chapterLink': detail.chapterLink,
      },
      'video': {
        'playUrl': video.playUrl,
        if (video.resolutions != null) 'resolutions': video.resolutions,
      },
    });
  }
}

class XPathParser {
  /// Extract text from HTML node using XPath-like selector.
  /// Supports: //tag[@attr='value']/text(), .//tag/text(), //tag/@attr
  static String? extractText(
    dynamic node,
    String xpath,
  ) {
    if (node == null) return null;
    // Use xml package for XPath evaluation
    return null; // Stub - implemented in Task 9
  }

  /// Find all nodes matching XPath selector
  static List<dynamic> findNodes(dynamic root, String xpath) {
    // Stub - implemented in Task 9
    return [];
  }
}