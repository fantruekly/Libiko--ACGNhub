# Comic Explore Sections + Pagination Implementation Plan (C2c)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the 发现 tab a per-source explore-section selector and pagination (fixed comics per page with 上一页 / 下一页).

**Architecture:** Add a pure result parser (`ExplorePage`/`parseExploreResult`), teach the engine to read a source's explore sections and evaluate a chosen section/page, expose a `(sourceKey, section, page)` Riverpod family that applies the server-vs-client pagination rule, and add the section chips + pagination bar to `_DiscoverTab`.

**Tech Stack:** Flutter 3.35, Dart 3, Riverpod 2, `flutter_qjs` (native QuickJS; not runnable under `flutter test` — verified with app-level probes).

## Global Constraints

- Comic UI in `lib/modules/comic/`; engine in `lib/core/comic/`.
- Tokens: accent `#007AFF`, muted `#8E8E93`, border `#E5E5EA`. Grid constants: 6 columns, spacing (main 20 / cross 16), `childAspectRatio: 0.60`, padding `fromLTRB(16, 8, 16, 24)`.
- Server pagination only for `type == 'multiPageComicList'`; every other section loads once and is paginated client-side at **30/page**.
- The section selector is rendered only when the source has **more than one** section; a source change resets the section to 0 and the page to 1.
- Any provider calling the C1 engine must catch/surface errors, never an unhandled exception.
- No code comments unless the surrounding file already has them.
- Flutter commands run with `$env:Path = "C:\flutter\bin;$env:Path";` prefixed. Commit after every task and push to `origin/dev`.

---

### Task 1: `ExplorePage` + `parseExploreResult`

**Files:**
- Create: `lib/core/comic/explore_result.dart`
- Test: `test/core/comic/explore_result_test.dart`

**Interfaces:**
- Consumes: `Comic` (`lib/core/comic/models.dart`).
- Produces: `class ExplorePage { final List<Comic> comics; final int? maxPage; final String? next; const ExplorePage({required this.comics, this.maxPage, this.next}); }`; `ExplorePage parseExploreResult(dynamic raw)`.

- [ ] **Step 1: Write the failing test**

Create `test/core/comic/explore_result_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/comic/explore_result.dart';

void main() {
  test('parses a {comics, maxPage} result', () {
    final page = parseExploreResult({
      'comics': [
        {'id': '1', 'title': 'A'},
        {'id': '2', 'title': 'B'},
      ],
      'maxPage': 4,
    });
    expect(page.comics.map((c) => c.id), ['1', '2']);
    expect(page.maxPage, 4);
    expect(page.next, isNull);
  });

  test('parses a list of parts', () {
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
          {'id': '3', 'title': 'C'},
        ],
      },
    ]);
    expect(page.comics.map((c) => c.id), ['1', '2', '3']);
    expect(page.maxPage, isNull);
  });

  test('parses a {title: comics} map', () {
    final page = parseExploreResult({
      '推荐': [
        {'id': '1', 'title': 'A'},
      ],
      '热门': [
        {'id': '2', 'title': 'B'},
      ],
    });
    expect(page.comics.map((c) => c.id), ['1', '2']);
  });

  test('reads a cursor', () {
    final page = parseExploreResult({
      'comics': [
        {'id': '1', 'title': 'A'},
      ],
      'next': 'cursor-1',
    });
    expect(page.next, 'cursor-1');
  });

  test('tolerates empty and unknown input', () {
    expect(parseExploreResult(null).comics, isEmpty);
    expect(parseExploreResult('nope').comics, isEmpty);
    expect(parseExploreResult(<dynamic, dynamic>{}).comics, isEmpty);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/comic/explore_result_test.dart`
Expected: FAIL — `explore_result.dart` not found.

- [ ] **Step 3: Create `lib/core/comic/explore_result.dart`**

```dart
import 'models.dart';

/// A normalized explore/search result: the flattened comics plus optional
/// pagination metadata.
class ExplorePage {
  final List<Comic> comics;
  final int? maxPage;
  final String? next;

  const ExplorePage({required this.comics, this.maxPage, this.next});
}

/// Normalizes the shapes a Venera source can return from `search.load` /
/// `explore[].load`:
/// - `{ comics, maxPage }`
/// - `{ parts: [{ title, comics }] }`
/// - `[{ title, comics }]` (multiPartPage)
/// - `{ <title>: Comic[], ... }` (singlePageWithMultiPart)
/// - `{ data: [Comic[] | { title, comics }] }` (mixed)
ExplorePage parseExploreResult(dynamic raw) {
  final out = <Comic>[];
  void addComics(dynamic list) {
    if (list is! List) return;
    out.addAll(list
        .whereType<Map>()
        .map((e) => Comic.fromJs(e.cast<dynamic, dynamic>())));
  }

  void addParts(dynamic parts) {
    if (parts is! List) return;
    for (final part in parts) {
      if (part is Map) addComics(part['comics']);
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

  return ExplorePage(comics: out, maxPage: maxPage, next: next);
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/comic/explore_result_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Analyze**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`

- [ ] **Step 6: Commit and push**

```bash
git add lib/core/comic/explore_result.dart test/core/comic/explore_result_test.dart
git commit -m "feat(comic): add the explore result parser"
git push
```

---

### Task 2: Engine — explore sections + `explore(section, page, cursor)`

**Files:**
- Modify: `lib/core/comic/comic_source.dart`
- Modify: `assets/comic_source/test_source.js`
- Modify: `.superpowers/sdd/comic_explore_probe.dart` (verification only)

**Interfaces:**
- Consumes: `ExplorePage`/`parseExploreResult` (Task 1).
- Produces: `class ComicSourceSection { final String title; final String type; const ComicSourceSection({required this.title, required this.type}); }`; `ComicSource` gains `final List<ComicSourceSection> sections;`; `ComicSourceManager.explore(ComicSource source, int sectionIndex, {int page = 1, String? cursor}) → Future<ExplorePage>`.

- [ ] **Step 1: Add the section model and field**

In `lib/core/comic/comic_source.dart`, add above `class ComicSource`:

```dart
class ComicSourceSection {
  final String title;
  final String type;

  const ComicSourceSection({required this.title, required this.type});
}
```

Add the field to `ComicSource` (after `canOnImageLoad`) and the constructor parameter:

```dart
  final bool canOnImageLoad;
  final List<ComicSourceSection> sections;
```

```dart
    this.canOnImageLoad = false,
    this.sections = const [],
  });
```

In `fromMetadata`, add `sections: _sectionsFrom(meta['sections']),` to the returned `ComicSource(...)`, and add the helper:

```dart
  static List<ComicSourceSection> _sectionsFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => ComicSourceSection(
              title: e['title']?.toString() ?? '',
              type: e['type']?.toString() ?? '',
            ))
        .toList();
  }
```

- [ ] **Step 2: Return section metadata from the registry pass 2**

In `_registryJs`, inside `__acgnhub_registerSource`'s `finish` return object, add after `onImageLoad: ...`:

```js
      sections: (s.explore || []).map(function (e) {
        return { title: e.title || '', type: e.type || '' };
      })
```

- [ ] **Step 3: Import the parser and rewrite `explore`**

Add to the imports at the top of `comic_source.dart`:

```dart
import 'explore_result.dart';
```

Replace the `explore` method with:

```dart
  Future<ExplorePage> explore(ComicSource source, int sectionIndex,
      {int page = 1, String? cursor}) async {
    await _ensureInitialized();
    if (!source.canExplore) return const ExplorePage(comics: []);
    final result = await _engine.evaluate('''
      (async () => {
        const s = await globalThis.__acgnhub_instance(${jsonEncode(source.key)});
        const sec = (s.explore || [])[$sectionIndex];
        if (!sec) return { comics: [], maxPage: 1 };
        if (typeof sec.load === 'function') return await sec.load($page);
        if (typeof sec.loadNext === 'function') {
          return await sec.loadNext(${cursor == null ? 'undefined' : jsonEncode(cursor)});
        }
        return { comics: [], maxPage: 1 };
      })()
    ''');
    return parseExploreResult(result);
  }
```

- [ ] **Step 4: Route `search` through the parser and delete `_comicsFrom`**

In `search`, change `return _comicsFrom(result);` to `return parseExploreResult(result).comics;`, and delete the whole `_comicsFrom` method.

- [ ] **Step 5: Add explore sections to the test fixture**

Append an `explore` block to `class AcgnhubTestSource` in `assets/comic_source/test_source.js` (before the closing `}`):

```js
  explore = [
    {
      title: '最近更新',
      type: 'multiPageComicList',
      load: (page) => ({
        comics: [
          new Comic({ id: 'p' + page + '-1', title: 'Page ' + page + ' A' }),
          new Comic({ id: 'p' + page + '-2', title: 'Page ' + page + ' B' }),
        ],
        maxPage: 3,
      }),
    },
    {
      title: '分类',
      type: 'singlePageWithMultiPart',
      load: () => ({
        '冒险': [new Comic({ id: 'a1', title: 'Adventure 1' })],
        '日常': [new Comic({ id: 'd1', title: 'Daily 1' })],
      }),
    },
  ];
```

- [ ] **Step 6: Extend the probe to walk sections and pages**

Replace the body of `_run` in `.superpowers/sdd/comic_explore_probe.dart` with:

```dart
  Future<void> _run() async {
    await AppDatabase.init();
    final manager = ComicSourceManager();
    try {
      await manager.load();
      print('PROBE LOADED COUNT=${manager.sources.length}');
      for (final source in manager.sources) {
        if (!source.canExplore) {
          print('PROBE EXPLORE key=${source.key} SKIP no-explore');
          continue;
        }
        for (var section = 0; section < source.sections.length; section++) {
          for (var page = 1; page <= 2; page++) {
            try {
              final result = await manager
                  .explore(source, section, page: page)
                  .timeout(const Duration(seconds: 30));
              print('PROBE EXPLORE key=${source.key} section=$section '
                  'title=${source.sections[section].title} '
                  'type=${source.sections[section].type} page=$page '
                  'count=${result.comics.length} maxPage=${result.maxPage}');
            } catch (e) {
              print('PROBE EXPLORE key=${source.key} section=$section '
                  'page=$page ERROR=${e.runtimeType} $e');
            }
          }
        }
      }
    } catch (e) {
      print('PROBE LOAD ERROR ${e.runtimeType} $e');
    } finally {
      manager.dispose();
    }
    print('PROBE VERDICT DONE');
    exit(0);
  }
```

- [ ] **Step 7: Analyze, build, and run the probe**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug` → built.
Run the probe (rebuilds the exe with the probe entrypoint):

```powershell
$env:Path = "C:\flutter\bin;$env:Path"; flutter run -d windows -t .superpowers/sdd/comic_explore_probe.dart 2>&1 | Tee-Object -FilePath ".superpowers\sdd\explore_probe4.log"
```

Expected: each source reports its sections; copy_manga / manhuagui report `count` on section 0 (their `multiPartPage`/`singlePageWithMultiPart` content flattens); Komiic / zaimanhua report `maxPage` > 1 with page 2 differing from page 1; the test source's two sections both return content. Record the table.

- [ ] **Step 8: Commit and push**

```bash
git add lib/core/comic/comic_source.dart assets/comic_source/test_source.js
git commit -m "feat(comic): read explore sections and evaluate a chosen section and page"
git push
```

---

### Task 3: Provider + UI — section selector and pagination

The provider and its only consumer (`_DiscoverTab`) are coupled: changing the provider signature breaks the UI, so they are implemented and committed together.

**Files:**
- Modify: `lib/modules/comic/comic_providers.dart`
- Modify: `lib/modules/comic/comic_home.dart`

**Interfaces:**
- Consumes: `ComicSourceManager.explore` (Task 2), `ComicSource.sections` (Task 2).
- Produces: `class ComicExplorePage { final List<Comic> comics; final int page; final int maxPage; final bool serverPaged; }`; `final comicExploreProvider = FutureProvider.family<ComicExplorePage, (String, int, int)>(...)`.

- [ ] **Step 1: Replace the existing explore provider**

In `lib/modules/comic/comic_providers.dart`, replace the current `comicExploreProvider` declaration with:

```dart
/// One page of an explore section.
class ComicExplorePage {
  final List<Comic> comics;
  final int page;
  final int maxPage;
  final bool serverPaged;

  const ComicExplorePage({
    required this.comics,
    required this.page,
    required this.maxPage,
    required this.serverPaged,
  });
}

const _explorePageSize = 30;

/// `multiPageComicList` sections page on the source; every other section is
/// loaded once and paginated here at [_explorePageSize] comics per page.
final comicExploreProvider = FutureProvider.family<ComicExplorePage,
    (String, int, int)>((ref, key) async {
  final (sourceKey, section, page) = key;
  final manager = ref.watch(comicSourceManagerProvider);
  final source = ref
      .watch(comicSourcesProvider)
      .valueOrNull
      ?.where((s) => s.key == sourceKey)
      .firstOrNull;
  if (source == null) throw StateError('source $sourceKey not loaded');
  final type = section >= 0 && section < source.sections.length
      ? source.sections[section].type
      : '';
  if (type == 'multiPageComicList') {
    final result = await manager.explore(source, section, page: page);
    final maxPage = result.maxPage ?? page;
    return ComicExplorePage(
      comics: result.comics,
      page: page,
      maxPage: maxPage < 1 ? 1 : maxPage,
      serverPaged: true,
    );
  }
  final all = page == 1
      ? (await manager.explore(source, section, page: 1)).comics
      : (await ref.watch(
              comicExploreProvider((sourceKey, section, 1)).future))
          .comics;
  final maxPage =
      all.isEmpty ? 1 : (all.length + _explorePageSize - 1) ~/ _explorePageSize;
  final start = (page - 1) * _explorePageSize;
  final end = (start + _explorePageSize).clamp(0, all.length);
  final comics = start >= all.length ? const <Comic>[] : all.sublist(start, end);
  return ComicExplorePage(
    comics: comics,
    page: page,
    maxPage: maxPage,
    serverPaged: false,
  );
});
```

- [ ] **Step 2: Add state fields and reset on source change**

In `_DiscoverTabState`, add:

```dart
  int _selectedSection = 0;
  int _page = 1;
```

Change the source-chip `onSelected` to also reset:

```dart
      onSelected: (_) => setState(() {
        _selectedKey = source.key;
        _selectedSection = 0;
        _page = 1;
      }),
```

- [ ] **Step 3: Render the section chips between the source header and the grid**

In `_DiscoverTabState.build`, inside the `Column`'s `children`, after `_sourceHeader(sources, selected)` and before `Expanded(child: _explore(selected.key))`, insert:

```dart
            _sectionChips(selected),
```

Add the method:

```dart
  Widget _sectionChips(ComicSource source) {
    if (source.sections.length <= 1) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
        child: Row(
          children: [
            for (var i = 0; i < source.sections.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(source.sections[i].title.isEmpty
                      ? '分区 ${i + 1}'
                      : source.sections[i].title),
                  selected: i == _selectedSection,
                  showCheckmark: false,
                  onSelected: (_) => setState(() {
                    _selectedSection = i;
                    _page = 1;
                  }),
                  selectedColor: _accent,
                  backgroundColor: const Color(0xFFF2F2F7),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: i == _selectedSection ? Colors.white : _muted,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 4: Rewrite `_explore` to use the family and add the pagination bar**

Replace `_explore(String sourceKey)` with a version that takes the `ComicSource`:

```dart
  Widget _explore(ComicSource source) {
    final sections = source.sections;
    final section =
        sections.isEmpty ? 0 : _selectedSection.clamp(0, sections.length - 1);
    final async =
        ref.watch(comicExploreProvider((source.key, section, _page)));
    final pageData = async.valueOrNull;

    return Column(
      children: [
        Expanded(
          child: async.when(
            loading: () => const ShimmerLoader(
              crossAxisCount: 6,
              itemCount: 12,
              padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
            ),
            error: (_, __) => EmptyState(
              icon: Icons.cloud_off_rounded,
              message: '加载失败',
              actionLabel: '重试',
              onAction: () => ref.invalidate(
                  comicExploreProvider((source.key, section, _page))),
            ),
            data: (data) {
              if (data.comics.isEmpty) {
                return const EmptyState(
                    icon: Icons.image_not_supported_rounded, message: '暂无内容');
              }
              return _comicGrid(
                count: data.comics.length,
                itemBuilder: (i) => ComicCard(
                  title: data.comics[i].title,
                  cover: data.comics[i].cover,
                  heroTag: 'comic_${source.key}_${data.comics[i].id}',
                  onTap: () => Navigator.push(
                    context,
                    smoothRoute(ComicDetailPage(
                      sourceKey: source.key,
                      comicId: data.comics[i].id,
                      title: data.comics[i].title,
                      cover: data.comics[i].cover,
                    )),
                  ),
                ),
              );
            },
          ),
        ),
        if (pageData != null && pageData.maxPage > 1)
          _paginationBar(pageData.page, pageData.maxPage),
      ],
    );
  }

  Widget _paginationBar(int page, int maxPage) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: '上一页',
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: page > 1 ? () => setState(() => _page = page - 1) : null,
          ),
          const Spacer(),
          Text('第 $page / $maxPage 页',
              style: const TextStyle(fontSize: 13, color: _muted)),
          const Spacer(),
          IconButton(
            tooltip: '下一页',
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed:
                page < maxPage ? () => setState(() => _page = page + 1) : null,
          ),
        ],
      ),
    );
  }
```

Change the call site `Expanded(child: _explore(selected.key))` to `Expanded(child: _explore(selected))`.

- [ ] **Step 5: Analyze, test, build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → all pass.
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug` → built.

- [ ] **Step 6: In-app smoke test**

Launch `build\windows\x64\runner\Debug\acgnhub.exe`, open 漫画 → 发现: pick 再漫画 / Komiic (server-paged) and confirm 第 X / Y 页 with working 上一页 / 下一页; pick 拷贝漫画 / 漫画柜 (client-paged) and confirm a 30/page pager; confirm the section chips are hidden for single-section sources. Record the outcome.

- [ ] **Step 7: Commit and push**

```bash
git add lib/modules/comic/comic_providers.dart lib/modules/comic/comic_home.dart
git commit -m "feat(comic): add the explore section selector and pagination"
git push
```

---

## Self-Review

- **Spec coverage:** §4.1 `ComicSourceSection` → Task 2 Step 1; §4.2 `ExplorePage`/parser → Task 1; §4.3 `explore(section,page,cursor)` → Task 2 Step 3; §5 provider rule (server `multiPageComicList`, else 30/page client) → Task 3 Step 1; §6 section chips + pagination bar + resets → Task 3 Steps 2–4; §9 tests → Task 1, Task 2 fixture/probe, Task 3 smoke. `mixed` is handled defensively by the parser (Task 1) but the UI treats it as one-shot, per §11.
- **Placeholders:** none; every step shows the code.
- **Type consistency:** `ExplorePage{comics,maxPage,next}` (Task 1) is returned by `explore` (Task 2) and consumed by the provider (Task 3); `ComicExplorePage{comics,page,maxPage,serverPaged}` (Task 3) is consumed by the UI (Task 3); `ComicSourceSection{title,type}` is produced in Task 2 and read by Task 3. The family key is the record `(String sourceKey, int section, int page)` everywhere.
- **Out of scope:** new sources, AES, login, `loadNext` cursor UI, `mixed` semantics.
