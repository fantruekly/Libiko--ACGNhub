import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/source/source_manager.dart';
import '../../core/models/work.dart';
import 'anime_source.dart';
import 'anime_rule.dart';
import 'bangumi_service.dart';
import 'package:flutter/services.dart';

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
    final source = AnimeSource(rule);
    manager.register(source);
  }

  return manager.getByType(WorkType.anime).cast<AnimeSource>();
});

final bangumiServiceProvider = Provider<BangumiService>((ref) => BangumiService());

List<Work> _parseItems(List<Map<String, dynamic>> items) {
  final seen = <int>{};
  final works = <Work>[];
  for (final item in items) {
    final id = item['id'] as int;
    if (seen.contains(id)) continue;
    seen.add(id);

    final title = item['title'] as String? ?? '';
    if (title.isEmpty) continue;

    works.add(Work(
      id: 'bangumi_$id',
      sourceId: 'bangumi',
      sourceName: 'Bangumi',
      type: WorkType.anime,
      title: title,
      coverUrl: item['cover'] as String?,
      summary: item['summary'] as String?,
      extra: {'bangumiId': id, 'keyword': title},
    ));
  }
  return works;
}

final trendingAnimeProvider = FutureProvider<List<Work>>((ref) async {
  try {
    final bangumi = ref.read(bangumiServiceProvider);
    final calendar = await bangumi.getCalendar();
    if (calendar.isNotEmpty) return _parseItems(calendar);
  } catch (_) {}

  try {
    final cachedJson = await rootBundle.loadString('assets/bangumi_calendar.json');
    final cached = json.decode(cachedJson) as List<dynamic>;
    final items = <Map<String, dynamic>>[];
    final seen = <int>{};
    for (final day in cached) {
      for (final item in (day['items'] as List<dynamic>? ?? [])) {
        final id = item['id'] as int;
        if (seen.contains(id)) continue;
        seen.add(id);
        final title = item['name_cn'] as String? ?? item['name'] as String? ?? '';
        if (title.isEmpty) continue;
        final images = item['images'] as Map<String, dynamic>?;
        var cover = images?['large'] as String?;
        if (cover != null && cover.startsWith('http://')) {
          cover = cover.replaceFirst('http://', 'https://');
        }
        items.add({
          'id': id,
          'title': title,
          'cover': cover,
          'summary': item['summary'] as String?,
        });
      }
    }
    return _parseItems(items);
  } catch (_) {
    return [];
  }
});

final popularAnimeProvider = Provider<List<Work>>((ref) {
  const popular = [
    {'title': '葬送的芙莉莲'},
    {'title': '鬼灭之刃'},
    {'title': '我推的孩子'},
    {'title': '咒术回战'},
    {'title': '药屋少女的呢喃'},
    {'title': '迷宫饭'},
    {'title': 'Re:从零开始的异世界生活'},
    {'title': '无职转生'},
    {'title': '想要成为影之实力者'},
    {'title': '我心里危险的东西'},
    {'title': '地狱乐'},
    {'title': '夏日重现'},
  ];

  return popular.map((a) => Work(
    id: 'popular_${a['title']}',
    sourceId: 'popular',
    sourceName: '热门推荐',
    type: WorkType.anime,
    title: a['title'] as String,
    coverUrl: null,
    extra: {'keyword': a['title'] as String},
  )).toList();
});