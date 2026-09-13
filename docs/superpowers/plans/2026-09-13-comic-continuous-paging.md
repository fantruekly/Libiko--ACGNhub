# Comic Continuous Paging Implementation Plan (C2f)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a one-shot explore section's content is exhausted, keep paging by pulling the source's `categoryComics` listing automatically (using the part's `viewMore` target or the source's first category), so the user never taps a 查看更多 button.

**Architecture:** `ExplorePage` carries `viewMore`; `ComicSource` exposes category metadata and `ComicSourceManager.category(...)`; `comicExploreProvider`'s client-paged branch serves explore pages first, then category pages.

**Tech Stack:** Flutter 3.35, Dart 3, Riverpod 2, `flutter_qjs` (native QuickJS; not runnable under `flutter test`).

## Global Constraints

- Engine in `lib/core/comic/`; providers in `lib/modules/comic/`.
- Client page size stays 48 (6 columns × 8 rows); server/cursor/category pages keep the source's own size.
- A section whose source has no `categoryComics` stays finite (no behavior change).
- Any provider calling the C1 engine must catch/surface errors, never an unhandled exception.
- No code comments unless the surrounding file already has them.
- Flutter commands run with `$env:Path = "C:\flutter\bin;$env:Path";` prefixed. Commit after every task and push to `origin/dev`.

---

### Task 1: `ExplorePage.viewMore` + parser

**Files:**
- Modify: `lib/core/comic/explore_result.dart`
- Modify: `test/core/comic/explore_result_test.dart`

**Interfaces:**
- Produces: `ExplorePage` gains `final String? viewMore;`; `parseExploreResult` captures the first non-empty `viewMore` from parts/`data` entries.

- [ ] **Step 1: Write the failing test**

Append to `test/core/comic/explore_result_test.dart` inside `main()`:

```dart
  test('captures the first viewMore from parts', () {
    final page = parseExploreResult([
      {
        'title': 'p1',
        'comics': [
          {'id': '1', 'title': 'A'},
        ],
      },
      {
        'title': 'p2',
        'comics': [
          {'id': '2', 'title': 'B'},
        ],
        'viewMore': 'category:全部@',
      },
      {
        'title': 'p3',
        'comics': [
          {'id': '3', 'title': 'C'},
        ],
        'viewMore': 'category:later@x',
      },
    ]);
    expect(page.comics.map((c) => c.id), ['1', '2', '3']);
    expect(page.viewMore, 'category:全部@');
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/comic/explore_result_test.dart`
Expected: FAIL — `viewMore` getter not found.

- [ ] **Step 3: Add `viewMore` to `ExplorePage` and the parser**

In `lib/core/comic/explore_result.dart`, add the field:

```dart
class ExplorePage {
  final List<Comic> comics;
  final int? maxPage;
  final String? next;
  final String? viewMore;

  const ExplorePage(
      {required this.comics, this.maxPage, this.next, this.viewMore});
}
```

In `parseExploreResult`, track `viewMore`. Replace the body with:

```dart
ExplorePage parseExploreResult(dynamic raw) {
  final out = <Comic>[];
  void addComics(dynamic list) {
    if (list is! List) return;
    out.addAll(list
        .whereType<Map>()
        .map((e) => Comic.fromJs(e.cast<dynamic, dynamic>())));
  }

  String? viewMore;
  void takeViewMore(dynamic part) {
    if (part is! Map) return;
    final vm = part['viewMore'];
    if (viewMore == null && vm is String && vm.isNotEmpty) viewMore = vm;
  }

  void addParts(dynamic parts) {
    if (parts is! List) return;
    for (final part in parts) {
      if (part is Map) {
        addComics(part['comics']);
        takeViewMore(part);
      }
    }
  }

  int? maxPage;
  String? next;

  if (raw is List) {
    addParts(raw);
  } else if (raw is Map) {
    final comics = raw['comics'];
    final parts = raw['parts'];
    final data = raw['data'];
    if (comics is List) addComics(comics);
    if (parts is List) addParts(parts);
    if (data is List) {
      for (final item in data) {
        if (item is List) {
          addComics(item);
        } else if (item is Map) {
          addComics(item['comics']);
          takeViewMore(item);
        }
      }
    }
    if (comics is! List && parts is! List && data is! List) {
      for (final value in raw.values) {
        addComics(value);
      }
    }
    final mp = raw['maxPage'];
    if (mp is num) maxPage = mp.toInt();
    final n = raw['next'];
    if (n is String && n.isNotEmpty) next = n;
  }

  return ExplorePage(
      comics: out, maxPage: maxPage, next: next, viewMore: viewMore);
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/comic/explore_result_test.dart`
Expected: PASS (all tests, including the new one).

- [ ] **Step 5: Analyze**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`

- [ ] **Step 6: Commit and push**

```bash
git add lib/core/comic/explore_result.dart test/core/comic/explore_result_test.dart
git commit -m "feat(comic): capture the explore viewMore target"
git push
```

---

### Task 2: Category metadata + `ComicSourceManager.category`

**Files:**
- Modify: `lib/core/comic/comic_source.dart`

**Interfaces:**
- Consumes: `ExplorePage`/`parseExploreResult` (Task 1).
- Produces: `ComicSource` gains `bool hasCategoryComics`, `String categoryDefault`, `String categoryParam`, `List<String> categoryOptions`; `ComicSourceManager.category(ComicSource source, int page, {String? category, String? param, List<String>? options}) → Future<ExplorePage>`.

- [ ] **Step 1: Add the fields**

In `lib/core/comic/comic_source.dart`, add to `ComicSource` after `sections`:

```dart
  final bool hasCategoryComics;
  final String categoryDefault;
  final String categoryParam;
  final List<String> categoryOptions;
```

and to the constructor:

```dart
    this.hasCategoryComics = false,
    this.categoryDefault = '',
    this.categoryParam = '',
    this.categoryOptions = const [],
```

- [ ] **Step 2: Parse the category metadata in `fromMetadata`**

Add a helper and use it in the returned `ComicSource(...)`:

```dart
  static bool _hasCategory(dynamic raw) => raw is Map && raw['hasComics'] == true;
  static String _categoryStr(dynamic raw, String key) =>
      raw is Map ? (raw[key]?.toString() ?? '') : '';
  static List<String> _categoryList(dynamic raw, String key) {
    if (raw is! Map) return const [];
    final list = raw[key];
    if (list is! List) return const [];
    return list.map((e) => e.toString()).toList();
  }
```

In `fromMetadata`, before `return ComicSource(...)`:

```dart
    final category = meta['category'];
```

and in the constructor call add:

```dart
      hasCategoryComics: _hasCategory(category),
      categoryDefault: _categoryStr(category, 'category'),
      categoryParam: _categoryStr(category, 'param'),
      categoryOptions: _categoryList(category, 'options'),
```

- [ ] **Step 3: Expose the category metadata from the registry**

In `_registryJs`, inside `__acgnhub_registerSource`'s `finish` return object, add after `sections: ...`:

```js
      category: (function () {
        const c = s.category;
        const cc = s.categoryComics;
        const parts = c && Array.isArray(c.parts) ? c.parts : [];
        const part = parts.length ? parts[0] : null;
        const cats = part && Array.isArray(part.categories) ? part.categories : [];
        const params = part && Array.isArray(part.categoryParams) ? part.categoryParams : [];
        const optList = cc && Array.isArray(cc.optionList) ? cc.optionList : [];
        const options = optList.map(function (o) {
          const opts = o && Array.isArray(o.options) ? o.options : [];
          return opts.length ? String(opts[0]).split('-')[0] : '';
        });
        return {
          hasComics: !!(cc && typeof cc.load === 'function'),
          category: cats.length ? String(cats[0]) : '',
          param: params.length ? String(params[0]) : '',
          options: options
        };
      })()
```

- [ ] **Step 4: Add `ComicSourceManager.category`**

Add after `explore`:

```dart
  Future<ExplorePage> category(ComicSource source, int page,
      {String? category, String? param, List<String>? options}) async {
    await _ensureInitialized();
    if (!source.hasCategoryComics) return const ExplorePage(comics: []);
    final cat = category ?? source.categoryDefault;
    final par = param ?? source.categoryParam;
    final opts = options ?? source.categoryOptions;
    final result = await _engine.evaluate('''
      (async () => {
        const s = await globalThis.__acgnhub_instance(${jsonEncode(source.key)});
        if (!s.categoryComics || typeof s.categoryComics.load !== 'function') {
          return { comics: [], maxPage: 1 };
        }
        return await s.categoryComics.load(${jsonEncode(cat)}, ${jsonEncode(par)},
          ${jsonEncode(opts)}, $page);
      })()
    ''');
    return parseExploreResult(result);
  }
```

- [ ] **Step 5: Analyze and build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug` → built.

- [ ] **Step 6: Commit and push**

```bash
git add lib/core/comic/comic_source.dart
git commit -m "feat(comic): expose the source category listing"
git push
```

---

### Task 3: Provider continuation

**Files:**
- Modify: `lib/modules/comic/comic_providers.dart`

**Interfaces:**
- Consumes: `ExplorePage.viewMore` (Task 1), `ComicSource.hasCategoryComics`/`ComicSourceManager.category` (Task 2).

- [ ] **Step 1: Make `comicExploreAllProvider` return `ExplorePage`**

Replace its body with:

```dart
/// The full one-shot result for a non-server-paged section (cached per
/// section), including its `viewMore` target.
final comicExploreAllProvider =
    FutureProvider.family<ExplorePage, (String, int)>((ref, key) async {
  final (sourceKey, section) = key;
  final manager = ref.watch(comicSourceManagerProvider);
  final source = ref
      .watch(comicSourcesProvider)
      .valueOrNull
      ?.where((s) => s.key == sourceKey)
      .firstOrNull;
  if (source == null) throw StateError('source $sourceKey not loaded');
  return manager.explore(source, section, page: 1);
});
```

- [ ] **Step 2: Replace the client-paged branch**

In `comicExploreProvider`, replace the current client-paged block (the `final all = ...` block through its `return`) with:

```dart
  final explore =
      await ref.watch(comicExploreAllProvider((sourceKey, section)).future);
  final all = explore.comics;
  final explorePages =
      all.isEmpty ? 1 : (all.length + _explorePageSize - 1) ~/ _explorePageSize;
  if (page <= explorePages) {
    final start = (page - 1) * _explorePageSize;
    final end = (start + _explorePageSize).clamp(0, all.length);
    final comics = start >= all.length ? const <Comic>[] : all.sublist(start, end);
    return ComicExplorePage(
      comics: comics,
      page: page,
      maxPage: source.hasCategoryComics ? null : explorePages,
      hasNext: source.hasCategoryComics || page < explorePages,
      serverPaged: false,
    );
  }
  if (!source.hasCategoryComics) {
    return ComicExplorePage(
      comics: const [],
      page: page,
      maxPage: explorePages,
      hasNext: false,
      serverPaged: false,
    );
  }
  final catPage = page - explorePages;
  final (cat, param) = _continuationTarget(explore.viewMore);
  final result =
      await manager.category(source, catPage, category: cat, param: param);
  return ComicExplorePage(
    comics: result.comics,
    page: page,
    maxPage: null,
    hasNext: result.maxPage != null
        ? catPage < result.maxPage!
        : result.comics.isNotEmpty,
    serverPaged: true,
  );
```

Add the helper at file scope (near `_explorePageSize`):

```dart
(String?, String?) _continuationTarget(String? viewMore) {
  if (viewMore == null || !viewMore.startsWith('category:')) {
    return (null, null);
  }
  final rest = viewMore.substring('category:'.length);
  final at = rest.indexOf('@');
  if (at < 0) return (rest, null);
  return (rest.substring(0, at), rest.substring(at + 1));
}
```

- [ ] **Step 3: Analyze and build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug` → built.

- [ ] **Step 4: Commit and push**

```bash
git add lib/modules/comic/comic_providers.dart
git commit -m "feat(comic): continue one-shot explore sections into the category listing"
git push
```

---

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
