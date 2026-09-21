import 'package:flutter/material.dart';

import '../modules/anime/anime_source_page.dart';
import '../modules/comic/comic_source_page.dart';
import '../modules/game/game_source_page.dart';
import '../modules/novel/novel_source_page.dart';

class SourceHubPage extends StatelessWidget {
  const SourceHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String, Widget Function())>[
      (Icons.live_tv_rounded, '动漫', 'Kazumi 规则源', () => const AnimeSourcePage()),
      (Icons.menu_book_rounded, '漫画', 'Venera JS 源', () => const ComicSourcePage()),
      (Icons.auto_stories_rounded, '轻小说', '内置源', () => const NovelSourcePage()),
      (Icons.games_rounded, '游戏', '内置源', () => const GameSourcePage()),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('添加源')),
      body: ListView(
        children: [
          for (final it in items)
            ListTile(
              leading: Icon(it.$1),
              title: Text(it.$2),
              subtitle: Text(it.$3),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => it.$4())),
            ),
        ],
      ),
    );
  }
}
