import 'package:dio/dio.dart';

class BangumiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.bgm.tv',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'User-Agent': 'ACGNhub/0.1 (https://github.com/acgnhub)',
    },
  ));

  String _fixUrl(String? url) {
    if (url == null) return '';
    if (url.startsWith('http://')) {
      return url.replaceFirst('http://', 'https://');
    }
    return url;
  }

  Future<List<Map<String, dynamic>>> getCalendar() async {
    try {
      final response = await _dio.get('/calendar');
      final data = response.data as List<dynamic>;
      final results = <Map<String, dynamic>>[];
      final seen = <int>{};
      for (final day in data) {
        final items = day['items'] as List<dynamic>? ?? [];
        for (final item in items) {
          final id = item['id'] as int;
          if (seen.contains(id)) continue;
          seen.add(id);
          final images = item['images'] as Map<String, dynamic>?;
          results.add({
            'id': id,
            'title': item['name_cn'] as String? ?? item['name'] as String? ?? '',
            'cover': _fixUrl(images?['large'] as String?),
            'summary': item['summary'] as String? ?? '',
            'rating': item['rating']?['score'],
            'airDate': item['air_date'] as String?,
            'url': item['url'] as String? ?? 'https://bgm.tv/subject/$id',
          });
        }
      }
      return results;
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getSubjectDetail(int subjectId) async {
    try {
      final response = await _dio.get('/v0/subjects/$subjectId');
      final data = response.data as Map<String, dynamic>;
      final images = data['images'] as Map<String, dynamic>?;
      return {
        'id': data['id'],
        'title': data['name_cn'] as String? ?? data['name'] as String? ?? '',
        'cover': _fixUrl(images?['large'] as String?),
        'summary': data['summary'] as String? ?? '',
        'rating': data['rating']?['score'],
        'tags': (data['tags'] as List<dynamic>?)
                ?.map((t) => t['name'] as String)
                .toList() ??
            [],
        'eps': data['eps'] ?? 0,
        'airDate': data['date'] as String?,
        'staff': data['infobox'] as List<dynamic>? ?? [],
      };
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> searchSubject(String keyword) async {
    try {
      final response = await _dio.get('/search/subject/$keyword', queryParameters: {
        'type': 2,
        'responseGroup': 'small',
      });
      final list = response.data['list'] as List<dynamic>? ?? [];
      return list.map((item) {
        final images = item['images'] as Map<String, dynamic>?;
        return {
          'id': item['id'],
          'title': item['name_cn'] as String? ?? item['name'] as String? ?? '',
          'cover': _fixUrl(images?['large'] as String?),
          'summary': item['summary'] as String? ?? '',
          'url': item['url'] as String? ?? '',
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }
}