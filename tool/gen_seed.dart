import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';

Future<void> main() async {
  final dio = Dio(BaseOptions(
    baseUrl: 'https://api.bgm.tv',
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
    headers: {
      'User-Agent': 'Libiko/0.1 (https://github.com/libiko)',
      'Accept': 'application/json',
    },
  ));

  final cal = await dio.get('/calendar');
  final days = cal.data as List<dynamic>;

  final ids = <int>[];
  final seen = <int>{};
  for (final day in days) {
    for (final item in ((day as Map<String, dynamic>)['items'] as List<dynamic>? ?? [])) {
      final id = (item as Map<String, dynamic>)['id'] as int;
      if (seen.add(id)) ids.add(id);
      if (ids.length >= 40) break;
    }
    if (ids.length >= 40) break;
  }

  final works = <Map<String, dynamic>>[];
  for (final id in ids) {
    try {
      final res = await dio.get('/v0/subjects/$id');
      final m = res.data as Map<String, dynamic>;
      final nameCn = (m['name_cn'] as String?)?.trim() ?? '';
      final name = (m['name'] as String?)?.trim() ?? '';
      final title = nameCn.isNotEmpty ? nameCn : name;
      if (title.isEmpty) continue;
      final images = m['images'] as Map<String, dynamic>?;
      final cover = images?['large'] as String? ?? images?['common'] as String?;
      final rating = m['rating'] as Map<String, dynamic>?;
      works.add({
        'id': 'bangumi_$id',
        'sourceId': 'bangumi',
        'sourceName': 'Bangumi',
        'type': 'anime',
        'title': title,
        'coverUrl': cover == null || cover.isEmpty
            ? null
            : 'https://images.weserv.nl/?url=${Uri.encodeComponent(cover.startsWith('http://') ? cover.replaceFirst('http://', 'https://') : cover)}&w=300',
        'summary': (m['summary'] as String?)?.trim(),
        'tags': ((m['tags'] as List<dynamic>?) ?? [])
            .map((t) => (t as Map<String, dynamic>)['name'] as String)
            .toList(),
        'author': null,
        'extra': {
          'bangumiId': id,
          'score': (rating?['score'] is num && (rating!['score'] as num) > 0)
              ? (rating['score'] as num).toDouble()
              : null,
          'episodes': ((m['eps'] ?? m['total_episodes']) is num && ((m['eps'] ?? m['total_episodes']) as num) > 0)
              ? ((m['eps'] ?? m['total_episodes']) as num).toInt()
              : null,
          'airDate': m['date'],
        },
      });
    } catch (e) {
      stderr.writeln('skip $id: $e');
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  await File('assets/anime_seed.json').writeAsString(
    const JsonEncoder.withIndent('  ').convert(works),
  );
  stdout.writeln('wrote ${works.length} entries');
}
