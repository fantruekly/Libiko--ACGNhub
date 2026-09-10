import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../core/source/source_manager.dart';
import '../../core/models/work.dart';
import 'anime_source.dart';
import 'anime_rule.dart';
import 'bangumi_service.dart';

final sourceManagerProvider = Provider<SourceManager>((ref) {
  return SourceManager();
});

final animeSourceListProvider = FutureProvider<List<AnimeSource>>((ref) async {
  final manager = ref.read(sourceManagerProvider);
  final manifestJson = await rootBundle.loadString('AssetManifest.json');
  final manifest = json.decode(manifestJson) as Map<String, dynamic>;
  final ruleFiles = manifest.keys.where((k) => k.startsWith('assets/rules/') && k.endsWith('.json')).toList();
  for (final file in ruleFiles) {
    final jsonString = await rootBundle.loadString(file);
    final rule = AnimeRule.fromJsonString(jsonString);
    manager.register(AnimeSource(rule));
  }
  return manager.getByType(WorkType.anime).cast<AnimeSource>();
});

String _stableCoverUrl(String? cover) {
  if (cover == null || cover.isEmpty) return '';

  final normalized = cover.startsWith('http://')
      ? cover.replaceFirst('http://', 'https://')
      : cover;

  if (normalized.contains('lain.bgm.tv') || normalized.contains('bgm.tv/pic/cover')) {
    final encoded = Uri.encodeComponent(normalized);
    return 'https://images.weserv.nl/?url=$encoded';
  }

  return normalized;
}

final trendingAnimeProvider = FutureProvider<List<Work>>((ref) async {
  final service = BangumiService();
  final remoteWorks = await service.getCalendar();

  if (remoteWorks.isNotEmpty) {
    return remoteWorks.map((item) {
      final id = item['id'] as int;
      return Work(
        id: 'bangumi_$id',
        sourceId: 'bangumi',
        sourceName: '',
        type: WorkType.anime,
        title: item['title'] as String? ?? '',
        coverUrl: _stableCoverUrl(item['cover'] as String?),
        summary: item['summary'] as String?,
        extra: {'bangumiId': id, 'keyword': item['title']},
      );
    }).toList();
  }

  final cachedJson = await rootBundle.loadString('assets/bangumi_calendar.json');
  final cached = json.decode(cachedJson) as List<dynamic>;

  final seen = <int>{};
  final works = <Work>[];
  for (final day in cached) {
    for (final item in (day['items'] as List<dynamic>? ?? [])) {
      final id = item['id'] as int;
      if (seen.contains(id)) continue;
      seen.add(id);
      final title = item['name_cn'] as String? ?? item['name'] as String? ?? '';
      if (title.isEmpty) continue;
      final images = item['images'] as Map<String, dynamic>?;
      final cover = _stableCoverUrl(images?['large'] as String? ?? images?['common'] as String?);
      works.add(Work(
        id: 'bangumi_$id',
        sourceId: 'bangumi',
        sourceName: '',
        type: WorkType.anime,
        title: title,
        coverUrl: cover,
        summary: item['summary'] as String?,
        extra: {'bangumiId': id, 'keyword': title},
      ));
    }
  }
  return works;
});

final bangumiServiceProvider = Provider<BangumiService>((ref) => BangumiService());