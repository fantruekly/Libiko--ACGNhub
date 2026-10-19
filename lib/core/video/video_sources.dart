import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sources/source_preferences.dart';
import '../sources/managed_sources.dart';
import 'rule_source.dart';
import 'rule_store.dart';
import 'source_rule.dart';
import 'video_source.dart';

/// All playback sources: one [RuleVideoSource] per bundled/imported rule.
List<VideoSource> buildSources(List<SourceRule> rules) => [
      for (final rule in rules) RuleVideoSource(rule),
    ];

final allVideoSourcesProvider = FutureProvider<List<VideoSource>>((ref) async {
  final rules = await ref.watch(ruleStoreProvider).loadAll();
  final health = ref.read(sourceHealthProvider);
  return [
    for (final source in buildSources(rules)) ManagedVideoSource(source, health)
  ];
});

final videoSourcesProvider = FutureProvider<List<VideoSource>>((ref) async {
  final config = ref.watch(sourcePreferencesProvider);
  final sources = await ref.watch(allVideoSourcesProvider.future);
  return config.apply(SourceKind.anime, sources, (source) => source.id);
});
