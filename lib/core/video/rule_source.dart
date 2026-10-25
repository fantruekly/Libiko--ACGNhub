import 'package:flutter/foundation.dart';

import 'api_rule.dart';
import 'cancellation.dart';
import 'source_cache.dart';
import 'source_rule.dart';
import 'video_source.dart';
import 'webview_scraper.dart';

/// A [VideoSource] backed by a Kazumi-compatible [SourceRule]. The search and
/// chapter pages are rendered in a headless WebView, then XPath-extracted.
/// Rules whose `searchMode`/`chapterMode` is `api` are sent through
/// [ApiRuleClient] instead.
class RuleVideoSource implements VideoSource {
  final SourceRule rule;
  final WebviewScraper _scraper;
  final ApiRuleClient _api;
  final SourceCache _cache;

  RuleVideoSource(this.rule,
      {WebviewScraper? scraper, ApiRuleClient? apiClient, SourceCache? cache})
      : _scraper = scraper ?? WebviewScraper(),
        _api = apiClient ?? ApiRuleClient(rule),
        _cache = cache ?? sharedSourceCache;

  @override
  String get id => rule.id;

  @override
  String get name => rule.name;

  @override
  String get baseUrl => rule.baseUrl;

  /// Health observers must not label a cache read as a fresh source request.
  bool hasCachedSearch(String keyword) => _cache.search(id, keyword) != null;
  bool hasCachedEpisodes(String detailUrl) =>
      _cache.episodes(id, detailUrl) != null;

  @override
  Future<List<VideoItem>> search(String keyword,
      {CancellationToken? cancel}) async {
    final cached = _cache.search(id, keyword);
    if (cached != null) return cached;
    final List<VideoItem> items;
    if (rule.searchMode == 'api') {
      items = await _api.search(keyword, cancel: cancel);
    } else {
      final result = await _scraper.fetchJson(
        url: rule.buildSearchUrl(keyword),
        script: buildSearchScript(rule),
        userAgent: rule.userAgent,
        cancel: cancel,
      );
      items = mapSearch(rule, result);
    }
    if (!(cancel?.isCancelled ?? false)) _cache.putSearch(id, keyword, items);
    return items;
  }

  @override
  Future<List<VideoEpisode>> episodes(String detailUrl,
      {CancellationToken? cancel}) async {
    final cached = _cache.episodes(id, detailUrl);
    if (cached != null) return cached;
    final List<VideoEpisode> episodes;
    if (rule.chapterMode == 'api') {
      episodes = await _api.episodes(detailUrl, cancel: cancel);
    } else {
      final result = await _scraper.fetchJson(
        url: detailUrl,
        script: buildEpisodesScript(rule),
        userAgent: rule.userAgent,
        cancel: cancel,
      );
      episodes = mapEpisodes(rule, result);
    }
    if (!(cancel?.isCancelled ?? false)) {
      _cache.putEpisodes(id, detailUrl, episodes);
    }
    return episodes;
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
      final legacyRoad = RegExp(r'^线路(\d+)\s+').firstMatch(rawTitle);
      final lineId = row['lineId']?.toString() ??
          (legacyRoad == null
              ? 'road:0'
              : 'road:${int.parse(legacyRoad.group(1)!) - 1}');
      final lineName = row['lineName']?.toString() ??
          (legacyRoad == null ? '线路1' : '线路${legacyRoad.group(1)}');
      final episodeTitle = (row['episodeTitle'] ??
              (legacyRoad == null
                  ? rawTitle
                  : rawTitle.substring(legacyRoad.end)))
          .toString()
          .trim();
      final linePosition = eps.where((e) => e.lineId == lineId).length + 1;
      final url = resolveUrl(href, rule.baseUrl);
      eps.add(VideoEpisode(
        id: url,
        title: episodeTitle.isEmpty ? '第$linePosition集' : rawTitle,
        index: eps.length,
        playUrl: url,
        sourceId: rule.id,
        lineId: lineId,
        lineName: lineName,
        // An absent label is not enough evidence to map across lines.
        episodeKey: episodeKeyFromTitle(episodeTitle),
        userAgent: rule.userAgent,
        referer: rule.referer,
        useLegacyParser: rule.useLegacyParser,
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
