### Task 11: Create anime home page with Riverpod

**Files:**
- Create: `lib/modules/anime/anime_providers.dart`
- Create: `lib/modules/anime/anime_home.dart`

**Interfaces:**
- Consumes: `SourceManager` (Task 3), `AnimeSource` (Task 9), `WorkCard` (Task 7)
- Produces: `animeSourceListProvider`, `AnimeHomePage` widget

- [ ] **Step 1: Write providers**

Create `lib/modules/anime/anime_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/source/source_manager.dart';
import '../../core/models/work.dart';
import 'anime_source.dart';
import 'anime_rule.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

final sourceManagerProvider = Provider<SourceManager>((ref) {
  return SourceManager();
});

final animeSourceListProvider = FutureProvider<List<AnimeSource>>((ref) async {
  final manager = ref.read(sourceManagerProvider);

  // Load built-in rules
  final manifest = await rootBundle.loadString('AssetManifest.json');
  final ruleFiles = <String>[];
  if (manifest.contains('assets/rules/')) {
    final lines = manifest.split('\n');
    for (final line in lines) {
      if (line.contains('assets/rules/') && line.contains('.json')) {
        final key = line.split('"')[1];
        if (key != null) ruleFiles.add(key);
      }
    }
  }

  // Load default rule if no files found in manifest
  for (final file in ruleFiles) {
    final jsonString = await rootBundle.loadString(file);
    final rule = AnimeRule.fromJsonString(jsonString);
    final source = AnimeSource(rule);
    manager.register(source);
  }

  return manager.getByType(WorkType.anime).cast<AnimeSource>();
});
```

- [ ] **Step 2: Write AnimeHomePage**

Create `lib/modules/anime/anime_home.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'anime_providers.dart';

class AnimeHomePage extends ConsumerWidget {
  const AnimeHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourcesAsync = ref.watch(animeSourceListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('鍔ㄦ极'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AnimeSearchPage()),
              );
            },
          ),
        ],
      ),
      body: sourcesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('鍔犺浇澶辫触: $err')),
        data: (sources) {
          if (sources.isEmpty) {
            return const Center(child: Text('娌℃湁鍙敤鐨勫姩婕簮'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(animeSourceListProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  '宸插姞杞界殑鍔ㄦ极婧?,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...sources.map((s) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.tv),
                        title: Text(s.name),
                        subtitle: Text(s.baseUrl),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    )),
                const SizedBox(height: 24),
                const Text(
                  '浣跨敤鎼滅储鏌ユ壘浣犳兂鐪嬬殑鍔ㄦ极',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class AnimeSearchPage extends StatelessWidget {
  const AnimeSearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('鎼滅储鍔ㄦ极')),
      body: const Center(child: Text('鎼滅储鍔熻兘寮€鍙戜腑')),
    );
  }
}
```

- [ ] **Step 3: Run build to verify**

```bash
flutter build windows --debug
```

Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
git add lib/modules/anime/
git commit -m "feat(anime): add anime home page with Riverpod providers"
```

---


