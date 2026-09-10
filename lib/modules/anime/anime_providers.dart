import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/source/source_manager.dart';
import '../../core/models/work.dart';
import '../../core/models/search_result.dart';
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

final trendingAnimeProvider = FutureProvider<List<Work>>((ref) async {
  final bangumi = ref.read(bangumiServiceProvider);
  final calendar = await bangumi.getCalendar();

  final seen = <int>{};
  final works = <Work>[];
  for (final item in calendar) {
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
});

final popularAnimeProvider = Provider<List<Work>>((ref) {
  const popular = [
    {'title': '葬送的芙莉莲', 'keyword': '葬送的芙莉莲'},
    {'title': '鬼灭之刃', 'keyword': '鬼灭之刃'},
    {'title': '我推的孩子', 'keyword': '我推的孩子'},
    {'title': '咒术回战', 'keyword': '咒术回战'},
    {'title': '药屋少女的呢喃', 'keyword': '药屋少女'},
    {'title': '迷宫饭', 'keyword': '迷宫饭'},
    {'title': 'Re:从零开始的异世界生活', 'keyword': '从零开始'},
    {'title': '无职转生', 'keyword': '无职转生'},
    {'title': '想要成为影之实力者', 'keyword': '影之实力者'},
    {'title': '我心里危险的东西', 'keyword': '我心里危险'},
    {'title': '地狱乐', 'keyword': '地狱乐'},
    {'title': '夏日重现', 'keyword': '夏日重现'},
  ];

  return popular.map((a) => Work(
    id: 'popular_${a['title']}',
    sourceId: 'popular',
    sourceName: '热门推荐',
    type: WorkType.anime,
    title: a['title'] as String,
    coverUrl: null,
    extra: {'keyword': a['keyword'] as String},
  )).toList();
});