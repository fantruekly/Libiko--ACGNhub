import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import '../models/anime_extra.dart';
import '../models/work.dart';
import 'metadata_provider.dart';

class BangumiProvider implements MetadataProvider {
  static const _base = 'https://api.bgm.tv';
  static const _browserBase = 'https://bgm.tv';
  static const _browserUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  final Dio _dio;
  final DateTime Function() _now;

  BangumiProvider({Dio? dio, DateTime Function()? now})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: _base,
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 20),
              headers: {
                'User-Agent': 'Libiko/0.1',
                'Accept': 'application/json',
              },
            )),
        _now = now ?? DateTime.now;

  @override
  String get id => 'bangumi';

  @override
  Future<List<Work>> feed(AnimeFeed feed, {int page = 1}) async {
    if (feed == AnimeFeed.trending) {
      final res = await _dio.get<String>(
        '$_browserBase/anime/browser',
        queryParameters: {'sort': 'trends', 'page': page},
        options: Options(
          responseType: ResponseType.plain,
          headers: {
            'User-Agent': _browserUserAgent,
            'Accept': 'text/html,application/xhtml+xml',
          },
        ),
      );
      final html = res.data;
      if (res.statusCode != 200 || html == null) {
        throw Exception('bangumi 热度榜请求失败 (${res.statusCode})');
      }
      return parseBrowserList(html);
    }
    if (page > 1) return const [];
    final res = await _dio.get('/calendar');
    final days = res.data as List<dynamic>;
    return feed == AnimeFeed.today
        ? parseCalendar(days, onlyWeekday: _now().weekday)
        : parseCalendar(days);
  }

  @override
  Future<List<Work>> search(String keyword, {int page = 1}) async {
    final res = await _dio.get(
      '/search/subject/${Uri.encodeComponent(keyword)}',
      queryParameters: {'type': 2, 'responseGroup': 'small'},
    );
    return parseSearch(res.data);
  }

  @override
  Future<Work> detail(Work work) async {
    final id = work.extra['bangumiId'];
    if (id == null) {
      throw StateError('BangumiProvider.detail requires bangumiId');
    }
    final res = await _dio.get('/v0/subjects/$id');
    return parseDetail(res.data as Map<String, dynamic>);
  }

  Future<List<AnimeCharacter>> characters(int id) async {
    final res = await _dio.get('/v0/subjects/$id/characters');
    return parseCharacters(res.data);
  }

  Future<List<RelatedWork>> related(int id) async {
    final res = await _dio.get('/v0/subjects/$id/subjects');
    return parseRelated(res.data);
  }

  @visibleForTesting
  static List<AnimeCharacter> parseCharacters(dynamic data) {
    final list = (data as List<dynamic>?) ?? [];
    final out = <AnimeCharacter>[];
    for (final e in list) {
      final m = e as Map<String, dynamic>;
      final name = (m['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) continue;
      final images = m['images'] as Map<String, dynamic>?;
      final actors = ((m['actors'] as List<dynamic>?) ?? [])
          .map((a) {
            final am = a as Map<String, dynamic>;
            final aimg = am['images'] as Map<String, dynamic>?;
            return AnimeActor(
              name: (am['name'] as String?)?.trim() ?? '',
              image: _https(
                  aimg?['grid'] as String? ?? aimg?['medium'] as String?),
            );
          })
          .where((a) => a.name.isNotEmpty)
          .toList();
      out.add(AnimeCharacter(
        name: name,
        relation: m['relation'] as String?,
        image: _https(images?['grid'] as String? ?? images?['medium'] as String?),
        actors: actors,
      ));
    }
    return out;
  }

  @visibleForTesting
  static List<RelatedWork> parseRelated(dynamic data) {
    final list = (data as List<dynamic>?) ?? [];
    final out = <RelatedWork>[];
    for (final e in list) {
      final m = e as Map<String, dynamic>;
      final id = m['id'] as int?;
      if (id == null) continue;
      final nameCn = (m['name_cn'] as String?)?.trim() ?? '';
      final name = (m['name'] as String?)?.trim() ?? '';
      final title = nameCn.isNotEmpty ? nameCn : name;
      if (title.isEmpty) continue;
      final images = m['images'] as Map<String, dynamic>?;
      out.add(RelatedWork(
        bangumiId: id,
        title: title,
        relation: m['relation'] as String?,
        image: _https(images?['grid'] as String? ?? images?['medium'] as String?),
      ));
    }
    return out;
  }

  static String? _https(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('//')) return 'https:$url';
    return url.startsWith('http://')
        ? url.replaceFirst('http://', 'https://')
        : url;
  }

  /// 解析网站「热度」榜单页（`/anime/browser?sort=trends`）的 HTML。
  @visibleForTesting
  static List<Work> parseBrowserList(String html) {
    final doc = html_parser.parse(html);
    final out = <Work>[];
    for (final li in doc.querySelectorAll('ul#browserItemList li.item')) {
      final id = int.tryParse(li.id.replaceFirst('item_', ''));
      if (id == null) continue;
      final nameCn = li.querySelector('h3 a.l')?.text.trim() ?? '';
      final name = li.querySelector('h3 small.grey')?.text.trim() ?? '';
      final title = nameCn.isNotEmpty ? nameCn : name;
      if (title.isEmpty) continue;
      final info = li.querySelector('p.info.tip')?.text ?? '';
      final score = double.tryParse(
          li.querySelector('p.rateInfo small.fade')?.text.trim() ?? '');
      final rank = int.tryParse(
          (li.querySelector('span.rank')?.text ?? '').replaceAll(RegExp(r'\D'), ''));
      out.add(Work(
        id: 'bangumi_$id',
        sourceId: 'bangumi',
        sourceName: 'Bangumi',
        type: WorkType.anime,
        title: title,
        coverUrl: _cover(li.querySelector('img.cover')?.attributes['src']),
        tags: const [],
        extra: {
          'bangumiId': id,
          'score': score,
          'episodes': _episodesFromInfo(info),
          'airDate': _airDateFromInfo(info),
          'rank': rank,
        },
      ));
    }
    return out;
  }

  static int? _episodesFromInfo(String info) {
    final m = RegExp(r'(\d+)\s*话').firstMatch(info);
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  static String? _airDateFromInfo(String info) {
    final m = RegExp(r'(\d{4})年(\d{1,2})月(\d{1,2})日').firstMatch(info);
    if (m == null) return null;
    return '${m.group(1)}-${m.group(2)!.padLeft(2, '0')}-'
        '${m.group(3)!.padLeft(2, '0')}';
  }

  @visibleForTesting
  static List<Work> parseCalendar(List<dynamic> days, {int? onlyWeekday}) {
    final works = <Work>[];
    final seen = <int>{};
    for (final day in days) {
      final d = day as Map<String, dynamic>;
      final weekday = (d['weekday'] as Map<String, dynamic>?)?['id'] as int?;
      if (onlyWeekday != null && weekday != onlyWeekday) continue;
      for (final item in (d['items'] as List<dynamic>? ?? [])) {
        final w = _parseItem(item as Map<String, dynamic>);
        if (w != null && seen.add(w.extra['bangumiId'] as int)) works.add(w);
      }
    }
    return works;
  }

  @visibleForTesting
  static List<Work> parseSearch(dynamic data) {
    final list =
        ((data is Map ? (data['list'] ?? data['data']) : data) as List<dynamic>?) ??
            [];
    return list
        .map((e) => _parseItem(e as Map<String, dynamic>))
        .whereType<Work>()
        .toList();
  }

  @visibleForTesting
  static Work parseDetail(Map<String, dynamic> d) =>
      _parseItem(d, isDetail: true)!;

  static Work? _parseItem(Map<String, dynamic> item, {bool isDetail = false}) {
    final id = item['id'] as int?;
    if (id == null) return null;
    final nameCn = (item['name_cn'] as String?)?.trim() ?? '';
    final name = (item['name'] as String?)?.trim() ?? '';
    final title = nameCn.isNotEmpty ? nameCn : name;
    if (title.isEmpty) return null;

    final images = item['images'] as Map<String, dynamic>?;
    final cover = images?['large'] as String? ?? images?['common'] as String?;
    final rating = item['rating'] as Map<String, dynamic>?;
    final rawScore = rating?['score'];
    final score =
        (rawScore is num && rawScore > 0) ? rawScore.toDouble() : null;
    final rawEps = item['eps'];
    final episodes = (rawEps is num && rawEps > 0) ? rawEps.toInt() : null;
    final tags = (item['tags'] as List<dynamic>?)
            ?.map((t) => (t as Map<String, dynamic>)['name'] as String)
            .toList() ??
        [];

    return Work(
      id: 'bangumi_$id',
      sourceId: 'bangumi',
      sourceName: 'Bangumi',
      type: WorkType.anime,
      title: title,
      coverUrl: _cover(cover),
      summary: (item['summary'] as String?)?.trim(),
      tags: isDetail ? tags : const [],
      extra: {
        'bangumiId': id,
        'score': score,
        'episodes': episodes,
        'airDate': item['air_date'] ?? item['date'],
        'rank': item['rank'],
      },
    );
  }

  static String? _cover(String? url) {
    if (url == null || url.isEmpty) return null;
    final https = _https(url)!;
    if (https.contains('images.weserv.nl')) return https;
    return 'https://images.weserv.nl/?url=${Uri.encodeComponent(https)}&w=300';
  }
}
