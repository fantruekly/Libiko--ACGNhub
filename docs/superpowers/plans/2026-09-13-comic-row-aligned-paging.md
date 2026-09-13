# Comic Row-Aligned Paging Implementation Plan (C2g)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make server-paged and cursor-paged explore sections show UI pages of 48 comics (8 rows × 6 columns) by concatenating source pages, so only the true last page can have a partial row.

**Architecture:** Add `comicSourcePageProvider` (one source page, chaining cursors); rewrite `comicExploreProvider`'s server/cursor branches into one accumulate-and-slice branch at 48/page. No engine or UI layout change.

**Tech Stack:** Flutter 3.35, Dart 3, Riverpod 2, `flutter_qjs` (native QuickJS; not runnable under `flutter test`).

## Global Constraints

- Providers in `lib/modules/comic/`; client page size stays 48 (`_explorePageSize`).
- Client-paged and category-continuation behavior is unchanged.
- Aligned server/cursor sections report `maxPage = null` (the UI shows `第 X 页`).
- Any provider calling the C1 engine must catch/surface errors, never an unhandled exception.
- No code comments unless the surrounding file already has them.
- Flutter commands run with `$env:Path = "C:\flutter\bin;$env:Path";` prefixed. Commit after every task and push to `origin/dev`.

---

### Task 1: `comicSourcePageProvider` + aligned server/cursor branch

**Files:**
- Modify: `lib/modules/comic/comic_providers.dart`
- Modify: `lib/modules/comic/comic_home.dart` (retry invalidates the new provider)

**Interfaces:**
- Consumes: `ComicSourceManager.explore(..., {page, cursor})` and `ExplorePage` (C1/C2c).
- Produces: `final comicSourcePageProvider = FutureProvider.family<ExplorePage, (String, int, int)>`; `comicExploreProvider`'s server/cursor branch now slices 48/page.

- [ ] **Step 1: Add `comicSourcePageProvider`**

In `lib/modules/comic/comic_providers.dart`, add before `comicExploreProvider`:

```dart
/// One source page for a server- or cursor-paged section. Cursor sections
/// chain: source page N reads page N-1's `next`.
final comicSourcePageProvider =
    FutureProvider.family<ExplorePage, (String, int, int)>((ref, key) async {
  final (sourceKey, section, sourceIndex) = key;
  final manager = ref.watch(comicSourceManagerProvider);
  final source = ref
      .watch(comicSourcesProvider)
      .valueOrNull
      ?.where((s) => s.key == sourceKey)
      .firstOrNull;
  if (source == null) throw StateError('source $sourceKey not loaded');
  final meta = section >= 0 && section < source.sections.length
      ? source.sections[section]
      : null;
  if (meta?.usesLoadNext == true) {
    final cursor = sourceIndex <= 1
        ? null
        : (await ref.watch(
                comicSourcePageProvider((sourceKey, section, sourceIndex - 1))
                    .future))
            .next;
    return manager.explore(source, section, page: sourceIndex, cursor: cursor);
  }
  return manager.explore(source, section, page: sourceIndex);
});
```

- [ ] **Step 2: Replace the server/cursor branches in `comicExploreProvider`**

In `comicExploreProvider`, replace the whole `if (sectionMeta?.usesLoadNext == true) { ... }` block **and** the `if (type == 'multiPageComicList') { ... }` block (both branches, up to but not including the client-paged `final explore = ...` block) with one branch:

```dart
  if (sectionMeta?.usesLoadNext == true || type == 'multiPageComicList') {
    final accumulated = <Comic>[];
    var sourceIndex = 1;
    var hasMoreSource = true;
    while (accumulated.length <= page * _explorePageSize && hasMoreSource) {
      final sourcePage = await ref.watch(
          comicSourcePageProvider((sourceKey, section, sourceIndex)).future);
      accumulated.addAll(sourcePage.comics);
      if (sectionMeta?.usesLoadNext == true) {
        hasMoreSource = sourcePage.next != null;
      } else {
        hasMoreSource = sourcePage.maxPage != null
            ? sourceIndex < sourcePage.maxPage!
            : sourcePage.comics.isNotEmpty;
      }
      if (sourcePage.comics.isEmpty) break;
      sourceIndex++;
    }
    final start = (page - 1) * _explorePageSize;
    final end = (start + _explorePageSize).clamp(0, accumulated.length);
    final comics = start >= accumulated.length
        ? const <Comic>[]
        : accumulated.sublist(start, end);
    return ComicExplorePage(
      comics: comics,
      page: page,
      maxPage: null,
      hasNext: accumulated.length > page * _explorePageSize,
      serverPaged: true,
    );
  }
```

The client-paged branch (the `final explore = await ref.watch(comicExploreAllProvider(...))` block onward) stays exactly as it is.

- [ ] **Step 3: Make retry invalidate the source-page provider**

In `lib/modules/comic/comic_home.dart`, in `_explore`'s error `onAction`, add the source-page invalidation:

```dart
              onAction: () {
                ref.invalidate(comicSourcePageProvider);
                ref.invalidate(
                    comicExploreAllProvider((source.key, section)));
                ref.invalidate(
                    comicExploreProvider((source.key, section, _page)));
              },
```

- [ ] **Step 4: Analyze and build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug` → built.

- [ ] **Step 5: Commit and push**

```bash
git add lib/modules/comic/comic_providers.dart lib/modules/comic/comic_home.dart
git commit -m "feat(comic): row-align source and cursor explore pages to 48"
git push
```

---

### Task 2: Fixture + alignment verification

**Files:**
- Modify: `assets/comic_source/test_source.js`
- Modify: `lib/modules/comic/comic_providers.dart` (refresh a stale doc comment)
- Create (scratch, untracked): `.superpowers/sdd/comic_align_probe.dart`

- [ ] **Step 0: Refresh the stale `comicExploreProvider` doc comment**

In `lib/modules/comic/comic_providers.dart`, replace the doc comment above `comicExploreProvider` so it describes the current behavior: server/cursor sections accumulate source pages and are sliced at `_explorePageSize` (48) with `maxPage` null; one-shot sections are loaded once and continue into the source's category listing. Keep it a `///` doc comment.

- [ ] **Step 1: Give the fixture larger server/cursor pages**

In `assets/comic_source/test_source.js`, replace the `最近更新` section with:

```js
    {
      title: '最近更新',
      type: 'multiPageComicList',
      load: (page) => ({
        comics: Array.from(
          { length: 25 },
          (_, i) =>
            new Comic({ id: 'p' + page + '-' + i, title: 'Page ' + page + ' #' + i }),
        ),
        maxPage: 3,
      }),
    },
```

and replace the `游标` section with:

```js
    {
      title: '游标',
      type: 'multiPageComicList',
      loadNext: (next) => {
        const p = next ? Number(next) : 1;
        return {
          comics: Array.from(
            { length: 25 },
            (_, i) =>
              new Comic({ id: 'c' + p + '-' + i, title: 'Cursor ' + p + ' #' + i }),
          ),
          next: p < 3 ? String(p + 1) : null,
        };
      },
    },
```

- [ ] **Step 2: Write the alignment probe**

Create `.superpowers/sdd/comic_align_probe.dart`:

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
      for (final title in ['最近更新', '游标']) {
        final section = fixture.sections.indexWhere((s) => s.title == title);
        if (section < 0) {
          print('PROBE ALIGN $title section not found');
          continue;
        }
        for (final page in [1, 2]) {
          final data = await container
              .read(comicExploreProvider(('acgnhub_test', section, page)).future);
          print('PROBE ALIGN $title page=$page count=${data.comics.length} '
              'first=${data.comics.isEmpty ? '-' : data.comics.first.id} '
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
        home: Scaffold(body: Center(child: Text('align probe'))),
      );
}
```

- [ ] **Step 3: Run the probe**

```powershell
$env:Path = "C:\flutter\bin;$env:Path"; flutter run -d windows -t .superpowers/sdd/comic_align_probe.dart 2>&1 | Tee-Object -FilePath ".superpowers\sdd\align_probe.log"
```

Expected: `最近更新` page 1 → `count=48`, `hasNext=true`; page 2 → `count=27`, `hasNext=false`. `游标` page 1 → `count=48`, `hasNext=true`; page 2 → `count=27`, `hasNext=false`. If the counts differ, report DONE_WITH_CONCERNS with the actual output.

- [ ] **Step 4: Probe ehentai through the app**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter run -d windows -t .superpowers/sdd/comic_real_continuation_probe.dart 2>&1 | Tee-Object -FilePath ".superpowers\sdd\real_align_probe.log"`

Record whether the aligned page counts are multiples of 6 (the probe prints counts for ManHuaGui/baozi; add ehentai by reading `comicExploreProvider` for `ehentai` sections 0/1 pages 1–2 if the probe does not already cover it — if it does not, note that the alignment is covered by the fixture and skip).

- [ ] **Step 5: Analyze, test, build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → all pass.
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug` → built.

- [ ] **Step 6: Commit and push**

```bash
git add assets/comic_source/test_source.js
git commit -m "test(comic): fixture pages for row alignment"
git push
```

(Delete the copied `test_source.js` from the app source dir after the probe if `importFromFile` left it there. The probe is untracked scratch; do not commit it.)

---

## Self-Review

- **Spec coverage:** §4.1 `comicSourcePageProvider` → Task 1 Step 1; §4.2 aligned branch → Task 1 Step 2; retry → Task 1 Step 3; §8 fixture/probe → Task 2. §6 UI unchanged.
- **Placeholders:** none; every step shows the code.
- **Type consistency:** `comicSourcePageProvider` returns `ExplorePage` (Task 1) and is watched by the aligned branch (Task 1); the family keys `(String, int, int)` match `comicExploreProvider`'s shape; `_explorePageSize` is 48.
- **Note:** the older `.superpowers/sdd/comic_cursor_probe.dart` expects the fixture's `游标` section to yield `c1/c2/c3`; after this fixture change it is stale and superseded by `comic_align_probe.dart` (both are untracked scratch).
