### Task 4: Fixture + continuous-paging verification

**Files:**
- Modify: `assets/comic_source/test_source.js`
- Create (scratch, untracked): `.superpowers/sdd/comic_continuous_probe.dart`

- [ ] **Step 1: Give the fixture a category browser and a viewMore part**

In `assets/comic_source/test_source.js`, change the `分类` explore section to return a list of parts with a `viewMore`, and add a `category` + `categoryComics`:

```js
    {
      title: '分类',
      type: 'singlePageWithMultiPart',
      load: () => ([
        {
          title: '冒险',
          comics: [new Comic({ id: 'a1', title: 'Adventure 1' })],
          viewMore: 'category:全部@',
        },
      ]),
    },
```

and inside the class, after `comic = { ... }`:

```js
  category = {
    title: '测试分类',
    parts: [
      {
        name: '类型',
        type: 'fixed',
        categories: ['全部'],
        categoryParams: [''],
        itemType: 'category',
      },
    ],
  };

  categoryComics = {
    load: (category, param, options, page) => ({
      comics: [
        new Comic({ id: 'cat' + page + '-1', title: 'Cat ' + page + ' A' }),
        new Comic({ id: 'cat' + page + '-2', title: 'Cat ' + page + ' B' }),
        new Comic({ id: 'cat' + page + '-3', title: 'Cat ' + page + ' C' }),
      ],
      maxPage: 2,
    }),
    optionList: [],
  };
```

- [ ] **Step 2: Write the continuous probe**

Create `.superpowers/sdd/comic_continuous_probe.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:acgnhub/core/storage/database.dart';
import 'package:acgnhub/modules/comic/comic_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProbeApp());
}

class ProbeApp extends StatefulWidget {
  const ProbeApp({super.key});

  @override
  State<ProbeApp> createState() => _ProbeAppState();
}

class _ProbeAppState extends State<ProbeApp> {
  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await AppDatabase.init();
    final container = ProviderContainer();
    try {
      final manager = container.read(comicSourceManagerProvider);
      await manager.importFromFile(
          r'D:\ACGNhub\assets\comic_source\test_source.js');
      final sources = await container.read(comicSourcesProvider.future);
      final fixture = sources.firstWhere((s) => s.key == 'acgnhub_test');
      final section = fixture.sections.indexWhere((s) => s.title == '分类');
      if (section < 0) {
        print('PROBE CONTINUOUS section not found');
      } else {
        for (final page in [1, 2, 3]) {
          final data = await container.read(
              comicExploreProvider(('acgnhub_test', section, page)).future);
          print('PROBE CONTINUOUS page=$page '
              'ids=${data.comics.map((c) => c.id).toList()} '
              'maxPage=${data.maxPage} hasNext=${data.hasNext}');
        }
      }
    } catch (e, st) {
      print('PROBE ERROR $e\n$st');
    } finally {
      container.dispose();
    }
    print('PROBE DONE');
    exit(0);
  }

  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: Scaffold(body: Center(child: Text('continuous probe'))),
      );
}
```

- [ ] **Step 3: Run the probe**

```powershell
$env:Path = "C:\flutter\bin;$env:Path"; flutter run -d windows -t .superpowers/sdd/comic_continuous_probe.dart 2>&1 | Tee-Object -FilePath ".superpowers\sdd\continuous_probe.log"
```

Expected: page 1 → `ids=[a1]`, `maxPage=null`, `hasNext=true`; page 2 → `ids=[cat1-1, cat1-2, cat1-3]`, `hasNext=true`; page 3 → `ids=[cat2-1, cat2-2, cat2-3]`, `hasNext=false`. If page 2 does not switch to `cat*`, the continuation is broken — report it.

- [ ] **Step 4: Run the explore probe against manhuagui / baozi**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter run -d windows -t .superpowers/sdd/comic_explore_probe.dart 2>&1 | Tee-Object -FilePath ".superpowers\sdd\explore_probe9.log"`

Confirm manhuagui / baozi still return their explore content (the provider continuation is exercised in-app, not by this manager-level probe). Record their counts.

- [ ] **Step 5: Analyze, test, build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → all pass.
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug` → built.

- [ ] **Step 6: Commit and push**

```bash
git add assets/comic_source/test_source.js
git commit -m "test(comic): fixture for continuous category paging"
git push
```

(The probe is untracked scratch; do not commit it.)

---

## Self-Review

- **Spec coverage:** §4.1 `viewMore` → Task 1; §4.2 category metadata + `category()` → Task 2; §5 provider continuation → Task 3; §9 fixture/probe → Task 4. §6 UI unchanged (no task). §11 out-of-scope items appear in no task.
- **Placeholders:** none; every step shows the code.
- **Type consistency:** `ExplorePage{comics,maxPage,next,viewMore}` (Task 1) is returned by `explore`/`category` (Task 2) and consumed by the provider (Task 3); `ComicSource.hasCategoryComics/categoryDefault/categoryParam/categoryOptions` (Task 2) are read by the provider (Task 3); the family keys `(String sourceKey, int section)` and `(String sourceKey, int section, int page)` are unchanged.
- **Coupling:** Task 3 changes `comicExploreAllProvider`'s return type, so Task 2 and Task 3 are committed together only if Task 2 leaves the tree compiling (it does — `comicExploreAllProvider` still returns `List<Comic>` until Task 3; Task 2 only adds fields/methods).