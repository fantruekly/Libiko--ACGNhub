import 'package:dio/dio.dart';

class BangumiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.bgm.tv',
    connectTimeout: const Duration(seconds: 10),
    headers: {
      'User-Agent': 'ACGNhub/0.1 (https://github.com/acgnhub)',
    },
  ));

  Future<List<Map<String, dynamic>>> getCalendar() async {
    try {
      final response = await _dio.get('/calendar');
      final data = response.data as List<dynamic>;
      final results = <Map<String, dynamic>>[];
      for (final day in data) {
        final items = day['items'] as List<dynamic>? ?? [];
        for (final item in items) {
          final images = item['images'] as Map<String, dynamic>?;
          final cover = images?['large'] as String? ?? images?['common'] as String?;
          results.add({
            'id': item['id'],
            'title': item['name_cn'] as String? ?? item['name'] as String? ?? '',
            'cover': cover,
            'summary': item['summary'] as String?,
            'rating': item['rating']?['score'] as double?,
          });
        }
      }
      return results;
    } catch (_) {
      return [];
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
          'cover': images?['large'] as String? ?? images?['common'] as String?,
          'summary': item['summary'] as String?,
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }
}