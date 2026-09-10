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
      final works = await source.browse();
      allWorks.addAll(works);
    } catch (_) {}
  }

  return allWorks;
});