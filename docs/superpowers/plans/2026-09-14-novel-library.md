# 轻小说阅读进度与收藏 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 给轻小说模块加阅读进度（章节级）与收藏，并把首页改造成「探索 / 收藏 / 历史」三个 Tab（镜像漫画首页）。

**Architecture:** 新增 `lib/core/novel/novel_history.dart` 与 `novel_favorite.dart`（镜像 `comic_history.dart`/`comic_favorite.dart`：SharedPreferences + Riverpod Notifier）。`NovelHomePage` 改为 `DefaultTabController` 三 Tab；阅读器在章节加载成功时记录进度；详情页加收藏按钮与「继续阅读」。

**Tech Stack:** Flutter/Dart 3.6、Riverpod、SharedPreferences（`AppDatabase`）、`cached_network_image`。

## Global Constraints

- 运行环境：Flutter 在 `C:\flutter\bin`；命令前缀 `$env:Path = "C:\flutter\bin;$env:Path";`；工作目录 `D:\ACGNhub`。
- 每个任务结束必须：`flutter analyze lib test` 无问题 + `flutter test` 全绿。
- 每个任务结束提交并推送：`git add <精确文件>` → `git commit` → `git push origin dev`。
- 不新增依赖；不改 `pubspec.yaml`。
- 不加代码注释（`// Skip a malformed entry.` 这类与漫画现有风格一致的注释除外）。
- 中文 UI 文案。
- 存储 key：历史 `novel_history`，收藏 `novel_favorites`。数据结构与排序、串行写队列、`@visibleForTesting upsert` 均镜像漫画实现。
- 封面/图片一律带 `novelImageHeaders`（linovelib 防盗链需要）。
- 详情页 push 用 `noTransitionRoute`，阅读器 push 用 `smoothRoute`。

---

### Task 1: 数据层（NovelHistoryEntry + NovelFavorite）

**Files:**
- Create: `lib/core/novel/novel_history.dart`
- Create: `lib/core/novel/novel_favorite.dart`
- Test: `test/core/novel/novel_history_test.dart`
- Test: `test/core/novel/novel_favorite_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`（`lib/core/storage/database.dart`）。
- Produces:
  - `class NovelHistoryEntry { final String sourceKey; final String novelId; final String title; final String? cover; final String chapterId; final String chapterTitle; final DateTime updatedAt; }`（含 `fromJson`/`toJson`）
  - `class NovelHistoryManager { List<NovelHistoryEntry> all(); NovelHistoryEntry? forNovel(String sourceKey, String novelId); Future<void> record(NovelHistoryEntry entry); Future<void> clear(); static List<NovelHistoryEntry> upsert(List<NovelHistoryEntry> current, NovelHistoryEntry entry); }`
  - `class NovelHistoryNotifier extends Notifier<List<NovelHistoryEntry>>`（`record`/`clear`）+ `final novelHistoryProvider`
  - `class NovelFavorite { final String sourceKey; final String novelId; final String title; final String? cover; final DateTime addedAt; }`（含 `fromJson`/`toJson`）
  - `class NovelFavoriteManager { List<NovelFavorite> all(); bool isFavorite(String sourceKey, String novelId); Future<void> toggle(NovelFavorite favorite); Future<void> remove(String sourceKey, String novelId); Future<void> clear(); static List<NovelFavorite> upsert(List<NovelFavorite> current, NovelFavorite favorite); }`
  - `class NovelFavoritesNotifier extends Notifier<List<NovelFavorite>>`（`toggle`/`clear`）+ `final novelFavoritesProvider`

- [ ] **Step 1: 写 `novel_history.dart` 的失败测试**

创建 `test/core/novel/novel_history_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acgnhub/core/novel/novel_history.dart';
import 'package:acgnhub/core/storage/database.dart';

NovelHistoryEntry _entry(String novelId, String chapter, int ms) =>
    NovelHistoryEntry(
      sourceKey: 's1',
      novelId: novelId,
      title: 'Title $novelId',
      cover: 'c.jpg',
      chapterId: chapter,
      chapterTitle: '第$chapter章',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(ms),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('upsert dedupes by novel and keeps the newest first', () {
    final result = NovelHistoryManager.upsert(
        [_entry('a', '1', 100), _entry('b', '1', 200)], _entry('a', '5', 300));
    expect(result, hasLength(2));
    expect(result.first.novelId, 'a');
    expect(result.first.chapterId, '5');
    expect(result.last.novelId, 'b');
  });

  test('record stores and forNovel finds the entry', () async {
    await AppDatabase.init();
    final manager = NovelHistoryManager();
    await manager.record(_entry('a', '2', 100));
    expect(manager.all(), hasLength(1));
    expect(manager.forNovel('s1', 'a')!.chapterId, '2');
    expect(manager.forNovel('s1', 'nope'), isNull);
  });

  test('clear empties the history', () async {
    await AppDatabase.init();
    final manager = NovelHistoryManager();
    await manager.record(_entry('a', '1', 100));
    await manager.clear();
    expect(manager.all(), isEmpty);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/novel_history_test.dart`
Expected: 编译失败（`novel_history.dart` 不存在）。

- [ ] **Step 3: 实现 `lib/core/novel/novel_history.dart`**

```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/database.dart';

class NovelHistoryEntry {
  final String sourceKey;
  final String novelId;
  final String title;
  final String? cover;
  final String chapterId;
  final String chapterTitle;
  final DateTime updatedAt;

  const NovelHistoryEntry({
    required this.sourceKey,
    required this.novelId,
    required this.title,
    this.cover,
    required this.chapterId,
    required this.chapterTitle,
    required this.updatedAt,
  });

  factory NovelHistoryEntry.fromJson(Map<String, dynamic> json) =>
      NovelHistoryEntry(
        sourceKey: json['sourceKey'] as String? ?? '',
        novelId: json['novelId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        cover: json['cover'] as String?,
        chapterId: json['chapterId'] as String? ?? '',
        chapterTitle: json['chapterTitle'] as String? ?? '',
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int? ?? 0),
      );

  Map<String, dynamic> toJson() => {
        'sourceKey': sourceKey,
        'novelId': novelId,
        'title': title,
        'cover': cover,
        'chapterId': chapterId,
        'chapterTitle': chapterTitle,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };
}

class NovelHistoryManager {
  static const _key = 'novel_history';

  List<NovelHistoryEntry> all() {
    final entries = <NovelHistoryEntry>[];
    for (final raw in AppDatabase().getStringList(_key)) {
      try {
        entries.add(NovelHistoryEntry.fromJson(
            json.decode(raw) as Map<String, dynamic>));
      } catch (_) {
        // Skip a malformed entry.
      }
    }
    entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return entries;
  }

  NovelHistoryEntry? forNovel(String sourceKey, String novelId) {
    for (final entry in all()) {
      if (entry.sourceKey == sourceKey && entry.novelId == novelId) {
        return entry;
      }
    }
    return null;
  }

  Future<void> _pending = Future.value();

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _pending.then((_) => action());
    _pending = next.catchError((_) {});
    return next;
  }

  Future<void> record(NovelHistoryEntry entry) => _enqueue(() async {
        await _save(upsert(all(), entry));
      });

  Future<void> clear() => _enqueue(() => AppDatabase().remove(_key));

  Future<void> _save(List<NovelHistoryEntry> entries) async {
    await AppDatabase().setStringList(
        _key, entries.map((e) => json.encode(e.toJson())).toList());
  }

  @visibleForTesting
  static List<NovelHistoryEntry> upsert(
      List<NovelHistoryEntry> current, NovelHistoryEntry entry) {
    final out = current
        .where((e) =>
            !(e.sourceKey == entry.sourceKey && e.novelId == entry.novelId))
        .toList();
    out.insert(0, entry);
    return out;
  }
}

class NovelHistoryNotifier extends Notifier<List<NovelHistoryEntry>> {
  final _manager = NovelHistoryManager();

  @override
  List<NovelHistoryEntry> build() => _manager.all();

  Future<void> record(NovelHistoryEntry entry) async {
    await _manager.record(entry);
    state = _manager.all();
  }

  Future<void> clear() async {
    await _manager.clear();
    state = const [];
  }
}

final novelHistoryProvider =
    NotifierProvider<NovelHistoryNotifier, List<NovelHistoryEntry>>(
        NovelHistoryNotifier.new);
```

- [ ] **Step 4: 运行测试确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/novel_history_test.dart`
Expected: 全部通过。

- [ ] **Step 5: 写 `novel_favorite.dart` 的失败测试**

创建 `test/core/novel/novel_favorite_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acgnhub/core/novel/novel_favorite.dart';
import 'package:acgnhub/core/storage/database.dart';

NovelFavorite _fav(String novelId, int ms) => NovelFavorite(
      sourceKey: 's1',
      novelId: novelId,
      title: 'Title $novelId',
      cover: 'c.jpg',
      addedAt: DateTime.fromMillisecondsSinceEpoch(ms),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('upsert dedupes by (sourceKey, novelId) and keeps the newest first', () {
    final result = NovelFavoriteManager.upsert(
        [_fav('a', 100), _fav('b', 200)], _fav('a', 300));
    expect(result, hasLength(2));
    expect(result.first.novelId, 'a');
    expect(result.first.addedAt.millisecondsSinceEpoch, 300);
    expect(result.last.novelId, 'b');
  });

  test('toggle adds then removes, and isFavorite reflects it', () async {
    await AppDatabase.init();
    final manager = NovelFavoriteManager();

    await manager.toggle(_fav('a', 100));
    expect(manager.isFavorite('s1', 'a'), isTrue);
    expect(manager.all(), hasLength(1));

    await manager.toggle(_fav('a', 100));
    expect(manager.isFavorite('s1', 'a'), isFalse);
    expect(manager.all(), isEmpty);
  });

  test('all() is newest-first and clear() empties', () async {
    await AppDatabase.init();
    final manager = NovelFavoriteManager();
    await manager.toggle(_fav('a', 100));
    await manager.toggle(_fav('b', 200));
    expect(manager.all().map((f) => f.novelId), ['b', 'a']);
    await manager.clear();
    expect(manager.all(), isEmpty);
  });
}
```

- [ ] **Step 6: 运行测试确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/novel_favorite_test.dart`
Expected: 编译失败（`novel_favorite.dart` 不存在）。

- [ ] **Step 7: 实现 `lib/core/novel/novel_favorite.dart`**

```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/database.dart';

class NovelFavorite {
  final String sourceKey;
  final String novelId;
  final String title;
  final String? cover;
  final DateTime addedAt;

  const NovelFavorite({
    required this.sourceKey,
    required this.novelId,
    required this.title,
    this.cover,
    required this.addedAt,
  });

  factory NovelFavorite.fromJson(Map<String, dynamic> json) => NovelFavorite(
        sourceKey: json['sourceKey'] as String? ?? '',
        novelId: json['novelId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        cover: json['cover'] as String?,
        addedAt:
            DateTime.fromMillisecondsSinceEpoch(json['addedAt'] as int? ?? 0),
      );

  Map<String, dynamic> toJson() => {
        'sourceKey': sourceKey,
        'novelId': novelId,
        'title': title,
        'cover': cover,
        'addedAt': addedAt.millisecondsSinceEpoch,
      };
}

class NovelFavoriteManager {
  static const _key = 'novel_favorites';

  List<NovelFavorite> all() {
    final favorites = <NovelFavorite>[];
    for (final raw in AppDatabase().getStringList(_key)) {
      try {
        favorites.add(
            NovelFavorite.fromJson(json.decode(raw) as Map<String, dynamic>));
      } catch (_) {
        // Skip a malformed entry.
      }
    }
    favorites.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return favorites;
  }

  bool isFavorite(String sourceKey, String novelId) =>
      all().any((f) => f.sourceKey == sourceKey && f.novelId == novelId);

  Future<void> _pending = Future.value();

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _pending.then((_) => action());
    _pending = next.catchError((_) {});
    return next;
  }

  Future<void> toggle(NovelFavorite favorite) => _enqueue(() async {
        final favorites = all();
        final exists = favorites.any((f) =>
            f.sourceKey == favorite.sourceKey && f.novelId == favorite.novelId);
        if (exists) {
          final remaining = favorites
              .where((f) =>
                  !(f.sourceKey == favorite.sourceKey &&
                      f.novelId == favorite.novelId))
              .toList();
          await _save(remaining);
        } else {
          await _save(upsert(favorites, favorite));
        }
      });

  Future<void> remove(String sourceKey, String novelId) => _enqueue(() async {
        final favorites = all()
            .where((f) => !(f.sourceKey == sourceKey && f.novelId == novelId))
            .toList();
        await _save(favorites);
      });

  Future<void> clear() => _enqueue(() => AppDatabase().remove(_key));

  Future<void> _save(List<NovelFavorite> favorites) async {
    await AppDatabase().setStringList(
        _key, favorites.map((f) => json.encode(f.toJson())).toList());
  }

  @visibleForTesting
  static List<NovelFavorite> upsert(
      List<NovelFavorite> current, NovelFavorite favorite) {
    final out = current
        .where((f) =>
            !(f.sourceKey == favorite.sourceKey &&
                f.novelId == favorite.novelId))
        .toList();
    out.insert(0, favorite);
    return out;
  }
}

class NovelFavoritesNotifier extends Notifier<List<NovelFavorite>> {
  final _manager = NovelFavoriteManager();

  @override
  List<NovelFavorite> build() => _manager.all();

  bool isFavorite(String sourceKey, String novelId) =>
      state.any((f) => f.sourceKey == sourceKey && f.novelId == novelId);

  Future<void> toggle(NovelFavorite favorite) async {
    await _manager.toggle(favorite);
    state = _manager.all();
  }

  Future<void> clear() async {
    await _manager.clear();
    state = const [];
  }
}

final novelFavoritesProvider =
    NotifierProvider<NovelFavoritesNotifier, List<NovelFavorite>>(
        NovelFavoritesNotifier.new);
```

- [ ] **Step 8: 运行测试与静态检查**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/novel_history_test.dart test/core/novel/novel_favorite_test.dart`
Expected: 全部通过。

- [ ] **Step 9: 提交**

```bash
git add lib/core/novel/novel_history.dart lib/core/novel/novel_favorite.dart test/core/novel/novel_history_test.dart test/core/novel/novel_favorite_test.dart
git commit -m "feat(novel): add reading history and favorites storage"
git push origin dev
```

---

### Task 2: 首页「探索 / 收藏 / 历史」Tab

**Files:**
- Modify: `lib/modules/novel/novel_home.dart`
- Test: `test/modules/novel/novel_home_tabs_test.dart`
- Test: `test/modules/novel/novel_home_pager_test.dart`

**Interfaces:**
- Consumes: `novelHistoryProvider`/`NovelHistoryEntry`、`novelFavoritesProvider`/`NovelFavorite`（Task 1）；`NovelReaderPage`、`NovelDetailPage`、`novelImageHeaders`。
- Produces: `NovelHomePage` 现在渲染 3 个 Tab（探索/收藏/历史）；`NovelCard` 保持不变。

- [ ] **Step 1: 写新 Tab 的失败测试**

创建 `test/modules/novel/novel_home_tabs_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acgnhub/core/novel/models.dart';
import 'package:acgnhub/core/novel/novel_favorite.dart';
import 'package:acgnhub/core/novel/novel_history.dart';
import 'package:acgnhub/core/novel/novel_source.dart';
import 'package:acgnhub/core/storage/database.dart';
import 'package:acgnhub/modules/novel/novel_home.dart';
import 'package:acgnhub/modules/novel/novel_providers.dart';

class _FakeSource extends NovelSource {
  @override
  String get id => 'linovelib';
  @override
  String get name => 'Fake';
  @override
  String get baseUrl => 'https://fake';
  @override
  List<NovelBrowseGroup> get browseGroups => const [];
  @override
  Future<NovelHome> home() async => const NovelHome(sections: []);
  @override
  Future<NovelList> browse(String optionKey, {int page = 1}) async =>
      NovelList(items: const [], page: page, hasMore: false);
  @override
  Future<List<Novel>> search(String keyword, {int page = 1}) async => const [];
  @override
  Future<NovelDetail> detail(String id) async =>
      const NovelDetail(novel: Novel(id: 'x', title: 'x'), volumes: []);
  @override
  Future<NovelChapter> chapter(String novelId, String chapterId) async =>
      const NovelChapter(title: 't', blocks: []);
}

class _FavNotifier extends NovelFavoritesNotifier {
  @override
  List<NovelFavorite> build() => [
        NovelFavorite(
          sourceKey: 'linovelib',
          novelId: '1',
          title: '收藏的书',
          addedAt: DateTime.fromMillisecondsSinceEpoch(1),
        ),
      ];
}

class _HistNotifier extends NovelHistoryNotifier {
  @override
  List<NovelHistoryEntry> build() => [
        NovelHistoryEntry(
          sourceKey: 'linovelib',
          novelId: '1',
          title: '收藏的书',
          chapterId: 'c1',
          chapterTitle: '第一章',
          updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
        ),
      ];
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppDatabase.init();
  });

  testWidgets('收藏 and 历史 tabs render their data', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        novelSourceManagerProvider
            .overrideWithValue(NovelSourceManager(sources: [_FakeSource()])),
        novelFavoritesProvider.overrideWith(_FavNotifier.new),
        novelHistoryProvider.overrideWith(_HistNotifier.new),
      ],
      child: const MaterialApp(home: Scaffold(body: NovelHomePage())),
    ));
    await tester.pump();

    await tester.tap(find.text('收藏'));
    await tester.pumpAndSettle();
    expect(find.text('收藏的书'), findsOneWidget);
    expect(find.text('还没有收藏'), findsNothing);

    await tester.tap(find.text('历史'));
    await tester.pumpAndSettle();
    expect(find.text('读到 第一章'), findsOneWidget);
    expect(find.text('清空历史'), findsOneWidget);
  });

  testWidgets('收藏 and 历史 tabs show empty states', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        novelSourceManagerProvider
            .overrideWithValue(NovelSourceManager(sources: [_FakeSource()])),
      ],
      child: const MaterialApp(home: Scaffold(body: NovelHomePage())),
    ));
    await tester.pump();

    await tester.tap(find.text('收藏'));
    await tester.pumpAndSettle();
    expect(find.text('还没有收藏'), findsOneWidget);

    await tester.tap(find.text('历史'));
    await tester.pumpAndSettle();
    expect(find.text('还没有阅读记录'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_home_tabs_test.dart`
Expected: 失败（找不到「收藏」Tab / 空态文案）。

- [ ] **Step 3: 重写 `lib/modules/novel/novel_home.dart`**

用下面完整内容替换（`NovelCard` 与原探索逻辑保留，新增 Tab 外壳、`_FavoritesTab`、`_HistoryTab` 及辅助函数）：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/novel/linovelib_source.dart';
import '../../core/novel/models.dart';
import '../../core/novel/novel_favorite.dart';
import '../../core/novel/novel_history.dart';
import '../../core/novel/novel_source.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../core/widgets/smooth_route.dart';
import 'novel_detail_page.dart';
import 'novel_providers.dart';
import 'novel_reader_page.dart';

const _accent = Color(0xFF007AFF);
const _muted = Color(0xFF5A5A5F);
const _fg = Color(0xFF1C1C1E);

class NovelCard extends StatelessWidget {
  final Novel novel;
  final VoidCallback? onTap;
  const NovelCard({super.key, required this.novel, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: novel.coverUrl != null && novel.coverUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: novel.coverUrl!,
                      fit: BoxFit.cover,
                      memCacheWidth: 400,
                      httpHeaders: novelImageHeaders,
                      placeholder: (_, __) => _placeholder(),
                      errorWidget: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 38,
            child: Text(
              novel.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500, height: 1.45, color: _fg),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    final hash = novel.title.hashCode.abs();
    const bg = [Color(0xFFF3E5F5), Color(0xFFEDE7F6), Color(0xFFE8EAF6), Color(0xFFE0F2F1)];
    return Container(
      color: bg[hash % bg.length],
      child: Center(
        child: Text(
          novel.title.isEmpty ? '书' : novel.title.characters.first,
          style: TextStyle(
              color: _accent.withValues(alpha: 0.2), fontSize: 28, fontWeight: FontWeight.w400),
        ),
      ),
    );
  }
}

class NovelHomePage extends ConsumerWidget {
  const NovelHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            labelColor: _accent,
            unselectedLabelColor: _muted,
            indicatorColor: _accent,
            dividerColor: Color(0xFFE5E5EA),
            tabs: [Tab(text: '探索'), Tab(text: '收藏'), Tab(text: '历史')],
          ),
          Expanded(
            child: TabBarView(
              children: [_ExploreTab(), _FavoritesTab(), _HistoryTab()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExploreTab extends ConsumerStatefulWidget {
  const _ExploreTab();

  @override
  ConsumerState<_ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends ConsumerState<_ExploreTab>
    with AutomaticKeepAliveClientMixin {
  String _sourceId = 'linovelib';
  int _groupIndex = -1;
  int _optionIndex = 0;
  int _page = 1;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final sources = ref.watch(novelSourcesProvider);
    final source = ref.watch(novelSourceManagerProvider).byId(_sourceId);
    final groups = source?.browseGroups ?? const <NovelBrowseGroup>[];
    return Column(
      children: [
        const SizedBox(height: 8),
        _sourceChips(sources),
        _sectionChips(groups),
        if (_groupIndex >= 0 && _groupIndex < groups.length)
          _optionChips(groups[_groupIndex]),
        Expanded(child: _body(groups)),
      ],
    );
  }

  Widget _sourceChips(List<NovelSource> sources) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final s in sources)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _chip(s.name, s.id == _sourceId, () => setState(() {
                _sourceId = s.id;
                _groupIndex = -1;
                _optionIndex = 0;
                _page = 1;
              })),
            ),
        ],
      ),
    );
  }

  Widget _sectionChips(List<NovelBrowseGroup> groups) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _chip('推荐', _groupIndex < 0, () => setState(() {
              _groupIndex = -1;
              _page = 1;
            })),
          ),
          for (var i = 0; i < groups.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _chip(groups[i].label, _groupIndex == i, () => setState(() {
                _groupIndex = i;
                _optionIndex = 0;
                _page = 1;
              })),
            ),
        ],
      ),
    );
  }

  Widget _optionChips(NovelBrowseGroup group) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (var i = 0; i < group.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _chip(group.options[i].label, _optionIndex == i, () => setState(() {
                _optionIndex = i;
                _page = 1;
              })),
            ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      selectedColor: _accent,
      backgroundColor: const Color(0xFFF2F2F7),
      labelStyle: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w500, color: selected ? Colors.white : _muted),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _body(List<NovelBrowseGroup> groups) {
    if (_groupIndex < 0 || _groupIndex >= groups.length) {
      final async = ref.watch(novelHomeProvider(_sourceId));
      return async.when(
        loading: () => const ShimmerLoader(
            crossAxisCount: 6,
            itemCount: 12,
            aspectRatio: 0.58,
            padding: EdgeInsets.fromLTRB(16, 8, 16, 24)),
        error: (_, __) => EmptyState(
          icon: Icons.cloud_off_rounded,
          message: '加载失败',
          actionLabel: '重试',
          onAction: () => ref.invalidate(novelHomeProvider(_sourceId)),
        ),
        data: (home) => _grid(flattenHome(home)),
      );
    }
    final group = groups[_groupIndex];
    if (group.options.isEmpty) {
      return const EmptyState(icon: Icons.menu_book_rounded, message: '暂无内容');
    }
    final option = group.options[_optionIndex.clamp(0, group.options.length - 1)];
    final async = ref.watch(novelBrowseProvider((_sourceId, option.key, _page)));
    return async.when(
      loading: () => const ShimmerLoader(
          crossAxisCount: 6,
          itemCount: 12,
          aspectRatio: 0.58,
          padding: EdgeInsets.fromLTRB(16, 8, 16, 24)),
      error: (_, __) => EmptyState(
        icon: Icons.cloud_off_rounded,
        message: '加载失败',
        actionLabel: '重试',
        onAction: () =>
            ref.invalidate(novelBrowseProvider((_sourceId, option.key, _page))),
      ),
      data: (list) => Column(
        children: [
          Expanded(child: _grid(list.items)),
          _pager(list.hasMore),
        ],
      ),
    );
  }

  static final _pagerButtonStyle = OutlinedButton.styleFrom(
    minimumSize: const Size(84, 40),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  );

  Widget _pager(bool hasMore) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton(
            style: _pagerButtonStyle,
            onPressed: _page > 1 ? () => setState(() => _page--) : null,
            child: const Text('上一页'),
          ),
          const SizedBox(width: 16),
          Text('第 $_page 页',
              style: const TextStyle(fontSize: 13, color: _muted)),
          const SizedBox(width: 16),
          OutlinedButton(
            style: _pagerButtonStyle,
            onPressed: hasMore ? () => setState(() => _page++) : null,
            child: const Text('下一页'),
          ),
        ],
      ),
    );
  }

  Widget _grid(List<Novel> items) {
    if (items.isEmpty) {
      return const EmptyState(icon: Icons.menu_book_rounded, message: '暂无内容');
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6, mainAxisSpacing: 20, crossAxisSpacing: 16, childAspectRatio: 0.58),
      itemCount: items.length,
      itemBuilder: (_, i) => NovelCard(
        novel: items[i],
        onTap: () => Navigator.push(
          context,
          noTransitionRoute(NovelDetailPage(
            sourceKey: _sourceId,
            novelId: items[i].id,
            title: items[i].title,
            cover: items[i].coverUrl,
          )),
        ),
      ),
    );
  }
}

class _FavoritesTab extends ConsumerWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(novelFavoritesProvider);
    if (favorites.isEmpty) {
      return const EmptyState(
          icon: Icons.favorite_border_rounded, message: '还没有收藏');
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6, mainAxisSpacing: 20, crossAxisSpacing: 16, childAspectRatio: 0.58),
      itemCount: favorites.length,
      itemBuilder: (_, i) => NovelCard(
        novel: Novel(
          id: favorites[i].novelId,
          title: favorites[i].title,
          coverUrl: favorites[i].cover,
        ),
        onTap: () => Navigator.push(
          context,
          noTransitionRoute(NovelDetailPage(
            sourceKey: favorites[i].sourceKey,
            novelId: favorites[i].novelId,
            title: favorites[i].title,
            cover: favorites[i].cover,
          )),
        ),
      ),
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(novelHistoryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              const Text('历史记录',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: _fg,
                      height: 1.4)),
              const Spacer(),
              TextButton(
                onPressed:
                    records.isEmpty ? null : () => _confirmClear(context, ref),
                child: const Text('清空历史'),
              ),
            ],
          ),
        ),
        Expanded(
          child: records.isEmpty
              ? const EmptyState(
                  icon: Icons.history_rounded, message: '还没有阅读记录')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: records.length,
                  itemBuilder: (_, i) => _historyRow(context, records[i]),
                ),
        ),
      ],
    );
  }
}

Widget _historyRow(BuildContext context, NovelHistoryEntry entry) {
  return InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: () => Navigator.push(
      context,
      smoothRoute(NovelReaderPage(
        sourceKey: entry.sourceKey,
        novelId: entry.novelId,
        chapterId: entry.chapterId,
        title: entry.title,
        cover: entry.cover,
      )),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56,
              height: 76,
              child: _cover(entry.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500, color: _fg),
                ),
                const SizedBox(height: 6),
                Text(
                  '读到 ${entry.chapterTitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
                const SizedBox(height: 4),
                Text(
                  _relativeTime(entry.updatedAt),
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _cover(String? url) {
  if (url == null || url.isEmpty) {
    return Container(color: const Color(0xFFE5E5EA));
  }
  return CachedNetworkImage(
    imageUrl: url,
    fit: BoxFit.cover,
    memCacheWidth: 200,
    httpHeaders: novelImageHeaders,
    placeholder: (_, __) => Container(color: const Color(0xFFE5E5EA)),
    errorWidget: (_, __, ___) => Container(color: const Color(0xFFE5E5EA)),
  );
}

Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('清空历史记录？'),
      content: const Text('将删除全部阅读记录，且不可恢复。'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空')),
      ],
    ),
  );
  if (confirmed != true) return;
  await ref.read(novelHistoryProvider.notifier).clear();
}

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
  if (diff.inHours < 24) return '${diff.inHours} 小时前';
  if (diff.inDays < 30) return '${diff.inDays} 天前';
  final local = time.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}
```

- [ ] **Step 4: 让既有 pager 测试初始化数据库**

编辑 `test/modules/novel/novel_home_pager_test.dart`：在 `main()` 开头（`void main() {` 之后）加入 setUp，并补 import：

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acgnhub/core/storage/database.dart';
```

```dart
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppDatabase.init();
  });

  testWidgets('排行 pager lays out under the app outlined-button theme',
      (tester) async {
```

（其余内容不变；该测试仍在默认「探索」Tab 内点击「排行」。）

- [ ] **Step 5: 运行静态检查与测试**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/`
Expected: 全部通过（含新 `novel_home_tabs_test` 与既有 pager 测试）。

- [ ] **Step 6: 提交**

```bash
git add lib/modules/novel/novel_home.dart test/modules/novel/novel_home_tabs_test.dart test/modules/novel/novel_home_pager_test.dart
git commit -m "feat(novel): explore/favorites/history tabs on the home page"
git push origin dev
```

---

### Task 3: 阅读器记录阅读进度

**Files:**
- Modify: `lib/modules/novel/novel_reader_page.dart`
- Test: `test/modules/novel/novel_reader_page_test.dart`

**Interfaces:**
- Consumes: `novelHistoryProvider`/`NovelHistoryEntry`（Task 1）。
- Produces: `NovelReaderPage({..., String? cover})`；章节加载成功时写入一条历史。

- [ ] **Step 1: 写失败测试**

在 `test/modules/novel/novel_reader_page_test.dart` 末尾（`main()` 内最后一个 `testWidgets` 之后）追加：

```dart
  testWidgets('opening a chapter records reading history', (tester) async {
    final container = ProviderContainer(overrides: [
      novelChapterProvider(('linovelib', '1', 'c1')).overrideWith((ref) async =>
          const NovelChapter(title: '第一章', blocks: [NovelText('甲段')])),
      novelDetailProvider(('linovelib', '1')).overrideWith((ref) async =>
          const NovelDetail(novel: Novel(id: '1', title: '书'), volumes: [])),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: NovelReaderPage(
            sourceKey: 'linovelib',
            novelId: '1',
            chapterId: 'c1',
            title: '书',
            cover: 'cover.jpg'),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    final history = container.read(novelHistoryProvider);
    expect(history, hasLength(1));
    expect(history.first.novelId, '1');
    expect(history.first.chapterId, 'c1');
    expect(history.first.chapterTitle, '第一章');
    expect(history.first.cover, 'cover.jpg');
  });
```

- [ ] **Step 2: 运行测试确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_reader_page_test.dart`
Expected: 失败（`NovelReaderPage` 无 `cover` 参数 / 未记录历史）。

- [ ] **Step 3: 实现**

编辑 `lib/modules/novel/novel_reader_page.dart`：

(a) 增加 import：

```dart
import '../../core/novel/novel_history.dart';
```

(b) 给 `NovelReaderPage` 增加可选 `cover` 参数：

```dart
class NovelReaderPage extends ConsumerStatefulWidget {
  final String sourceKey;
  final String novelId;
  final String chapterId;
  final String title;
  final String? cover;
  const NovelReaderPage({
    super.key,
    required this.sourceKey,
    required this.novelId,
    required this.chapterId,
    required this.title,
    this.cover,
  });
```

(c) 在 `build` 中、`final index = chapters.indexWhere((c) => c.id == _chapterId);` 之后加入：

```dart
    ref.listen(
      novelChapterProvider((widget.sourceKey, widget.novelId, _chapterId)),
      (_, next) {
        next.whenData((chapter) {
          ref.read(novelHistoryProvider.notifier).record(NovelHistoryEntry(
                sourceKey: widget.sourceKey,
                novelId: widget.novelId,
                title: widget.title,
                cover: widget.cover,
                chapterId: _chapterId,
                chapterTitle:
                    chapter.title.isEmpty ? '第 $_chapterId 章' : chapter.title,
                updatedAt: DateTime.now(),
              ));
        });
      },
    );
```

- [ ] **Step 4: 运行测试确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_reader_page_test.dart`
Expected: 全部通过。

- [ ] **Step 5: 静态检查与全量测试**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: 全绿。

- [ ] **Step 6: 提交**

```bash
git add lib/modules/novel/novel_reader_page.dart test/modules/novel/novel_reader_page_test.dart
git commit -m "feat(novel): record reading progress from the reader"
git push origin dev
```

---

### Task 4: 详情页收藏按钮与「继续阅读」

**Files:**
- Modify: `lib/modules/novel/novel_detail_page.dart`
- Test: `test/modules/novel/novel_detail_page_test.dart`

**Interfaces:**
- Consumes: `novelFavoritesProvider`/`NovelFavorite`、`novelHistoryProvider`/`NovelHistoryEntry`（Task 1）；`NovelReaderPage({..., String? cover})`（Task 3）。
- Produces: 详情页 `_infoCard` 内含收藏按钮；信息卡与目录之间在有历史时显示「继续阅读」。

- [ ] **Step 1: 更新测试（先加数据库初始化，再写失败用例）**

编辑 `test/modules/novel/novel_detail_page_test.dart`：补 import

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acgnhub/core/novel/novel_history.dart';
import 'package:acgnhub/core/storage/database.dart';
```

在 `void main() {` 之后加入 setUp 与一个测试用 Notifier：

```dart
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppDatabase.init();
  });

  testWidgets('NovelDetailPage renders title, author and chapters',
      (tester) async {
```

在文件顶层（`void main` 之前）加入：

```dart
class _HistNotifier extends NovelHistoryNotifier {
  @override
  List<NovelHistoryEntry> build() => [
        NovelHistoryEntry(
          sourceKey: 'linovelib',
          novelId: '5340',
          title: '不相容的異種族妻子們',
          chapterId: '334356',
          chapterTitle: '第60話',
          updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
        ),
      ];
}
```

在 `main()` 末尾追加新用例：

```dart
  testWidgets('favorite toggles and continue-reading shows with history',
      (tester) async {
    const detail = NovelDetail(
      novel: Novel(id: '5340', title: '不相容的異種族妻子們', author: '이만두'),
      volumes: [],
    );
    final container = ProviderContainer(overrides: [
      novelDetailProvider(('linovelib', '5340'))
          .overrideWith((ref) async => detail),
      novelHistoryProvider.overrideWith(_HistNotifier.new),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: NovelDetailPage(
            sourceKey: 'linovelib', novelId: '5340', title: '不相容的異種族妻子們'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('继续阅读'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);

    await tester.tap(find.text('收藏'));
    await tester.pumpAndSettle();
    expect(find.text('已收藏'), findsOneWidget);
  });
```

- [ ] **Step 2: 运行测试确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_detail_page_test.dart`
Expected: 失败（找不到「继续阅读」/「收藏」）。

- [ ] **Step 3: 实现**

编辑 `lib/modules/novel/novel_detail_page.dart`：

(a) 增加 import：

```dart
import '../../core/novel/novel_favorite.dart';
import '../../core/novel/novel_history.dart';
```

(b) 把 `_content` 替换为：

```dart
  Widget _content(NovelDetail detail) {
    final novel = detail.novel;
    final cover =
        (novel.coverUrl?.isNotEmpty ?? false) ? novel.coverUrl : widget.cover;
    final history = _historyEntry();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _infoCard(novel),
        if (history != null) ...[
          const SizedBox(height: 12),
          _continueReading(history, cover),
        ],
        const SizedBox(height: 16),
        if (detail.volumes.isEmpty)
          const SizedBox(
            height: 200,
            child: EmptyState(
                icon: Icons.menu_book_rounded, message: '暂无章节'),
          )
        else
          for (final vol in detail.volumes) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Text(vol.title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600, color: _fg)),
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final ch in vol.chapters)
                  PillButton(label: ch.title, onTap: () => _openChapter(ch, cover)),
              ],
            ),
          ],
      ],
    );
  }
```

(c) 在 `_infoCard` 的 `Column` 子项末尾（简介 `if (summary.isNotEmpty) ...[...]` 之后）加入收藏按钮：

```dart
          const SizedBox(height: 14),
          _favoriteButton(novel),
```

(d) 新增方法（放在 `_coverPlaceholder` 之前）：

```dart
  Widget _favoriteButton(Novel novel) {
    final favorites = ref.watch(novelFavoritesProvider);
    final isFavorite = favorites.any((f) =>
        f.sourceKey == widget.sourceKey && f.novelId == widget.novelId);
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        backgroundColor:
            isFavorite ? const Color(0xFFE5E5EA) : const Color(0xFF007AFF),
        foregroundColor: isFavorite ? const Color(0xFF5A5A5F) : Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () {
        ref.read(novelFavoritesProvider.notifier).toggle(NovelFavorite(
              sourceKey: widget.sourceKey,
              novelId: widget.novelId,
              title: novel.title,
              cover: novel.coverUrl,
              addedAt: DateTime.now(),
            ));
      },
      icon: Icon(
          isFavorite
              ? Icons.bookmark_added_rounded
              : Icons.bookmark_add_outlined,
          size: 16),
      label: Text(isFavorite ? '已收藏' : '收藏',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }

  Widget _continueReading(NovelHistoryEntry entry, String? cover) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 44),
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () => Navigator.push(
          context,
          smoothRoute(NovelReaderPage(
            sourceKey: widget.sourceKey,
            novelId: widget.novelId,
            chapterId: entry.chapterId,
            title: widget.title,
            cover: cover,
          )),
        ),
        icon: const Icon(Icons.menu_book_rounded, size: 18),
        label: const Text('继续阅读',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }

  NovelHistoryEntry? _historyEntry() {
    final entries = ref.watch(novelHistoryProvider);
    for (final entry in entries) {
      if (entry.sourceKey == widget.sourceKey &&
          entry.novelId == widget.novelId) {
        return entry;
      }
    }
    return null;
  }
```

(e) 把 `_openChapter` 替换为带 `cover` 的版本：

```dart
  void _openChapter(NovelChapterRef chapter, String? cover) {
    Navigator.push(
      context,
      smoothRoute(NovelReaderPage(
        sourceKey: widget.sourceKey,
        novelId: widget.novelId,
        chapterId: chapter.id,
        title: widget.title,
        cover: cover,
      )),
    );
  }
```

- [ ] **Step 4: 运行测试确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_detail_page_test.dart`
Expected: 全部通过。

- [ ] **Step 5: 静态检查与全量测试**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: 全绿。

- [ ] **Step 6: 提交**

```bash
git add lib/modules/novel/novel_detail_page.dart test/modules/novel/novel_detail_page_test.dart
git commit -m "feat(novel): favorite button and continue-reading on detail"
git push origin dev
```

---

## 验证（任务全部完成后）

1. `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` 全绿。
2. 构建并启动应用，切到轻小说模块：
   - 顶部出现「探索 / 收藏 / 历史」三个 Tab。
   - 探索：源/分组/选项/分页照旧；切走再切回保留状态。
   - 打开一本书 → 阅读器读几章 → 返回详情页出现「继续阅读」；点收藏变「已收藏」。
   - 首页「历史」出现该书「读到 <章节名>」；「收藏」出现该书；「清空历史」可用。
   - 历史行点击进入阅读器到该章；收藏卡片点击进入详情。

## 已知取舍

- 历史按书去重，只保留最新一章（与漫画一致），不保留逐章历史。
- 不做账号云同步；不并入漫画/动漫；不记录章内滚动位置。
