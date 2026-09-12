### Task 4: `RuleStore`, source registry, and the bundled 7sefun rule

**Files:**
- Create: `lib/core/video/rule_store.dart`
- Create: `lib/core/video/video_sources.dart`
- Create: `assets/source_rules/7sefun.json`
- Modify: `pubspec.yaml`
- Test: `test/core/video/rule_store_test.dart`

**Interfaces:**
- Consumes: `SourceRule` (Task 1); `RuleVideoSource` (Task 3); `AgedmSource`, `GimySource` (existing).
- Produces: `class RuleStore { Future<List<SourceRule>> loadAll(); Future<List<SourceRule>> loadBuiltIn(); Future<List<SourceRule>> loadImported(); Future<SourceRule> importJson(String rawJson); }`; `@visibleForTesting static List<SourceRule> mergeRules(List<SourceRule> builtIn, List<SourceRule> imported)`; `final ruleStoreProvider = Provider<RuleStore>(...)`; `final videoSourcesProvider = FutureProvider<List<VideoSource>>(...)`; `List<VideoSource> buildSources(List<SourceRule> rules)`.

- [ ] **Step 1: Write the failing test**

Create `test/core/video/rule_store_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/video/rule_store.dart';
import 'package:acgnhub/core/video/source_rule.dart';

SourceRule _rule(String name) => SourceRule(
      name: name,
      baseUrl: 'https://$name.test/',
      searchUrl: 'https://$name.test/s?wd=@keyword',
      searchList: '//div',
      searchName: '//div[2]',
      searchResult: '//a',
      chapterRoads: '//div',
      chapterResult: '//a',
    );

void main() {
  test('mergeRules dedupes by name and imported wins', () {
    final merged = RuleStore.mergeRules(
      [_rule('a'), _rule('b')],
      [_rule('b'), _rule('c')],
    );
    expect(merged.map((r) => r.name).toSet(), {'a', 'b', 'c'});
    expect(merged.firstWhere((r) => r.name == 'b').baseUrl, 'https://b.test/');
  });

  test('bundled 7sefun rule parses from disk', () async {
    final raw = await File('assets/source_rules/7sefun.json').readAsString();
    final rule = SourceRule.fromJsonString(raw);
    expect(rule.name, '七色番');
    expect(rule.searchUrl, contains('@keyword'));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/video/rule_store_test.dart`
Expected: FAIL — `rule_store.dart` not found.

- [ ] **Step 3: Create `assets/source_rules/7sefun.json`**

```json
{
  "api": "4",
  "type": "anime",
  "name": "七色番",
  "version": "1.3",
  "muliSources": true,
  "useWebview": true,
  "useNativePlayer": true,
  "userAgent": "",
  "baseURL": "https://www.7sefun.top/",
  "searchURL": "https://www.7sefun.top/vodsearch/-------------.html?wd=@keyword",
  "searchList": "//div[2]/div[2]/div[2]/div[2]/div",
  "searchName": "//div[2]/text()",
  "searchResult": "//a",
  "chapterRoads": "//div[2]/div[2]/div[2]/div/div[2]/div[1]//div",
  "chapterResult": "//a"
}
```

- [ ] **Step 4: Declare the asset directory in `pubspec.yaml`**

Under `flutter: assets:` add the new line (keep the existing two entries):

```yaml
  assets:
    - assets/rules/
    - assets/source_rules/
    - assets/anime_seed.json
```

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter pub get`
Expected: `Got dependencies!`

- [ ] **Step 5: Create `lib/core/video/rule_store.dart`**

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'source_rule.dart';

/// Loads built-in rules from `assets/source_rules/` and user-imported rules
/// from `<app support dir>/rules/`. Imported rules win on a name collision.
class RuleStore {
  static const _assetDir = 'assets/source_rules/';
  static const _manifest = 'AssetManifest.json';

  Future<List<SourceRule>> loadAll() async {
    final builtIn = await loadBuiltIn();
    final imported = await loadImported();
    return mergeRules(builtIn, imported);
  }

  Future<List<SourceRule>> loadBuiltIn() async {
    final rules = <SourceRule>[];
    final manifestJson = await rootBundle.loadString(_manifest);
    final manifest = json.decode(manifestJson) as Map<String, dynamic>;
    final files = manifest.keys
        .where((k) => k.startsWith(_assetDir) && k.endsWith('.json'))
        .toList()
      ..sort();
    for (final file in files) {
      try {
        rules.add(SourceRule.fromJsonString(await rootBundle.loadString(file)));
      } catch (e) {
        debugPrint('[RuleStore] bad built-in rule $file: $e');
      }
    }
    return rules;
  }

  Future<Directory> _importDir() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'rules'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<List<SourceRule>> loadImported() async {
    final dir = await _importDir();
    final rules = <SourceRule>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        rules.add(SourceRule.fromJsonString(await entity.readAsString()));
      } catch (e) {
        debugPrint('[RuleStore] bad imported rule ${entity.path}: $e');
      }
    }
    return rules;
  }

  /// Parses [rawJson] (throws [FormatException] if invalid) and persists it.
  Future<SourceRule> importJson(String rawJson) async {
    final rule = SourceRule.fromJsonString(rawJson);
    final dir = await _importDir();
    final file = File(p.join(dir.path, '${_safeName(rule.name)}.json'));
    await file.writeAsString(rawJson);
    return rule;
  }

  static String _safeName(String name) =>
      name.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');

  @visibleForTesting
  static List<SourceRule> mergeRules(
      List<SourceRule> builtIn, List<SourceRule> imported) {
    final byName = <String, SourceRule>{};
    for (final r in builtIn) {
      byName[r.name] = r;
    }
    for (final r in imported) {
      byName[r.name] = r;
    }
    return byName.values.toList();
  }
}

final ruleStoreProvider = Provider<RuleStore>((ref) => RuleStore());
```

- [ ] **Step 6: Create `lib/core/video/video_sources.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'agedm_source.dart';
import 'gimy_source.dart';
import 'rule_source.dart';
import 'rule_store.dart';
import 'source_rule.dart';
import 'video_source.dart';

/// All playback sources: the hand-written HTTP sources plus every rule source.
List<VideoSource> buildSources(List<SourceRule> rules) => [
      AgedmSource(),
      GimySource(),
      for (final rule in rules) RuleVideoSource(rule),
    ];

final videoSourcesProvider = FutureProvider<List<VideoSource>>((ref) async {
  final rules = await ref.watch(ruleStoreProvider).loadAll();
  return buildSources(rules);
});
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/video/rule_store_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 8: Verify it compiles**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

- [ ] **Step 9: Commit**

```bash
git add lib/core/video/rule_store.dart lib/core/video/video_sources.dart assets/source_rules/7sefun.json pubspec.yaml test/core/video/rule_store_test.dart
git commit -m "feat(video): add rule store, source registry, and bundled 7sefun rule"
```

---
