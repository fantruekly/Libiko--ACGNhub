### Task 14: Create app shell and main entry point

**Files:**
- Create: `lib/shell/main_shell.dart`
- Create: `lib/shell/settings_page.dart`
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `AnimeHomePage` (Task 11), `AppDatabase` (Task 5)
- Produces: `MainShell` with bottom navigation, `main.dart` entry point

- [ ] **Step 1: Create directories**

```bash
mkdir -p lib\shell
```

- [ ] **Step 2: Write SettingsPage**

Create `lib/shell/settings_page.dart`:

```dart
import 'package:flutter/material.dart';
import '../../core/storage/database.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('璁剧疆')),
      body: ListView(
        children: [
          const _SectionHeader(title: '缂撳瓨'),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('娓呴櫎鍥剧墖缂撳瓨'),
            onTap: () async {
              // TODO: Clear cache
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('缂撳瓨宸叉竻闄?)),
                );
              }
            },
          ),
          const Divider(),
          const _SectionHeader(title: '鍏充簬'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('ACGNhub'),
            subtitle: Text('v0.1.0 - 鍔ㄦ极鑱氬悎搴旂敤'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Write MainShell**

Create `lib/shell/main_shell.dart`:

```dart
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
    const _PlaceholderPage(title: '婕敾', icon: Icons.menu_book, message: '婕敾妯″潡灏嗗湪闃舵2瀹炵幇'),
    const _PlaceholderPage(title: '杞诲皬璇?, icon: Icons.auto_stories, message: '杞诲皬璇存ā鍧楀皢鍦ㄩ樁娈?瀹炵幇'),
    const _PlaceholderPage(title: '娓告垙', icon: Icons.games, message: '娓告垙妯″潡灏嗗湪闃舵4瀹炵幇'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.live_tv_outlined),
            selectedIcon: Icon(Icons.live_tv),
            label: '鍔ㄦ极',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: '婕敾',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: '杞诲皬璇?,
          ),
          NavigationDestination(
            icon: Icon(Icons.games_outlined),
            selectedIcon: Icon(Icons.games),
            label: '娓告垙',
          ),
        ],
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final String title;
  final IconData icon;
  final String message;

  const _PlaceholderPage({
    required this.title,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(message, style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Write main.dart**

Replace the content of `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'core/storage/database.dart';
import 'shell/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await AppDatabase.init();
  runApp(const ProviderScope(child: ACGNhubApp()));
}

class ACGNhubApp extends StatelessWidget {
  const ACGNhubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ACGNhub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.dark,
      home: const MainShell(),
    );
  }
}
```

- [ ] **Step 5: Build and verify**

```bash
flutter build windows --debug
```

Expected: Build succeeds with no errors.

- [ ] **Step 6: Commit**

```bash
git add lib/shell/ lib/main.dart
git commit -m "feat(shell): add MainShell with bottom navigation and app entry point"
```

---


