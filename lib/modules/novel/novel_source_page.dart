import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/sources/source_preferences.dart';
import '../../core/sources/source_management_widgets.dart';
import 'novel_providers.dart';

class NovelSourcePage extends ConsumerWidget {
  const NovelSourcePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(sourcePreferencesProvider).apply(SourceKind.novel,
        ref.watch(allNovelSourcesProvider), (source) => source.id,
        includeDisabled: true);
    final order = [for (final source in sources) source.id];
    return Scaffold(
      appBar: AppBar(title: const Text('轻小说源')),
      body: SourceManagementBody(
          child: ListView(padding: const EdgeInsets.all(20), children: [
        const SourceManagementHint('禁用后不参与发现和搜索；仍可从历史记录手动打开。状态来自实际请求。'),
        for (final source in sources)
          SourceManagementTile(
              kind: SourceKind.novel,
              sourceId: source.id,
              name: source.name,
              subtitle: source.baseUrl,
              order: order),
      ])),
    );
  }
}
