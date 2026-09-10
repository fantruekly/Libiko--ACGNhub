import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/source/source_manager.dart';
import '../../core/models/work.dart';
import 'anime_source.dart';
import 'anime_rule.dart';
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

final animeHomeWorksProvider = FutureProvider<List<Work>>((ref) async {
  final sources = await ref.watch(animeSourceListProvider.future);
  final allWorks = <Work>[];

  for (final source in sources) {
    try {
      final works = await source.browse().timeout(const Duration(seconds: 5));
      allWorks.addAll(works);
    } catch (_) {}
  }

  if (allWorks.isEmpty) {
    final popularAnime = [
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
      {'title': '不死少女的谋杀闹剧', 'keyword': '不死少女'},
      {'title': '地狱乐', 'keyword': '地狱乐'},
    ];
    for (final anime in popularAnime) {
      allWorks.add(Work(
        id: 'popular_${anime['title']}',
        sourceId: 'popular',
        sourceName: '热门推荐',
        type: WorkType.anime,
        title: anime['title'] as String,
        coverUrl: null,
        extra: {'keyword': anime['keyword'] as String},
      ));
    }
  }

  return allWorks;
});