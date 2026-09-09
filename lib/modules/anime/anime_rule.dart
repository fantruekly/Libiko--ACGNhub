import 'dart:convert';
import 'package:html/dom.dart' as dom;

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
  static String? extractText(dynamic node, String xpath) {
    if (node == null) return null;
    if (xpath.endsWith('/text()')) {
      final attrXpath = xpath.replaceAll('/text()', '');
      final attr = _extractAttribute(node, attrXpath);
      if (attr != null) return attr;
    }
    if (xpath.startsWith('@')) {
      return _extractAttribute(node, xpath);
    }
    if (xpath.endsWith('/@src')) {
      return _extractAttribute(node, xpath);
    }
    if (xpath.endsWith('/@href')) {
      return _extractAttribute(node, xpath);
    }
    final found = _findNode(node, xpath);
    if (found != null) {
      if (found is dom.Element) {
        return found.text.trim();
      }
    }
    if (node is dom.Element) {
      return node.text.trim();
    }
    return null;
  }

  static String? _extractAttribute(dynamic node, String xpath) {
    if (node is dom.Element) {
      if (xpath.contains('/@src')) {
        return node.attributes['src'];
      }
      if (xpath.contains('/@href')) {
        return node.attributes['href'];
      }
      if (xpath.startsWith('@')) {
        final attrName = xpath.substring(1);
        return node.attributes[attrName];
      }
    }
    return null;
  }

  static List<dom.Element> findNodes(dynamic root, String xpath) {
    if (root == null) return [];
    if (root is dom.Document) {
      return _queryAll(root, xpath);
    }
    if (root is dom.Element) {
      return _queryAll(root, xpath);
    }
    return [];
  }

  static List<dom.Element> _queryAll(dynamic parent, String xpath) {
    final results = <dom.Element>[];
    String selector = xpath;

    if (selector.startsWith('.//')) {
      selector = selector.substring(1);
    }

    if (selector.startsWith('//')) {
      selector = selector.substring(2);
    }

    if (!selector.contains('[') && !selector.contains('/')) {
      if (parent is dom.Element) {
        results.addAll(parent.querySelectorAll(selector));
      }
      if (parent is dom.Document) {
        results.addAll(parent.querySelectorAll(selector));
      }
      return results;
    }

    final attrMatch = RegExp(r"^(\w+)\[@(\w+)='([^']*)'\]$").firstMatch(selector);
    if (attrMatch != null) {
      final tag = attrMatch.group(1)!;
      final attr = attrMatch.group(2)!;
      final value = attrMatch.group(3)!;
      if (parent is dom.Element) {
        results.addAll(parent.querySelectorAll(tag).where((e) => e.attributes[attr] == value));
      }
      if (parent is dom.Document) {
        results.addAll(parent.querySelectorAll(tag).where((e) => e.attributes[attr] == value));
      }
      return results;
    }

    final nestedMatch = RegExp(r"^(\w+)\[@(\w+)='([^']*)'\]/(\w+)$").firstMatch(selector);
    if (nestedMatch != null) {
      final parentTag = nestedMatch.group(1)!;
      final parentAttr = nestedMatch.group(2)!;
      final parentValue = nestedMatch.group(3)!;
      final childTag = nestedMatch.group(4)!;
      List<dom.Element> parents;
      if (parent is dom.Element) {
        parents = parent.querySelectorAll(parentTag).where((e) => e.attributes[parentAttr] == parentValue).toList();
      } else if (parent is dom.Document) {
        parents = parent.querySelectorAll(parentTag).where((e) => e.attributes[parentAttr] == parentValue).toList();
      } else {
        return [];
      }
      for (final p in parents) {
        results.addAll(p.querySelectorAll(childTag));
      }
      return results;
    }

    return results;
  }

  static dom.Element? _findNode(dynamic root, String xpath) {
    final nodes = findNodes(root, xpath);
    return nodes.isNotEmpty ? nodes.first : null;
  }
}