import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/work.dart';
import 'metadata_provider.dart';

class BangumiProvider implements MetadataProvider {
  static const _base = 'https://api.bgm.tv';

  final Dio _dio;
  final DateTime Function() _now;

  BangumiProvider({Dio? dio, DateTime Function()? now})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: _base,
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 20),
              headers: {
                'User-Agent': 'ACGNhub/0.1 (https://github.com/acgnhub)',
                'Accept': 'application/json',
              },
            )),
        _now = now ?? DateTime.now;

  @override
  String get id => 'bangumi';

  @override
  Future<List<Work>> feed(AnimeFeed feed, {int page = 1}) async {
    if (page > 1) return const [];
    final res = await _dio.get('/calendar');
    final days = res.data as List<dynamic>;
    switch (feed) {
      case AnimeFeed.today:
        return parseCalendar(days, onlyWeekday: _now().weekday);
      case AnimeFeed.season:
        return parseCalendar(days);
      case AnimeFeed.trending:
        final works = parseCalendar(days);
        works.sort((a, b) {
          final sa = (a.extra['score'] as num?) ?? 0;
          final sb = (b.extra['score'] as num?) ?? 0;
          return sb.compareTo(sa);
        });
        return works;
    }
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
    final list = ((data is Map ? data['list'] : data) as List<dynamic>?) ?? [];
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
    final https = url.startsWith('http://')
        ? url.replaceFirst('http://', 'https://')
        : url;
    if (https.contains('images.weserv.nl')) return https;
    return 'https://images.weserv.nl/?url=${Uri.encodeComponent(https)}&w=300';
  }
}
