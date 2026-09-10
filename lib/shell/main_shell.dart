import 'package:flutter/material.dart';
import '../modules/anime/anime_home.dart';
import 'settings_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _pages = <Widget>[
    const AnimeHomePage(),
    const _PlaceholderPage(title: '漫画', icon: Icons.menu_book, message: '阶段2'),
    const _PlaceholderPage(title: '轻小说', icon: Icons.auto_stories, message: '阶段3'),
    const _PlaceholderPage(title: '游戏', icon: Icons.games, message: '阶段4'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '番剧'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: '漫画'),
          NavigationDestination(icon: Icon(Icons.auto_stories_outlined), selectedIcon: Icon(Icons.auto_stories), label: '小说'),
          NavigationDestination(icon: Icon(Icons.games_outlined), selectedIcon: Icon(Icons.games), label: '游戏'),
        ],
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final String title;
  final IconData icon;
  final String message;

  const _PlaceholderPage({required this.title, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: false),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(message, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 15)),
          ],
        ),
      ),
    );
  }
}