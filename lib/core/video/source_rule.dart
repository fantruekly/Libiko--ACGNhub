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
  final String? referer;
  final bool useLegacyParser;
  final String searchMode;
  final String chapterMode;
  final Map<String, dynamic>? searchApiConfig;
  final Map<String, dynamic>? chapterApiConfig;

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
    this.referer,
    this.useLegacyParser = false,
    this.searchMode = 'xpath',
    this.chapterMode = 'xpath',
    this.searchApiConfig,
    this.chapterApiConfig,
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

    String opt(String key) {
      final v = json[key];
      return v is String ? v.trim() : '';
    }

    Map<String, dynamic>? apiConfig(String key) {
      final v = json[key];
      return v is Map ? Map<String, dynamic>.from(v) : null;
    }

    final searchMode = json['searchMode'] == 'api' ? 'api' : 'xpath';
    final chapterMode = json['chapterMode'] == 'api' ? 'api' : 'xpath';
    final isXpathSearch = searchMode == 'xpath';
    final isXpathChapter = chapterMode == 'xpath';

    final ua = json['userAgent'];
    return SourceRule(
      name: req('name'),
      baseUrl: req('baseURL'),
      searchUrl: isXpathSearch ? req('searchURL') : opt('searchURL'),
      searchList: isXpathSearch ? req('searchList') : opt('searchList'),
      searchName: isXpathSearch ? req('searchName') : opt('searchName'),
      searchResult: isXpathSearch ? req('searchResult') : opt('searchResult'),
      chapterRoads: isXpathChapter ? req('chapterRoads') : opt('chapterRoads'),
      chapterResult:
          isXpathChapter ? req('chapterResult') : opt('chapterResult'),
      userAgent: (ua is String && ua.trim().isNotEmpty) ? ua.trim() : null,
      referer: (json['referer'] is String &&
              (json['referer'] as String).trim().isNotEmpty)
          ? (json['referer'] as String).trim()
          : null,
      useLegacyParser: json['useLegacyParser'] == true,
      searchMode: searchMode,
      chapterMode: chapterMode,
      searchApiConfig: apiConfig('searchApiConfig'),
      chapterApiConfig: apiConfig('chapterApiConfig'),
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
