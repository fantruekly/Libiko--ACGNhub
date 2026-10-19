import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/sources/source_preferences.dart';
import '../../core/sources/source_management_widgets.dart';
import 'game_providers.dart';

class GameSourcePage extends ConsumerWidget {
  const GameSourcePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(sourcePreferencesProvider).apply(SourceKind.game,
        ref.watch(allGameSourcesProvider), (source) => source.id,
        includeDisabled: true);
    final order = [for (final source in sources) source.id];
    return Scaffold(
      appBar: AppBar(title: const Text('游戏源')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        const Padding(
            padding: EdgeInsets.all(8),
            child: Text('禁用后不参与发现和搜索；仍可从历史记录手动打开。状态来自实际请求。')),
        for (final source in sources)
          SourceManagementTile(
              kind: SourceKind.game,
              sourceId: source.id,
              name: source.name,
              subtitle: source.baseUrl,
              order: order),
      ]),
    );
  }
}
