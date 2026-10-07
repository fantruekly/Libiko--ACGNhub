import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'rule_source.dart';
import 'rule_store.dart';
import 'source_rule.dart';
import 'video_source.dart';

/// All playback sources: one [RuleVideoSource] per bundled/imported rule.
List<VideoSource> buildSources(List<SourceRule> rules) => [
      for (final rule in rules) RuleVideoSource(rule),
    ];

final videoSourcesProvider = FutureProvider<List<VideoSource>>((ref) async {
  final rules = await ref.watch(ruleStoreProvider).loadAll();
  return buildSources(rules);
});
