import 'dart:convert';

/// A Kazumi-compatible source rule: XPath selectors plus the URLs needed to
/// search a site and list its episodes. Unknown JSON keys are ignored so that
/// Kazumi plugin files import cleanly.
class SourceRule {
  final String name;
  final String baseUrl;
  final String searchUrl;
  final String searchList;
  final String searchName;
  final String searchResult;
  final String chapterRoads;
  final String chapterResult;
  final String? userAgent;

  const SourceRule({
    required this.name,
    required this.baseUrl,
    required this.searchUrl,
    required this.searchList,
    required this.searchName,
    required this.searchResult,
    required this.chapterRoads,
    required this.chapterResult,
    this.userAgent,
  });

  String get id => 'rule:$name';

  factory SourceRule.fromJson(Map<String, dynamic> json) {
    String req(String key) {
      final v = json[key];
      if (v is! String || v.trim().isEmpty) {
        throw FormatException('缺少或非法的字段: $key');
      }
      return v.trim();
    }

    final ua = json['userAgent'];
    return SourceRule(
      name: req('name'),
      baseUrl: req('baseURL'),
      searchUrl: req('searchURL'),
      searchList: req('searchList'),
      searchName: req('searchName'),
      searchResult: req('searchResult'),
      chapterRoads: req('chapterRoads'),
      chapterResult: req('chapterResult'),
      userAgent: (ua is String && ua.trim().isNotEmpty) ? ua.trim() : null,
    );
  }

  factory SourceRule.fromJsonString(String source) {
    final decoded = json.decode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('规则必须是 JSON 对象');
    }
    return SourceRule.fromJson(decoded);
  }

  String buildSearchUrl(String keyword) =>
      searchUrl.replaceAll('@keyword', Uri.encodeComponent(keyword));
}
