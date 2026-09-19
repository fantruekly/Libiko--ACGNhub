import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'gimy_source.dart';
import 'rule_source.dart';
import 'rule_store.dart';
import 'source_rule.dart';
import 'video_source.dart';

/// All playback sources: the hand-written HTTP sources plus every rule source.
List<VideoSource> buildSources(List<SourceRule> rules) => [
      GimySource(),
      for (final rule in rules) RuleVideoSource(rule),
    ];

final videoSourcesProvider = FutureProvider<List<VideoSource>>((ref) async {
  final rules = await ref.watch(ruleStoreProvider).loadAll();
  return buildSources(rules);
});
