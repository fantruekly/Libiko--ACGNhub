import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'cancellation.dart';
import 'video_source.dart';

class GimySource implements VideoSource {
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  final Dio _dio;

  GimySource({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://gimy.tv',
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 20),
              headers: {'User-Agent': _ua},
            ));

  @override
  String get id => 'gimy';

  @override
  String get name => 'gimy';

  @override
  String get baseUrl => 'https://gimy.tv';

  @override
  Future<List<VideoItem>> search(String keyword,
      {CancellationToken? cancel}) async {
    if (cancel?.isCancelled ?? false) return const [];
    final res = await _dio
        .get('/search/-------------.html', queryParameters: {'wd': keyword});
    if (cancel?.isCancelled ?? false) return const [];
    return parseSearch(res.data.toString());
  }

  @override
  Future<List<VideoEpisode>> episodes(String detailUrl,
      {CancellationToken? cancel}) async {
    if (cancel?.isCancelled ?? false) return const [];
    final res = await _dio.get(detailUrl);
    if (cancel?.isCancelled ?? false) return const [];
    return parseEpisodes(res.data.toString(), baseUrl);
  }

  @visibleForTesting
  static List<VideoItem> parseSearch(String html) {
    final doc = html_parser.parse(html);
    final items = <VideoItem>[];
    for (final a in doc.querySelectorAll('a[href*="/vod/"]')) {
      final href = a.attributes['href'] ?? '';
      final title = a.text.trim();
      if (href.isEmpty || title.isEmpty) continue;
      final id = RegExp(r'/vod/(\d+)').firstMatch(href)?.group(1) ?? href;
      items.add(VideoItem(
        id: id,
        title: title,
        cover: _ancestorImg(a),
        detailUrl: _abs(href, 'https://gimy.tv'),
      ));
    }
    return items;
  }

  @visibleForTesting
  static List<VideoEpisode> parseEpisodes(String html, String base) {
    final doc = html_parser.parse(html);
    final byRoad = <String, List<VideoEpisode>>{};
    for (final a in doc.querySelectorAll('a[href*="/ep-"]')) {
      final href = a.attributes['href'] ?? '';
      if (href.isEmpty) continue;
      final road =
          RegExp(r'/ep-\d+-(\d+)-\d+').firstMatch(href)?.group(1) ?? '1';
      final list = byRoad.putIfAbsent(road, () => []);
      final text = a.text.trim();
      list.add(VideoEpisode(
        id: href,
        title: text.isEmpty ? '第${list.length + 1}集' : text,
        index: list.length,
        playUrl: _abs(href, base),
      ));
    }
    return byRoad.isEmpty ? const [] : byRoad.values.first;
  }

  static String? _ancestorImg(dom.Element a) {
    dom.Element? node = a.parent;
    for (var depth = 0; node != null && depth < 4; depth++) {
      final img = node.querySelector('img');
      final src = img?.attributes['src'] ?? img?.attributes['data-src'];
      if (src != null && src.isNotEmpty) return src;
      node = node.parent;
    }
    return null;
  }

  static String _abs(String url, String base) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('/')) return '$base$url';
    return '$base/$url';
  }
}
