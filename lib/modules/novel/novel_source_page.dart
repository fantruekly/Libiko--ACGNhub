import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'novel_providers.dart';

class NovelSourcePage extends ConsumerWidget {
  const NovelSourcePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(novelSourcesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('轻小说源')),
      body: ListView(
        children: [
          for (final s in sources)
            ListTile(title: Text(s.name), subtitle: Text(s.id)),
        ],
      ),
    );
  }
}
