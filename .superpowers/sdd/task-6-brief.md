### Task 6: Import-rule button

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/modules/anime/anime_detail_page.dart`

**Interfaces:**
- Consumes: `ruleStoreProvider` (Task 4), `videoSourcesProvider` (Task 4).
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Add the file picker dependency**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter pub add file_selector`
Expected: `Got dependencies!` and a `file_selector:` line in `pubspec.yaml`.

- [ ] **Step 2: Add the import handler**

In `lib/modules/anime/anime_detail_page.dart`, add imports:

```dart
import 'package:file_selector/file_selector.dart';
import '../../core/video/rule_store.dart';
```

Add this method to `_AnimeDetailPageState`:

```dart
  Future<void> _importRule() async {
    final messenger = ScaffoldMessenger.of(context);
    const typeGroup = XTypeGroup(label: 'Kazumi 规则', extensions: ['json']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;
    try {
      final rule = await ref.read(ruleStoreProvider).importJson(
            await file.readAsString(),
          );
      ref.invalidate(videoSourcesProvider);
      if (!mounted) return;
      messenger.showSnackBar(
          SnackBar(content: Text('已导入规则：${rule.name}')));
      _searchAllSources();
    } on FormatException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
          SnackBar(content: Text('规则无效：${e.message}')));
    }
  }
```

- [ ] **Step 3: Add the button to the section header**

In `_playSection`, in the header `Row`, insert before the refresh `IconButton`:

```dart
                  IconButton(
                    tooltip: '导入规则',
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    onPressed: _importRule,
                    icon: const Icon(Icons.file_download_outlined),
                  ),
```

- [ ] **Step 4: Verify it compiles and builds**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib`
Expected: `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug`
Expected: `Built build\windows\x64\runner\Debug\acgnhub.exe`

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/modules/anime/anime_detail_page.dart
git commit -m "feat(anime): import Kazumi rule JSON from the resource section"
```

---
