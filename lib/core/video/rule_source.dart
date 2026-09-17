import 'package:flutter/foundation.dart';

import 'source_rule.dart';
import 'video_source.dart';
import 'webview_scraper.dart';

/// A [VideoSource] backed by a Kazumi-compatible [SourceRule]. The search and
/// chapter pages are rendered in a headless WebView, then XPath-extracted.
class RuleVideoSource implements VideoSource {
  final SourceRule rule;
  final WebviewScraper _scraper;

  RuleVideoSource(this.rule, {WebviewScraper? scraper})
      : _scraper = scraper ?? WebviewScraper();

  @override
  String get id => rule.id;

  @override
  String get name => rule.name;

  @override
  String get baseUrl => rule.baseUrl;

  @override
  Future<List<VideoItem>> search(String keyword) async {
    final result = await _scraper.fetchJson(
      url: rule.buildSearchUrl(keyword),
      script: buildSearchScript(rule),
      userAgent: rule.userAgent,
    );
    return mapSearch(rule, result);
  }

  @override
  Future<List<VideoEpisode>> episodes(String detailUrl) async {
    final result = await _scraper.fetchJson(
      url: detailUrl,
      script: buildEpisodesScript(rule),
      userAgent: rule.userAgent,
    );
    return mapEpisodes(rule, result);
  }

  @visibleForTesting
  static List<VideoItem> mapSearch(SourceRule rule, dynamic json) {
    if (json is! List) return const [];
    final items = <VideoItem>[];
    for (final row in json) {
      if (row is! Map) continue;
      final title = (row['name'] ?? '').toString().trim();
      final href = (row['href'] ?? '').toString().trim();
      if (title.isEmpty || href.isEmpty) continue;
      final url = resolveUrl(href, rule.baseUrl);
      items.add(VideoItem(id: url, title: title, detailUrl: url));
    }
    return items;
  }

  @visibleForTesting
  static List<VideoEpisode> mapEpisodes(SourceRule rule, dynamic json) {
    if (json is! List) return const [];
    final eps = <VideoEpisode>[];
    for (final row in json) {
      if (row is! Map) continue;
      final href = (row['href'] ?? '').toString().trim();
      if (href.isEmpty) continue;
      final rawTitle = (row['title'] ?? '').toString().trim();
      final url = resolveUrl(href, rule.baseUrl);
      eps.add(VideoEpisode(
        id: url,
        title: rawTitle.isEmpty ? '第${eps.length + 1}集' : rawTitle,
        index: eps.length,
        playUrl: url,
        userAgent: rule.userAgent,
        referer: rule.referer,
      ));
    }
    return eps;
  }

  @visibleForTesting
  static String resolveUrl(String url, String base) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('//')) return 'https:$url';
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    if (url.startsWith('/')) return '$b$url';
    return '$b/$url';
  }
}
