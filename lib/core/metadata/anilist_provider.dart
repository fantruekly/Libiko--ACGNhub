import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/work.dart';
import 'metadata_provider.dart';

class AniListProvider implements MetadataProvider {
  static const perPage = 25;
  static const _endpoint = 'https://graphql.anilist.co';

  final Dio _dio;

  AniListProvider({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 20),
              headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            ));

  @override
  String get id => 'anilist';

  static const _media = '''
    id
    title { romaji english native }
    coverImage { extraLarge large color }
    bannerImage
    description(asHtml: false)
    genres
    episodes
    duration
    status
    season
    seasonYear
    format
    averageScore
    popularity
    studios(isMain: true) { nodes { name } }
  ''';

  Future<Map<String, dynamic>> _post(String query, [Map<String, dynamic>? variables]) async {
    final res = await _dio.post(_endpoint, data: {'query': query, 'variables': variables ?? {}});
    final body = res.data as Map<String, dynamic>;
    if (body['errors'] != null) {
      throw Exception('AniList error: ${body['errors']}');
    }
    return body['data'] as Map<String, dynamic>;
  }

  @override
  Future<List<Work>> feed(AnimeFeed feed, {int page = 1}) async {
    switch (feed) {
      case AnimeFeed.trending:
        final data = await _post(
          'query(\$page:Int,\$perPage:Int){Page(page:\$page,perPage:\$perPage){'
          'media(type:ANIME,sort:TRENDING_DESC,isAdult:false){$_media}}}',
          {'page': page, 'perPage': perPage},
        );
        return parsePage(data);
      case AnimeFeed.season:
        final (season, year) = _currentSeason();
        final data = await _post(
          'query(\$page:Int,\$perPage:Int,\$season:MediaSeason,\$seasonYear:Int){'
          'Page(page:\$page,perPage:\$perPage){media(type:ANIME,season:\$season,'
          'seasonYear:\$seasonYear,sort:POPULARITY_DESC,isAdult:false){$_media}}}',
          {'page': page, 'perPage': perPage, 'season': season, 'seasonYear': year},
        );
        return parsePage(data);
      case AnimeFeed.today:
        final now = DateTime.now();
        final start = DateTime(now.year, now.month, now.day);
        final end = start.add(const Duration(days: 1));
        final data = await _post(
          'query(\$page:Int,\$perPage:Int,\$start:Int,\$end:Int){Page(page:\$page,perPage:\$perPage){'
          'airingSchedules(airingAt_greater:\$start,airingAt_lesser:\$end,sort:TIME){media{$_media}}}}',
          {
            'page': page,
            'perPage': perPage,
            'start': start.millisecondsSinceEpoch ~/ 1000,
            'end': end.millisecondsSinceEpoch ~/ 1000,
          },
        );
        return parseAiring(data);
    }
  }

  @override
  Future<List<Work>> search(String keyword, {int page = 1}) async {
    final data = await _post(
      'query(\$page:Int,\$perPage:Int,\$search:String){Page(page:\$page,perPage:\$perPage){'
      'media(type:ANIME,search:\$search,sort:SEARCH_MATCH,isAdult:false){$_media}}}',
      {'page': page, 'perPage': perPage, 'search': keyword},
    );
    return parsePage(data);
  }

  @override
  Future<Work> detail(Work work) async {
    final variables = <String, dynamic>{};
    final String query;
    if (work.anilistId != null) {
      query = 'query(\$id:Int){Media(id:\$id,type:ANIME){$_media}}';
      variables['id'] = work.anilistId;
    } else if (work.malId != null) {
      query = 'query(\$idMal:Int){Media(idMal:\$idMal,type:ANIME){$_media}}';
      variables['idMal'] = work.malId;
    } else {
      throw StateError('AniListProvider.detail requires anilistId or malId');
    }
    final data = await _post(query, variables);
    return parseMedia(data['Media'] as Map<String, dynamic>);
  }

  static (String, int) _currentSeason() {
    final now = DateTime.now();
    final season = switch (now.month) {
      >= 1 && <= 3 => 'WINTER',
      >= 4 && <= 6 => 'SPRING',
      >= 7 && <= 9 => 'SUMMER',
      _ => 'FALL',
    };
    return (season, now.year);
  }

  @visibleForTesting
  static List<Work> parsePage(Map<String, dynamic> data) {
    final page = data['Page'] as Map<String, dynamic>?;
    final media = (page?['media'] as List<dynamic>?) ?? [];
    return media.map((m) => parseMedia(m as Map<String, dynamic>)).toList();
  }

  @visibleForTesting
  static List<Work> parseAiring(Map<String, dynamic> data) {
    final page = data['Page'] as Map<String, dynamic>?;
    final schedules = (page?['airingSchedules'] as List<dynamic>?) ?? [];
    return schedules
        .map((s) => parseMedia((s as Map<String, dynamic>)['media'] as Map<String, dynamic>))
        .toList();
  }

  @visibleForTesting
  static Work parseMedia(Map<String, dynamic> m) {
    final id = m['id'] as int;
    final title = (m['title'] as Map<String, dynamic>?) ?? {};
    final cover = m['coverImage'] as Map<String, dynamic>?;
    final studios = ((m['studios'] as Map<String, dynamic>?)?['nodes'] as List<dynamic>?)
            ?.map((s) => (s as Map<String, dynamic>)['name'] as String)
            .toList() ??
        [];
    final native = title['native'] as String?;
    final romaji = title['romaji'] as String?;
    final english = title['english'] as String?;
    final display = (native != null && native.isNotEmpty)
        ? native
        : (romaji != null && romaji.isNotEmpty ? romaji : (english ?? ''));

    return Work(
      id: 'anilist_$id',
      sourceId: 'anilist',
      sourceName: 'AniList',
      type: WorkType.anime,
      title: display,
      coverUrl: cover?['extraLarge'] as String? ?? cover?['large'] as String?,
      summary: _strip(m['description'] as String?),
      tags: (m['genres'] as List<dynamic>?)?.cast<String>() ?? [],
      extra: {
        'anilistId': id,
        'titleNative': native,
        'titleEnglish': english,
        'bannerUrl': m['bannerImage'],
        'score': _normalizeScore(m['averageScore']),
        'episodes': m['episodes'],
        'duration': m['duration'],
        'status': m['status'],
        'seasonYear': m['seasonYear'],
        'format': m['format'],
        'studios': studios,
      },
    );
  }

  static double? _normalizeScore(dynamic averageScore) {
    if (averageScore is num) return averageScore / 10;
    return null;
  }

  static String? _strip(String? s) {
    if (s == null || s.isEmpty) return null;
    return s
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .trim();
  }
}
