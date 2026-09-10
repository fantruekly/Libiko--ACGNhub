import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/work.dart';
import 'metadata_provider.dart';

class JikanProvider implements MetadataProvider {
  static const perPage = 30;
  static const _weekdays = [
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday',
  ];

  final Dio _dio;

  JikanProvider({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://api.jikan.moe/v4',
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 20),
              headers: {'Accept': 'application/json'},
            ));

  @override
  String get id => 'jikan';

  @override
  Future<List<Work>> feed(AnimeFeed feed, {int page = 1}) async {
    final path = switch (feed) {
      AnimeFeed.trending => '/top/anime',
      AnimeFeed.season => '/seasons/now',
      AnimeFeed.today => '/schedules',
    };
    final query = <String, dynamic>{'limit': perPage, 'page': page};
    if (feed == AnimeFeed.trending) query['filter'] = 'bypopularity';
    if (feed == AnimeFeed.today) query['filter'] = _weekdays[DateTime.now().weekday - 1];
    final res = await _dio.get(path, queryParameters: query);
    return parseList(res.data);
  }

  @override
  Future<List<Work>> search(String keyword, {int page = 1}) async {
    final res = await _dio.get('/anime', queryParameters: {
      'q': keyword,
      'sfw': true,
      'limit': perPage,
      'page': page,
    });
    return parseList(res.data);
  }

  @override
  Future<Work> detail(Work work) async {
    final malId = work.malId;
    if (malId == null) {
      throw StateError('JikanProvider.detail requires malId');
    }
    final res = await _dio.get('/anime/$malId/full');
    return parseItem((res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
  }

  @visibleForTesting
  static List<Work> parseList(dynamic data) {
    final list = (data is Map ? data['data'] : data) as List<dynamic>? ?? [];
    return list.map((e) => parseItem(e as Map<String, dynamic>)).toList();
  }

  @visibleForTesting
  static Work parseItem(Map<String, dynamic> item) {
    final malId = item['mal_id'] as int;
    final jpg = ((item['images'] as Map<String, dynamic>?)?['jpg']) as Map<String, dynamic>?;
    final genres = (item['genres'] as List<dynamic>?)
            ?.map((g) => (g as Map<String, dynamic>)['name'] as String)
            .toList() ??
        [];
    final studios = (item['studios'] as List<dynamic>?)
            ?.map((s) => (s as Map<String, dynamic>)['name'] as String)
            .toList() ??
        [];

    return Work(
      id: 'jikan_$malId',
      sourceId: 'jikan',
      sourceName: 'MyAnimeList',
      type: WorkType.anime,
      title: _title(item),
      coverUrl: jpg?['large_image_url'] as String? ?? jpg?['image_url'] as String?,
      summary: _clean(item['synopsis'] as String?),
      tags: genres,
      extra: {
        'malId': malId,
        'titleNative': item['title_japanese'],
        'titleEnglish': item['title_english'],
        'score': item['score'],
        'episodes': item['episodes'],
        'status': item['status'],
        'seasonYear': item['year'],
        'studios': studios,
        'bannerUrl': null,
      },
    );
  }

  static String _title(Map<String, dynamic> item) {
    final t = item['title'] as String?;
    if (t != null && t.trim().isNotEmpty) return t;
    return (item['title_english'] as String?) ?? (item['title_japanese'] as String?) ?? '';
  }

  static String? _clean(String? s) {
    if (s == null || s.isEmpty) return null;
    return s.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll('&amp;', '&').trim();
  }
}
