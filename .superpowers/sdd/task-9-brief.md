### Task 9: Remove Bangumi entirely

**Files:**
- Delete: `lib/modules/anime/bangumi_service.dart`
- Delete: `assets/bangumi_calendar.json`
- Modify: `lib/modules/anime/anime_providers.dart`
- Modify: `pubspec.yaml`

**Interfaces:**
- Removes: `trendingAnimeProvider`, `bangumiServiceProvider`, `BangumiService`.

- [ ] **Step 1: Delete the service and asset**

Run:
```powershell
Remove-Item -LiteralPath "D:\ACGNhub\lib\modules\anime\bangumi_service.dart"
Remove-Item -LiteralPath "D:\ACGNhub\assets\bangumi_calendar.json"
```

- [ ] **Step 2: Remove Bangumi providers**

In `lib/modules/anime/anime_providers.dart`:
- Remove `import 'bangumi_service.dart';`
- Remove the `_stableCoverUrl` helper
- Remove the entire `trendingAnimeProvider` definition
- Remove the `bangumiServiceProvider` definition

Keep `sourceManagerProvider`, `animeSourceListProvider`, `metadataServiceProvider`, `animeFeedProvider`.

The file should end up as:

```dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../core/metadata/metadata_provider.dart';
import '../../core/metadata/metadata_service.dart';
import '../../core/source/source_manager.dart';
import '../../core/models/work.dart';
import 'anime_source.dart';
import 'anime_rule.dart';

final sourceManagerProvider = Provider<SourceManager>((ref) {
  return SourceManager();
});

final animeSourceListProvider = FutureProvider<List<AnimeSource>>((ref) async {
  final manager = ref.read(sourceManagerProvider);
  final manifestJson = await rootBundle.loadString('AssetManifest.json');
  final manifest = json.decode(manifestJson) as Map<String, dynamic>;
  final ruleFiles = manifest.keys.where((k) => k.startsWith('assets/rules/') && k.endsWith('.json')).toList();
  for (final file in ruleFiles) {
    final jsonString = await rootBundle.loadString(file);
    final rule = AnimeRule.fromJsonString(jsonString);
    manager.register(AnimeSource(rule));
  }
  return manager.getByType(WorkType.anime).cast<AnimeSource>();
});

final metadataServiceProvider = Provider<MetadataService>((ref) => MetadataService());

final animeFeedProvider = FutureProvider.family<List<Work>, AnimeFeed>((ref, feed) {
  return ref.watch(metadataServiceProvider).feed(feed);
});
```

- [ ] **Step 3: Remove the asset from pubspec**

In `pubspec.yaml`, remove the line `    - assets/bangumi_calendar.json` under `assets:`.

- [ ] **Step 4: Verify no references remain**

Run: `flutter analyze lib`
Expected: No errors and no references to `bangumi`.

Also run: `git grep -i bangumi -- lib` (expected: no output).

- [ ] **Step 5: Commit (only if user asked)**

```bash
git add -A
git commit -m "chore: remove Bangumi metadata integration"
```

---
