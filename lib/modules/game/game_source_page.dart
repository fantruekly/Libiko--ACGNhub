import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'game_providers.dart';

class GameSourcePage extends ConsumerWidget {
  const GameSourcePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(gameSourcesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('游戏源')),
      body: ListView(
        children: [
          for (final s in sources)
            ListTile(title: Text(s.name), subtitle: Text(s.id)),
        ],
      ),
    );
  }
}
