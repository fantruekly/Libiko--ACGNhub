# Comic UI — Home, Sources, Search, Detail Implementation Plan (C2a)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 漫画 sidebar placeholder with a real module: a home (发现 / 收藏 / 历史), a source manager, search, and a comic detail page with a local favorite toggle.

**Architecture:** New Riverpod providers wrap C1's `ComicSourceManager`; two local stores (`ComicFavoriteManager`, `ComicHistoryManager`) mirror the anime module's `AppDatabase` JSON-list pattern; `ComicImageProvider` resolves per-image headers. The UI mirrors the anime module's pages and `lib/core/widgets/` components.

**Tech Stack:** Flutter 3.35, Dart 3, Riverpod 2, `dio`, `cached_network_image`, `file_selector` (already dependencies), plus C1's `lib/core/comic/`.

## Global Constraints

- Comic UI lives in `lib/modules/comic/`; stores and image loading in `lib/core/comic/`.
- **Reader is out of scope for this plan** (C2b): the detail page's chapter buttons navigate to a `ComicReaderPage` that C2b adds — for C2a they may show a `SnackBar('阅读器开发中')` placeholder; do NOT build the reader here.
- Design tokens: accent `#007AFF`, muted `#8E8E93`, border `#E5E5EA`, fg `#1C1C1E`, surface `#FFFFFF`.
- The comic home grid matches the anime home: `crossAxisCount: 6`, spacing 16, `childAspectRatio: 0.66`, padding `fromLTRB(16, 8, 16, 24)`.
- Local stores: `AppDatabase` JSON lists under `comic_favorites` / `comic_history`; malformed entries are skipped.
- Any provider that calls the C1 engine must catch and surface errors (never an unhandled exception), because the engine runs third-party JS.
- Commit after every task. Flutter commands run with `$env:Path = "C:\flutter\bin;$env:Path";` prefixed.

---

### Task 1: `ComicFavoriteManager`

**Files:**
- Create: `lib/core/comic/comic_favorite.dart`
- Test: `test/core/comic/comic_favorite_test.dart`

**Interfaces:**
- Consumes: `Comic` (C1's `lib/core/comic/models.dart`), `AppDatabase`.
- Produces: `class ComicFavorite { final String sourceKey; final String comicId; final String title; final String? cover; final DateTime addedAt; }` with `fromJson`/`toJson`; `class ComicFavoriteManager { List<ComicFavorite> all(); bool isFavorite(String sourceKey, String comicId); Future<void> toggle(ComicFavorite favorite); Future<void> remove(String sourceKey, String comicId); Future<void> clear(); @visibleForTesting static List<ComicFavorite> upsert(List<ComicFavorite>, ComicFavorite); }`; `final comicFavoritesProvider = NotifierProvider<ComicFavoritesNotifier, List<ComicFavorite>>(...)` with `isFavorite(sourceKey, comicId)`/`toggle(ComicFavorite)`.

- [ ] **Step 1: Write the failing test**

Create `test/core/comic/comic_favorite_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acgnhub/core/comic/comic_favorite.dart';
import 'package:acgnhub/core/storage/database.dart';

ComicFavorite _fav(String comicId, int ms) => ComicFavorite(
      sourceKey: 's1',
      comicId: comicId,
      title: 'Title $comicId',
      cover: 'c.jpg',
      addedAt: DateTime.fromMillisecondsSinceEpoch(ms),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('upsert dedupes by (sourceKey, comicId) and keeps the newest first', () {
    final result = ComicFavoriteManager.upsert(
        [_fav('a', 100), _fav('b', 200)], _fav('a', 300));
    expect(result, hasLength(2));
    expect(result.first.comicId, 'a');
    expect(result.first.addedAt.millisecondsSinceEpoch, 300);
    expect(result.last.comicId, 'b');
  });

  test('toggle adds then removes, and isFavorite reflects it', () async {
    await AppDatabase.init();
    final manager = ComicFavoriteManager();

    await manager.toggle(_fav('a', 100));
    expect(manager.isFavorite('s1', 'a'), isTrue);
    expect(manager.all(), hasLength(1));

    await manager.toggle(_fav('a', 100));
    expect(manager.isFavorite('s1', 'a'), isFalse);
    expect(manager.all(), isEmpty);
  });

  test('all() is newest-first and clear() empties', () async {
    await AppDatabase.init();
    final manager = ComicFavoriteManager();
    await manager.toggle(_fav('a', 100));
    await manager.toggle(_fav('b', 200));
    expect(manager.all().map((f) => f.comicId), ['b', 'a']);
    await manager.clear();
    expect(manager.all(), isEmpty);
  });

  test('a malformed stored entry is skipped', () async {
    await AppDatabase.init();
    final manager = ComicFavoriteManager();
    await manager.toggle(_fav('a', 100));

    final prefs = await SharedPreferences.getInstance();
    final key =
        prefs.getKeys().firstWhere((k) => k.endsWith('comic_favorites'));
    await prefs.setStringList(key, ['not json', ...prefs.getStringList(key)!]);

    expect(manager.all().map((f) => f.comicId), ['a']);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/comic/comic_favorite_test.dart`
Expected: FAIL — `comic_favorite.dart` not found.

- [ ] **Step 3: Create `lib/core/comic/comic_favorite.dart`**

```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/database.dart';

class ComicFavorite {
  final String sourceKey;
  final String comicId;
  final String title;
  final String? cover;
  final DateTime addedAt;

  const ComicFavorite({
    required this.sourceKey,
    required this.comicId,
    required this.title,
    this.cover,
    required this.addedAt,
  });

  factory ComicFavorite.fromJson(Map<String, dynamic> json) => ComicFavorite(
        sourceKey: json['sourceKey'] as String? ?? '',
        comicId: json['comicId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        cover: json['cover'] as String?,
        addedAt:
            DateTime.fromMillisecondsSinceEpoch(json['addedAt'] as int? ?? 0),
      );

  Map<String, dynamic> toJson() => {
        'sourceKey': sourceKey,
        'comicId': comicId,
        'title': title,
        'cover': cover,
        'addedAt': addedAt.millisecondsSinceEpoch,
      };
}

class ComicFavoriteManager {
  static const _key = 'comic_favorites';

  List<ComicFavorite> all() {
    final favorites = <ComicFavorite>[];
    for (final raw in AppDatabase().getStringList(_key)) {
      try {
        favorites.add(
            ComicFavorite.fromJson(json.decode(raw) as Map<String, dynamic>));
      } catch (_) {
        // Skip a malformed entry.
      }
    }
    favorites.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return favorites;
  }

  bool isFavorite(String sourceKey, String comicId) =>
      all().any((f) => f.sourceKey == sourceKey && f.comicId == comicId);

  Future<void> toggle(ComicFavorite favorite) async {
    final favorites = all();
    final exists = favorites.any((f) =>
        f.sourceKey == favorite.sourceKey && f.comicId == favorite.comicId);
    if (exists) {
      await remove(favorite.sourceKey, favorite.comicId);
    } else {
      await _save(upsert(favorites, favorite));
    }
  }

  Future<void> remove(String sourceKey, String comicId) async {
    final favorites = all()
        .where((f) => !(f.sourceKey == sourceKey && f.comicId == comicId))
        .toList();
    await _save(favorites);
  }

  Future<void> clear() => AppDatabase().remove(_key);

  Future<void> _save(List<ComicFavorite> favorites) async {
    await AppDatabase().setStringList(
        _key, favorites.map((f) => json.encode(f.toJson())).toList());
  }

  @visibleForTesting
  static List<ComicFavorite> upsert(
      List<ComicFavorite> current, ComicFavorite favorite) {
    final out = current
        .where((f) =>
            !(f.sourceKey == favorite.sourceKey &&
                f.comicId == favorite.comicId))
        .toList();
    out.insert(0, favorite);
    return out;
  }
}

class ComicFavoritesNotifier extends Notifier<List<ComicFavorite>> {
  final _manager = ComicFavoriteManager();

  @override
  List<ComicFavorite> build() => _manager.all();

  bool isFavorite(String sourceKey, String comicId) =>
      state.any((f) => f.sourceKey == sourceKey && f.comicId == comicId);

  Future<void> toggle(ComicFavorite favorite) async {
    await _manager.toggle(favorite);
    state = _manager.all();
  }

  Future<void> clear() async {
    await _manager.clear();
    state = const [];
  }
}

final comicFavoritesProvider =
    NotifierProvider<ComicFavoritesNotifier, List<ComicFavorite>>(
        ComicFavoritesNotifier.new);
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/comic/comic_favorite_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Analyze**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/core/comic/comic_favorite.dart test/core/comic/comic_favorite_test.dart
git commit -m "feat(comic): add the local comic favorite store"
```

---

### Task 2: `ComicHistoryManager`

**Files:**
- Create: `lib/core/comic/comic_history.dart`
- Test: `test/core/comic/comic_history_test.dart`

**Interfaces:**
- Produces: `class ComicHistoryEntry { final String sourceKey; final String comicId; final String title; final String? cover; final String chapterId; final String chapterTitle; final int page; final DateTime readAt; }` with `fromJson`/`toJson`/`copyWith`; `class ComicHistoryManager { List<ComicHistoryEntry> all(); ComicHistoryEntry? forComic(String sourceKey, String comicId); Future<void> record(ComicHistoryEntry); Future<void> clear(); @visibleForTesting static List<ComicHistoryEntry> upsert(List<ComicHistoryEntry>, ComicHistoryEntry); }`; `final comicHistoryProvider = NotifierProvider<ComicHistoryNotifier, List<ComicHistoryEntry>>(...)` with `record`/`clear`.

- [ ] **Step 1: Write the failing test**

Create `test/core/comic/comic_history_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acgnhub/core/comic/comic_history.dart';
import 'package:acgnhub/core/storage/database.dart';

ComicHistoryEntry _entry(String comicId, String chapter, int page, int ms) =>
    ComicHistoryEntry(
      sourceKey: 's1',
      comicId: comicId,
      title: 'Title $comicId',
      cover: 'c.jpg',
      chapterId: chapter,
      chapterTitle: '第$chapter话',
      page: page,
      readAt: DateTime.fromMillisecondsSinceEpoch(ms),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('upsert dedupes by comic and keeps the newest first', () {
    final result = ComicHistoryManager.upsert(
        [_entry('a', '1', 0, 100), _entry('b', '1', 0, 200)],
        _entry('a', '5', 3, 300));
    expect(result, hasLength(2));
    expect(result.first.comicId, 'a');
    expect(result.first.chapterId, '5');
    expect(result.first.page, 3);
    expect(result.last.comicId, 'b');
  });

  test('record stores and forComic finds the entry', () async {
    await AppDatabase.init();
    final manager = ComicHistoryManager();
    await manager.record(_entry('a', '2', 1, 100));
    expect(manager.all(), hasLength(1));
    expect(manager.forComic('s1', 'a')!.chapterId, '2');
    expect(manager.forComic('s1', 'nope'), isNull);
  });

  test('clear empties the history', () async {
    await AppDatabase.init();
    final manager = ComicHistoryManager();
    await manager.record(_entry('a', '1', 0, 100));
    await manager.clear();
    expect(manager.all(), isEmpty);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/comic/comic_history_test.dart`
Expected: FAIL — `comic_history.dart` not found.

- [ ] **Step 3: Create `lib/core/comic/comic_history.dart`**

```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/database.dart';

class ComicHistoryEntry {
  final String sourceKey;
  final String comicId;
  final String title;
  final String? cover;
  final String chapterId;
  final String chapterTitle;
  final int page;
  final DateTime readAt;

  const ComicHistoryEntry({
    required this.sourceKey,
    required this.comicId,
    required this.title,
    this.cover,
    required this.chapterId,
    required this.chapterTitle,
    required this.page,
    required this.readAt,
  });

  factory ComicHistoryEntry.fromJson(Map<String, dynamic> json) =>
      ComicHistoryEntry(
        sourceKey: json['sourceKey'] as String? ?? '',
        comicId: json['comicId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        cover: json['cover'] as String?,
        chapterId: json['chapterId'] as String? ?? '',
        chapterTitle: json['chapterTitle'] as String? ?? '',
        page: json['page'] as int? ?? 0,
        readAt: DateTime.fromMillisecondsSinceEpoch(json['readAt'] as int? ?? 0),
      );

  Map<String, dynamic> toJson() => {
        'sourceKey': sourceKey,
        'comicId': comicId,
        'title': title,
        'cover': cover,
        'chapterId': chapterId,
        'chapterTitle': chapterTitle,
        'page': page,
        'readAt': readAt.millisecondsSinceEpoch,
      };

  ComicHistoryEntry copyWith({
    String? chapterId,
    String? chapterTitle,
    int? page,
    DateTime? readAt,
  }) =>
      ComicHistoryEntry(
        sourceKey: sourceKey,
        comicId: comicId,
        title: title,
        cover: cover,
        chapterId: chapterId ?? this.chapterId,
        chapterTitle: chapterTitle ?? this.chapterTitle,
        page: page ?? this.page,
        readAt: readAt ?? this.readAt,
      );
}

class ComicHistoryManager {
  static const _key = 'comic_history';

  List<ComicHistoryEntry> all() {
    final entries = <ComicHistoryEntry>[];
    for (final raw in AppDatabase().getStringList(_key)) {
      try {
        entries.add(ComicHistoryEntry.fromJson(
            json.decode(raw) as Map<String, dynamic>));
      } catch (_) {
        // Skip a malformed entry.
      }
    }
    entries.sort((a, b) => b.readAt.compareTo(a.readAt));
    return entries;
  }

  ComicHistoryEntry? forComic(String sourceKey, String comicId) {
    for (final entry in all()) {
      if (entry.sourceKey == sourceKey && entry.comicId == comicId) {
        return entry;
      }
    }
    return null;
  }

  Future<void> record(ComicHistoryEntry entry) async {
    await _save(upsert(all(), entry));
  }

  Future<void> clear() => AppDatabase().remove(_key);

  Future<void> _save(List<ComicHistoryEntry> entries) async {
    await AppDatabase().setStringList(
        _key, entries.map((e) => json.encode(e.toJson())).toList());
  }

  @visibleForTesting
  static List<ComicHistoryEntry> upsert(
      List<ComicHistoryEntry> current, ComicHistoryEntry entry) {
    final out = current
        .where((e) =>
            !(e.sourceKey == entry.sourceKey && e.comicId == entry.comicId))
        .toList();
    out.insert(0, entry);
    return out;
  }
}

class ComicHistoryNotifier extends Notifier<List<ComicHistoryEntry>> {
  final _manager = ComicHistoryManager();

  @override
  List<ComicHistoryEntry> build() => _manager.all();

  Future<void> record(ComicHistoryEntry entry) async {
    await _manager.record(entry);
    state = _manager.all();
  }

  Future<void> clear() async {
    await _manager.clear();
    state = const [];
  }
}

final comicHistoryProvider =
    NotifierProvider<ComicHistoryNotifier, List<ComicHistoryEntry>>(
        ComicHistoryNotifier.new);
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/comic/comic_history_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Analyze**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/core/comic/comic_history.dart test/core/comic/comic_history_test.dart
git commit -m "feat(comic): add the local comic history store"
```

---

### Task 3: Comic providers + image loading

**Files:**
- Create: `lib/modules/comic/comic_providers.dart`
- Create: `lib/core/comic/comic_image.dart`

**Interfaces:**
- Consumes: `ComicSourceManager`/`Comic`/`ComicDetails`/`ComicEp`/`ImageLoadingConfig` (C1).
- Produces: `final comicSourceManagerProvider = Provider<ComicSourceManager>(...)`; `final comicSourcesProvider = FutureProvider<List<ComicSource>>(...)`; `final comicExploreProvider = FutureProvider.family<List<Comic>, String>(...)` (sourceKey → the first explore section's first page); `final comicSearchProvider = FutureProvider.family<List<Comic>, String>(...)` (keyword → merged results across sources); `final comicDetailProvider = FutureProvider.family<ComicDetails, (String, String)>(...)`; `final comicEpProvider = FutureProvider.family<ComicEp, (String, String, String)>(...)`; `final comicSourceListUrlProvider` (a `NotifierProvider<..., String>` over `AppDatabase` key `comic_source_list_url`); `class ComicImageProvider` with `static ImageProvider of(String sourceKey, String comicId, String chapterId, String url)`.

- [ ] **Step 1: Create `lib/modules/comic/comic_providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/comic/comic_source.dart';
import '../../core/comic/models.dart';

final comicSourceManagerProvider =
    Provider<ComicSourceManager>((ref) => ComicSourceManager());

final comicSourcesProvider = FutureProvider<List<ComicSource>>((ref) async {
  final manager = ref.watch(comicSourceManagerProvider);
  await manager.load();
  return manager.sources;
});

/// The first explore section's first page for a source.
final comicExploreProvider =
    FutureProvider.family<List<Comic>, String>((ref, sourceKey) async {
  final manager = ref.watch(comicSourceManagerProvider);
  final source = ref
      .watch(comicSourcesProvider)
      .valueOrNull
      ?.where((s) => s.key == sourceKey)
      .firstOrNull;
  if (source == null || !source.canExplore) return const [];
  return manager.explore(source, 0);
});

/// A search hit paired with the source that produced it (a comic id is only
/// meaningful together with its source key).
class ComicSearchResult {
  final Comic comic;
  final String sourceKey;
  const ComicSearchResult({required this.comic, required this.sourceKey});
}

/// Search across every source that can search, merging the results.
final comicSearchProvider =
    FutureProvider.family<List<ComicSearchResult>, String>(
        (ref, keyword) async {
  final manager = ref.watch(comicSourceManagerProvider);
  final sources = ref.watch(comicSourcesProvider).valueOrNull ?? const [];
  final results = <ComicSearchResult>[];
  for (final source in sources.where((s) => s.canSearch)) {
    try {
      for (final comic in await manager.search(source, keyword)) {
        results.add(ComicSearchResult(comic: comic, sourceKey: source.key));
      }
    } catch (_) {
      // A source that fails is skipped; the others still contribute.
    }
  }
  return results;
});

final comicDetailProvider =
    FutureProvider.family<ComicDetails, (String, String)>(
        (ref, key) async {
  final manager = ref.watch(comicSourceManagerProvider);
  final (sourceKey, comicId) = key;
  final source = ref
      .watch(comicSourcesProvider)
      .valueOrNull
      ?.where((s) => s.key == sourceKey)
      .firstOrNull;
  if (source == null) throw StateError('source $sourceKey not loaded');
  return manager.loadInfo(source, comicId);
});

final comicEpProvider =
    FutureProvider.family<ComicEp, (String, String, String)>(
        (ref, key) async {
  final manager = ref.watch(comicSourceManagerProvider);
  final (sourceKey, comicId, chapterId) = key;
  final source = ref
      .watch(comicSourcesProvider)
      .valueOrNull
      ?.where((s) => s.key == sourceKey)
      .firstOrNull;
  if (source == null) throw StateError('source $sourceKey not loaded');
  return manager.loadEp(source, comicId, chapterId);
});
```

- [ ] **Step 2: Create `lib/core/comic/comic_image.dart`**

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

import 'comic_source.dart';

/// Resolves a comic page URL to an [ImageProvider] carrying the per-image
/// headers a source's `onImageLoad` demands (typically a `referer`).
class ComicImageProvider {
  ComicImageProvider(this.manager);

  final ComicSourceManager manager;

  Future<ImageProvider> resolve(
    String sourceKey,
    String comicId,
    String chapterId,
    String url,
  ) async {
    var effective = url;
    Map<String, String>? headers;
    final source = manager.sources.where((s) => s.key == sourceKey).firstOrNull;
    if (source != null) {
      try {
        final config = await manager.onImageLoad(source, url, comicId, chapterId);
        effective = config.url ?? url;
        headers = config.headers;
      } catch (_) {
        // Fall back to a plain request when the source hook fails.
      }
    }
    return CachedNetworkImageProvider(effective, headers: headers);
  }
}
```

Add `final comicImageProvider = Provider<ComicImageProvider>((ref) => ComicImageProvider(ref.watch(comicSourceManagerProvider)));` to `comic_providers.dart` (with the `comic_image.dart` import).

- [ ] **Step 3: Analyze**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
(No unit tests here: the providers call the C1 engine, which `flutter test` cannot load. Their behaviour is covered by C1's probes and by the in-app smoke test.)

- [ ] **Step 4: Commit**

```bash
git add lib/modules/comic/comic_providers.dart lib/core/comic/comic_image.dart
git commit -m "feat(comic): add comic providers and image loading"
```

---

### Task 4: Comic home + source management page

**Files:**
- Create: `lib/modules/comic/comic_home.dart`
- Create: `lib/modules/comic/comic_source_page.dart`

**Interfaces:**
- Consumes: Tasks 1–3; `lib/core/widgets/` (`GlassSurface`, `EmptyState`, `ShimmerLoader`, `smooth_route`), `AnimeDetailPage`-style navigation.
- Produces: `class ComicHomePage extends ConsumerStatefulWidget`; `class ComicSourcePage extends ConsumerStatefulWidget`.

- [ ] **Step 1: Create `lib/modules/comic/comic_home.dart`**

Structure (mirror `lib/modules/anime/anime_home.dart`'s tab pattern):

```dart
class ComicHomePage extends ConsumerStatefulWidget { ... }

class _ComicHomePageState extends ConsumerState<ComicHomePage> {
  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            labelColor: Color(0xFF007AFF),
            unselectedLabelColor: Color(0xFF8E8E93),
            indicatorColor: Color(0xFF007AFF),
            dividerColor: Color(0xFFE5E5EA),
            tabs: [Tab(text: '发现'), Tab(text: '收藏'), Tab(text: '历史')],
          ),
          Expanded(
            child: TabBarView(
              children: [_DiscoverTab(), _FavoritesTab(), _HistoryTab()],
            ),
          ),
        ],
      ),
    );
  }
}
```

- `_DiscoverTab` (`ConsumerStatefulWidget`, keeps the selected source key in state):
  - `ref.watch(comicSourcesProvider)`; when empty → `EmptyState(icon: Icons.extension_off_rounded, message: '还没有添加漫画源', actionLabel: '添加源', onAction: → ComicSourcePage)`.
  - Otherwise: a header `Row` of source chips (`ChoiceChip`-style, accent when selected, exactly like the anime home's pill styling) + a `Spacer` + an `IconButton(Icons.settings_rounded, tooltip: '源管理')` opening `ComicSourcePage`.
  - `ref.watch(comicExploreProvider(selectedKey))` → `ShimmerLoader` while loading, an inline retry on error, else a `GridView.builder` with the anime home's grid constants (`crossAxisCount: 6`, spacing 16, `childAspectRatio: 0.66`, padding `fromLTRB(16, 8, 16, 24)`) of `ComicCard`s.
  - `ComicCard` (a private widget in this file): cover via `CachedNetworkImage` (`memCacheWidth: 400`) in a `ClipRRect(10)`, title below (13 px, max 2 lines), tapping pushes `ComicDetailPage(sourceKey: …, comic: …)` via `smoothRoute`.
- `_FavoritesTab`: `ref.watch(comicFavoritesProvider)` → the same grid of `ComicCard`s built from the favorites' `title`/`cover`; tapping pushes `ComicDetailPage` (constructed from the favorite's ids); `EmptyState(icon: Icons.favorite_border_rounded, message: '还没有收藏')` when empty.
- `_HistoryTab`: `ref.watch(comicHistoryProvider)` → a `ListView` of rows: cover 56×76, title, `看到 ${e.chapterTitle}` (12 px muted), the relative time; tapping pushes `ComicDetailPage` for that comic (C2b will resume the reader at the recorded chapter); a header `Row` with 历史记录 + a 清空历史 `TextButton` (a confirm dialog like `AnimeHistoryView`); `EmptyState(icon: Icons.history_rounded, message: '还没有阅读记录')` when empty.

- [ ] **Step 2: Create `lib/modules/comic/comic_source_page.dart`**

`Scaffold(appBar: AppBar(title: Text('源管理')), body: ListView(...))`:
- For each source in `ref.watch(comicSourcesProvider)`: a `ListTile` with the name as title, `key · v${version}` as subtitle, capability chips (`搜索`/`发现`/`详情`/`章节`), a trailing `PopupMenuButton` with 刷新 (enabled only when `url.isNotEmpty`) and 删除 (confirm dialog → `manager.remove(source)` then `ref.invalidate(comicSourcesProvider)`).
- A 添加源 section: a `TextField` + a 从 URL 导入 `FilledButton`; a 从文件导入 `OutlinedButton` using `file_selector`'s `openFile(acceptedTypeGroups: [XTypeGroup(label: 'JS 源', extensions: ['js'])])`; both call `manager.importFromUrl`/`importFromFile`, show a `SnackBar` on success, and show the `FormatException`/error message inline (red 13 px) on failure; then `ref.invalidate(comicSourcesProvider)`.
- A 远程规则列表 section: a `TextField` bound to `comic_source_list_url`, a 获取列表 button that GETs the JSON list and renders each entry with an 添加 button calling `manager.importFromUrl(entry['url'])`.

- [ ] **Step 3: Analyze, test, build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → all pass.
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug` → built.

- [ ] **Step 4: Commit**

```bash
git add lib/modules/comic/comic_home.dart lib/modules/comic/comic_source_page.dart
git commit -m "feat(comic): add the comic home and source management"
```

---

### Task 5: Comic search

**Files:**
- Create: `lib/modules/comic/comic_search.dart`

**Interfaces:**
- Consumes: `comicSearchProvider` (Task 3), `ComicCard` (Task 4 — make it a public widget in `comic_home.dart` or move it to a shared file so both pages use it).
- Produces: `class ComicSearchPage extends ConsumerStatefulWidget`.

- [ ] **Step 1: Create `lib/modules/comic/comic_search.dart`**

Mirror `lib/modules/anime/anime_search.dart`:
- A top search field (a `TextField` with a search icon, `onSubmitted` sets the keyword state).
- `ref.watch(comicSearchProvider(keyword))` → `ShimmerLoader` while loading, an inline error + 重试 on failure, `EmptyState(icon: Icons.search_off_rounded, message: '没有找到漫画')` when empty, else the same `GridView` of `ComicCard`s (grid constants as in Task 4).
- Each result is a `ComicSearchResult` (already defined in Task 3), so the card carries its `sourceKey`; tapping pushes `ComicDetailPage(sourceKey: result.sourceKey, comicId: result.comic.id, title: result.comic.title, cover: result.comic.cover)`.

- [ ] **Step 2: Analyze and build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug` → built.

- [ ] **Step 3: Commit**

```bash
git add lib/modules/comic/comic_search.dart lib/modules/comic/comic_providers.dart
git commit -m "feat(comic): add comic search"
```

---

### Task 6: Comic detail page

**Files:**
- Create: `lib/modules/comic/comic_detail_page.dart`

**Interfaces:**
- Consumes: `comicDetailProvider` (Task 3), `comicFavoritesProvider` (Task 1), `comicHistoryProvider` (Task 2), `ComicImageProvider` (Task 3), `WindowControls`/`smooth_route`.
- Produces: `class ComicDetailPage extends ConsumerStatefulWidget { final String sourceKey; final String comicId; final String title; final String? cover; }`.

- [ ] **Step 1: Create `lib/modules/comic/comic_detail_page.dart`**

Structure (mirror `lib/modules/anime/anime_detail_page.dart`'s layout):
- `_header`: `DragToMoveArea` + a 48 px `Container` with a back button, the title (`Expanded`), and `const WindowControls()`.
- Body: `CustomScrollView` with:
  - an info card (a `GlassSurface(blur: 0)` like the anime info card): a `Row` of the cover (`Hero(tag: 'comic_${sourceKey}_$comicId')`, 110×154, `ClipRRect(10)`, `memCacheWidth: 300`) and, 24 px to its right, a `Column` of: the title (20 px w600, max 2 lines), a 14 px gap, the 收藏 button (a `FilledButton.icon`, `收藏` accent-filled + `Icons.bookmark_add_outlined` → `已收藏` dimmed `#E5E5EA`/`#8E8E93` + `Icons.bookmark_added_rounded`, 36 px high, radius 10), a 14 px gap, then the tags `Wrap` (the anime `_metaChip` styling) and the description (13 px, muted, max 3 lines + a 展开/收起 toggle);
  - a 章节 section: a header `Row` (章节 + a count) and a `Wrap` of chapter buttons — each 104×44, radius 10, accent 6 % fill + 30 % border, label = the chapter title (single line ellipsis) — built from `details.chapters`; tapping shows `SnackBar('阅读器开发中')` for C2a (C2b replaces this with `ComicReaderPage`);
  - a 继续阅读 button when `comicHistoryProvider` has an entry for this comic (also a C2a placeholder `SnackBar`).
- Loading: `ShimmerLoader`; error: an `EmptyState` with a 重试 action calling `ref.invalidate(comicDetailProvider((sourceKey, comicId)))`.
- The 收藏 button builds a `ComicFavorite` from the loaded details (`sourceKey`, `comicId`, title, cover, `DateTime.now()`) and calls `ref.read(comicFavoritesProvider.notifier).toggle(...)`.

- [ ] **Step 2: Analyze, test, build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → all pass.
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug` → built.

- [ ] **Step 3: Commit**

```bash
git add lib/modules/comic/comic_detail_page.dart
git commit -m "feat(comic): add the comic detail page"
```

---

### Task 7: Shell wiring + final verification

**Files:**
- Modify: `lib/shell/main_shell.dart`

- [ ] **Step 1: Wire the module into the shell**

In `lib/shell/main_shell.dart`:
- import `'../modules/comic/comic_home.dart'` and `'../modules/comic/comic_search.dart'`;
- replace `_pages[1]` (the 漫画 placeholder) with `const ComicHomePage()`;
- make the title-bar search `IconButton` open `ComicSearchPage` when `_currentIndex == 1` (it currently opens the anime search for `_currentIndex == 0`).

- [ ] **Step 2: Analyze, test, build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → all pass.
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug` → built.

- [ ] **Step 3: In-app smoke test (manual)**

Launch the app, open 漫画, and: add a source (import `assets/comic_source/test_source.js` from the repo via 从文件导入), confirm it appears with its capability chips; search a keyword and confirm the fixture's two results; open a detail page and confirm the chapters render and 收藏 toggles; check the 收藏 tab shows it and the 历史 tab is empty. Record the outcome.

- [ ] **Step 4: Commit**

```bash
git add lib/shell/main_shell.dart
git commit -m "feat(comic): wire the comic module into the shell"
```

---

## Self-Review

- **Spec coverage:** §3 stores → Tasks 1–2; §3 image + providers → Task 3; §4 home → Task 4; §5 source management → Task 4; §6 detail → Task 6; search (§4's search entry) → Task 5; shell wiring → Task 7; §10 tests → Tasks 1–2, 7. The reader (§7) is C2b.
- **Placeholders:** the only intentional placeholders are the C2a chapter/继续阅读 `SnackBar`s, which C2b replaces — called out explicitly in Task 6.
- **Type consistency:** `ComicFavorite{sourceKey, comicId, title, cover, addedAt}`, `ComicHistoryEntry{sourceKey, comicId, title, cover, chapterId, chapterTitle, page, readAt}`, `comicFavoritesProvider`/`comicHistoryProvider`, `comicSourcesProvider`/`comicExploreProvider`/`comicSearchProvider`/`comicDetailProvider`/`comicEpProvider`, `ComicImageProvider.resolve`, `ComicHomePage`/`ComicSourcePage`/`ComicSearchPage`/`ComicDetailPage` — used consistently across tasks.
