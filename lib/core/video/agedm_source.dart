import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'video_source.dart';

class AgedmSource implements VideoSource {
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  final Dio _dio;

  AgedmSource({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://www.agedm.io',
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 20),
              headers: {'User-Agent': _ua},
            ));

  @override
  String get id => 'agedm';

  @override
  String get name => 'AGE动漫';

  @override
  String get baseUrl => 'https://www.agedm.io';

  @override
  Future<List<VideoItem>> search(String keyword) async {
    final res = await _dio.get('/search', queryParameters: {'query': keyword});
    return parseSearch(res.data.toString());
  }

  @override
  Future<List<VideoEpisode>> episodes(String detailUrl) async {
    final res = await _dio.get(detailUrl);
    return parseEpisodes(res.data.toString(), baseUrl);
  }

  @visibleForTesting
  static List<VideoItem> parseSearch(String html) {
    final doc = html_parser.parse(html);
    final items = <VideoItem>[];
    for (final a in doc.querySelectorAll('h5.card-title a')) {
      final href = a.attributes['href'] ?? '';
      final title = a.text.trim();
      if (href.isEmpty || title.isEmpty) continue;
      final id = RegExp(r'/detail/(\d+)').firstMatch(href)?.group(1) ?? href;
      items.add(VideoItem(
        id: id,
        title: title,
        cover: _ancestorImg(a),
        detailUrl: _abs(href, 'https://www.agedm.io'),
      ));
    }
    return items;
  }

  @visibleForTesting
  static List<VideoEpisode> parseEpisodes(String html, String base) {
    final doc = html_parser.parse(html);
    final eps = <VideoEpisode>[];
    var i = 0;
    for (final a in doc.querySelectorAll('a[href*="/play/"]')) {
      final href = a.attributes['href'] ?? '';
      if (href.isEmpty) continue;
      final text = a.text.trim();
      eps.add(VideoEpisode(
        id: href,
        title: text.isEmpty ? '第${i + 1}集' : text,
        index: i,
        playUrl: _abs(href, base),
      ));
      i++;
    }
    return eps;
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
    if (url.startsWith('http')) {
      return url.startsWith('http://') ? url.replaceFirst('http://', 'https://') : url;
    }
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('/')) return '$base$url';
    return '$base/$url';
  }
}
