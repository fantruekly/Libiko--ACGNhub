# Home Tabs and Watch History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the home page's pill buttons with the detail page's `TabBar`/`TabBarView` paging style, add a 4th 历史记录 tab backed by a local watch history that records automatically when an episode plays.

**Architecture:** A `WatchRecord` model + `WatchHistoryManager` (JSON list in `SharedPreferences` via the existing `AppDatabase`, deduped by `work.id`) feed a Riverpod `NotifierProvider`. `VideoPlayerPage` becomes a `ConsumerStatefulWidget` that takes the `Work` and records after a successful play. The home page uses `DefaultTabController` with 4 tabs; the 4th renders a new `AnimeHistoryView` grid.

**Tech Stack:** Flutter 3.35, Dart 3, Riverpod 2 (`NotifierProvider`), `shared_preferences` via `AppDatabase`.

## Global Constraints

- Windows only; package name `acgnhub`.
- Persistence goes through `AppDatabase` (initialized in `main()`), same pattern as `FavoriteManager` — a JSON list under one key.
- Tab styling must match the detail page exactly: `labelColor #007AFF`, `unselectedLabelColor #8E8E93`, `indicatorColor #007AFF`, `dividerColor #E5E5EA`.
- History is deduped by `work.id`, newest first; the card subtitle is `看到 <episode title>`.
- Design tokens: accent `#007AFF`, muted `#8E8E93`, border `#E5E5EA`, fg `#1C1C1E`.
- `_FeedView` and `AnimeFeed` are unchanged; the feed grid stays `crossAxisCount: 5`, spacing 16, `childAspectRatio: 0.66`.
- Commit after every task.
- Flutter commands run with `$env:Path = "C:\flutter\bin;$env:Path";` prefixed.

---

### Task 1: `WatchRecord` model

**Files:**
- Create: `lib/core/models/watch_record.dart`
- Test: `test/core/models/watch_record_test.dart`

**Interfaces:**
- Consumes: `Work` (existing).
- Produces: `class WatchRecord { final Work work; final String episodeTitle; final int episodeIndex; final DateTime watchedAt; }` with `WatchRecord.fromJson(Map<String, dynamic>)` and `Map<String, dynamic> toJson()`.

- [ ] **Step 1: Write the failing test**

Create `test/core/models/watch_record_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/models/watch_record.dart';
import 'package:acgnhub/core/models/work.dart';

void main() {
  const work = Work(
    id: 'bangumi_123',
    sourceId: 'bangumi',
    sourceName: 'Bangumi',
    type: WorkType.anime,
    title: '葬送的芙莉莲',
    coverUrl: 'https://img/x.jpg',
    summary: 'A summary.',
    tags: ['奇幻'],
    extra: {'bangumiId': 123},
  );

  test('toJson/fromJson round-trips the record and its Work', () {
    final record = WatchRecord(
      work: work,
      episodeTitle: '第3集',
      episodeIndex: 2,
      watchedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    );

    final restored = WatchRecord.fromJson(record.toJson());

    expect(restored.work.id, 'bangumi_123');
    expect(restored.work.title, '葬送的芙莉莲');
    expect(restored.work.coverUrl, 'https://img/x.jpg');
    expect(restored.work.tags, ['奇幻']);
    expect(restored.work.bangumiId, 123);
    expect(restored.episodeTitle, '第3集');
    expect(restored.episodeIndex, 2);
    expect(restored.watchedAt, DateTime.fromMillisecondsSinceEpoch(1700000000000));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/models/watch_record_test.dart`
Expected: FAIL — `watch_record.dart` not found.

- [ ] **Step 3: Create `lib/core/models/watch_record.dart`**

```dart
import 'work.dart';

class WatchRecord {
  final Work work;
  final String episodeTitle;
  final int episodeIndex;
  final DateTime watchedAt;

  const WatchRecord({
    required this.work,
    required this.episodeTitle,
    required this.episodeIndex,
    required this.watchedAt,
  });

  factory WatchRecord.fromJson(Map<String, dynamic> json) => WatchRecord(
        work: Work.fromJson(json['work'] as Map<String, dynamic>),
        episodeTitle: json['episodeTitle'] as String? ?? '',
        episodeIndex: json['episodeIndex'] as int? ?? 0,
        watchedAt:
            DateTime.fromMillisecondsSinceEpoch(json['watchedAt'] as int? ?? 0),
      );

  Map<String, dynamic> toJson() => {
        'work': work.toJson(),
        'episodeTitle': episodeTitle,
        'episodeIndex': episodeIndex,
        'watchedAt': watchedAt.millisecondsSinceEpoch,
      };
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/models/watch_record_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add lib/core/models/watch_record.dart test/core/models/watch_record_test.dart
git commit -m "feat(history): add WatchRecord model"
```

---

### Task 2: `WatchHistoryManager` + `watchHistoryProvider`

**Files:**
- Create: `lib/core/services/watch_history.dart`
- Test: `test/core/services/watch_history_test.dart`

**Interfaces:**
- Consumes: `WatchRecord` (Task 1); `Work`; `VideoEpisode` (`lib/core/video/video_source.dart`); `AppDatabase`.
- Produces: `class WatchHistoryManager { List<WatchRecord> all(); Future<void> record(Work, VideoEpisode); Future<void> clear(); @visibleForTesting static List<WatchRecord> upsert(List<WatchRecord> current, WatchRecord record); @visibleForTesting static List<WatchRecord> sortDescending(List<WatchRecord> records); }`; `class WatchHistoryNotifier extends Notifier<List<WatchRecord>>` with `record`/`clear`; `final watchHistoryProvider = NotifierProvider<WatchHistoryNotifier, List<WatchRecord>>(...)`.

- [ ] **Step 1: Write the failing test**

Create `test/core/services/watch_history_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/models/watch_record.dart';
import 'package:acgnhub/core/models/work.dart';
import 'package:acgnhub/core/services/watch_history.dart';

Work _work(String id) => Work(
      id: id,
      sourceId: 'bangumi',
      sourceName: 'Bangumi',
      type: WorkType.anime,
      title: 'Title $id',
    );

WatchRecord _record(String id, String ep, int ms) => WatchRecord(
      work: _work(id),
      episodeTitle: ep,
      episodeIndex: 0,
      watchedAt: DateTime.fromMillisecondsSinceEpoch(ms),
    );

void main() {
  test('upsert dedupes by work id and puts the new record first', () {
    final existing = [_record('a', '第1集', 1000), _record('b', '第1集', 2000)];
    final result = WatchHistoryManager.upsert(existing, _record('a', '第5集', 3000));

    expect(result, hasLength(2));
    expect(result.first.work.id, 'a');
    expect(result.first.episodeTitle, '第5集');
    expect(result.last.work.id, 'b');
  });

  test('upsert inserts a new work at the front', () {
    final result = WatchHistoryManager.upsert([_record('a', '第1集', 1000)], _record('c', '第2集', 2000));
    expect(result.map((r) => r.work.id).toList(), ['c', 'a']);
  });

  test('sortDescending orders by watchedAt newest first', () {
    final sorted = WatchHistoryManager.sortDescending(
        [_record('a', 'e', 1000), _record('b', 'e', 3000), _record('c', 'e', 2000)]);
    expect(sorted.map((r) => r.work.id).toList(), ['b', 'c', 'a']);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/services/watch_history_test.dart`
Expected: FAIL — `watch_history.dart` not found.

- [ ] **Step 3: Create `lib/core/services/watch_history.dart`**

```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/watch_record.dart';
import '../models/work.dart';
import '../storage/database.dart';
import '../video/video_source.dart';

class WatchHistoryManager {
  static const _key = 'watch_history';

  List<WatchRecord> all() {
    final jsonList = AppDatabase().getStringList(_key);
    final records = <WatchRecord>[];
    for (final raw in jsonList) {
      try {
        records.add(
            WatchRecord.fromJson(json.decode(raw) as Map<String, dynamic>));
      } catch (_) {
        // Skip a malformed entry rather than failing the whole list.
      }
    }
    return sortDescending(records);
  }

  Future<void> record(Work work, VideoEpisode episode) async {
    final record = WatchRecord(
      work: work,
      episodeTitle: episode.title,
      episodeIndex: episode.index,
      watchedAt: DateTime.now(),
    );
    await _save(upsert(all(), record));
  }

  Future<void> clear() => AppDatabase().remove(_key);

  Future<void> _save(List<WatchRecord> records) async {
    final jsonList = records.map((r) => json.encode(r.toJson())).toList();
    await AppDatabase().setStringList(_key, jsonList);
  }

  @visibleForTesting
  static List<WatchRecord> upsert(
      List<WatchRecord> current, WatchRecord record) {
    final out = current.where((r) => r.work.id != record.work.id).toList();
    out.insert(0, record);
    return out;
  }

  @visibleForTesting
  static List<WatchRecord> sortDescending(List<WatchRecord> records) {
    final out = [...records];
    out.sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
    return out;
  }
}

class WatchHistoryNotifier extends Notifier<List<WatchRecord>> {
  final _manager = WatchHistoryManager();

  @override
  List<WatchRecord> build() => _manager.all();

  Future<void> record(Work work, VideoEpisode episode) async {
    await _manager.record(work, episode);
    state = _manager.all();
  }

  Future<void> clear() async {
    await _manager.clear();
    state = const [];
  }
}

final watchHistoryProvider =
    NotifierProvider<WatchHistoryNotifier, List<WatchRecord>>(
        WatchHistoryNotifier.new);
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/services/watch_history_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Analyze**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/core/services/watch_history.dart test/core/services/watch_history_test.dart
git commit -m "feat(history): add WatchHistoryManager and watchHistoryProvider"
```

---

### Task 3: Record history when an episode plays

**Files:**
- Modify: `lib/core/widgets/work_card.dart`
- Modify: `lib/modules/anime/video_player_page.dart`
- Modify: `lib/modules/anime/anime_detail_page.dart`

**Interfaces:**
- Consumes: `watchHistoryProvider` (Task 2); `Work`; `VideoEpisode`.
- Produces: `WorkCard({required Work work, VoidCallback? onTap, String? subtitle})`; `VideoPlayerPage({required Work work, required List<VideoEpisode> episodes, required int initialIndex})`.

- [ ] **Step 1: Add the `subtitle` parameter to `WorkCard`**

In `lib/core/widgets/work_card.dart`, change the fields and constructor:

```dart
  final Work work;
  final VoidCallback? onTap;
  final String? subtitle;

  const WorkCard({super.key, required this.work, this.onTap, this.subtitle});
```

and add, immediately after the title `Text(...)` widget (before the closing `]` of the `Column`'s children):

```dart
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
            ),
          ],
```

- [ ] **Step 2: Make `VideoPlayerPage` record history**

In `lib/modules/anime/video_player_page.dart`:

Add imports:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/work.dart';
import '../../core/services/watch_history.dart';
```

Replace the widget declaration and state class header:

```dart
class VideoPlayerPage extends ConsumerStatefulWidget {
  final Work work;
  final List<VideoEpisode> episodes;
  final int initialIndex;

  const VideoPlayerPage({
    super.key,
    required this.work,
    required this.episodes,
    required this.initialIndex,
  });

  @override
  ConsumerState<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends ConsumerState<VideoPlayerPage> {
```

Replace the single remaining `widget.title` use (in the top button bar's `Text`) with `widget.work.title`.

In `_playIndex`, after `await _player.open(Media(url));` add:

```dart
    ref
        .read(watchHistoryProvider.notifier)
        .record(widget.work, widget.episodes[i]);
```

- [ ] **Step 3: Pass the `Work` from the detail page**

In `lib/modules/anime/anime_detail_page.dart`, in `_playEpisode`, change the `VideoPlayerPage` construction to:

```dart
        builder: (_) => VideoPlayerPage(
          work: _work,
          episodes: _episodes ?? const [],
          initialIndex: ep.index,
        ),
```

- [ ] **Step 4: Verify it compiles**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib`
Expected: `No issues found!`

- [ ] **Step 5: Run the full suite**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/core/widgets/work_card.dart lib/modules/anime/video_player_page.dart lib/modules/anime/anime_detail_page.dart
git commit -m "feat(history): record a watch record when an episode starts playing"
```

---

### Task 4: Home tabs + history view

**Files:**
- Modify: `lib/modules/anime/anime_home.dart`
- Create: `lib/modules/anime/anime_history.dart`

**Interfaces:**
- Consumes: `watchHistoryProvider` (Task 2); `WorkCard.subtitle` (Task 3); `AnimeDetailPage`, `smoothRoute`, `EmptyState`.
- Produces: `class AnimeHistoryView extends ConsumerWidget`; `AnimeHomePage` becomes a `ConsumerWidget` with 4 tabs.

- [ ] **Step 1: Replace the `AnimeHomePage` classes in `lib/modules/anime/anime_home.dart`**

Delete everything from `class AnimeHomePage extends ConsumerStatefulWidget {` (line 12) through the closing brace of `_AnimeHomePageState` (line 92) — i.e. the pill row, `_controller`, `_index`, `_goTo`, `_pill` — and replace it with:

```dart
class AnimeHomePage extends ConsumerWidget {
  const AnimeHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const DefaultTabController(
      length: 4,
      child: Column(
        children: [
          TabBar(
            labelColor: Color(0xFF007AFF),
            unselectedLabelColor: Color(0xFF8E8E93),
            indicatorColor: Color(0xFF007AFF),
            dividerColor: Color(0xFFE5E5EA),
            tabs: [
              Tab(text: '本季新番'),
              Tab(text: '热门推荐'),
              Tab(text: '今日放送'),
              Tab(text: '历史记录'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _FeedView(feed: AnimeFeed.season),
                _FeedView(feed: AnimeFeed.trending),
                _FeedView(feed: AnimeFeed.today),
                AnimeHistoryView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

Add the import:

```dart
import 'anime_history.dart';
```

Leave `_FeedView` and `_FeedViewState` untouched.

- [ ] **Step 2: Create `lib/modules/anime/anime_history.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/watch_history.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/smooth_route.dart';
import '../../core/widgets/work_card.dart';
import 'anime_detail_page.dart';

class AnimeHistoryView extends ConsumerWidget {
  const AnimeHistoryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(watchHistoryProvider);
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Text(
                '历史记录',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                    height: 1.4),
              ),
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
                  icon: Icons.history_rounded, message: '还没有观看记录')
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.66,
                  ),
                  itemCount: records.length,
                  itemBuilder: (_, i) {
                    final record = records[i];
                    return WorkCard(
                      work: record.work,
                      subtitle: '看到 ${record.episodeTitle}',
                      onTap: () => Navigator.push(
                          context,
                          smoothRoute(
                              AnimeDetailPage(work: record.work))),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空历史记录？'),
        content: const Text('将删除全部观看记录，且不可恢复。'),
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
    if (confirmed == true) {
      await ref.read(watchHistoryProvider.notifier).clear();
    }
  }
}
```

- [ ] **Step 3: Verify it compiles**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib`
Expected: `No issues found!`

- [ ] **Step 4: Build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug`
Expected: `Built build\windows\x64\runner\Debug\acgnhub.exe`

- [ ] **Step 5: Commit**

```bash
git add lib/modules/anime/anime_home.dart lib/modules/anime/anime_history.dart
git commit -m "feat(home): tab-bar navigation with a watch-history tab"
```

---

### Task 5: Final verification

**Files:** none (verification only); fixes may touch any file above.

- [ ] **Step 1: Analyze and test**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: all tests pass.

- [ ] **Step 2: Build and smoke-run**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug`
Then launch `build\windows\x64\runner\Debug\acgnhub.exe`.
Expected: the home page shows 本季新番 / 热门推荐 / 今日放送 / 历史记录 as underlined tabs (no pills); tapping or swiping pages between them; 历史记录 starts empty; playing an episode from a detail page adds a card with `看到 第N集`; 清空历史 empties it.

- [ ] **Step 3: Record the manual result**

Write the observed outcome (including any tab/history issue) into the task report.

---

## Self-Review

- **Spec coverage:** §3 `WatchRecord` → Task 1; §3 `WatchHistoryManager` + provider → Task 2; §4 `WorkCard.subtitle`, `VideoPlayerPage`, detail-page wiring → Task 3; §4 home tabs + `AnimeHistoryView` → Task 4; §6 error handling → Tasks 2 and 4; §7 tests → Tasks 1–2, 5. All spec sections covered.
- **Placeholders:** none — every step has concrete code or an exact command.
- **Type consistency:** `WatchRecord{work, episodeTitle, episodeIndex, watchedAt}`; `WatchHistoryManager.all/record/clear/upsert/sortDescending`; `watchHistoryProvider` (`NotifierProvider<WatchHistoryNotifier, List<WatchRecord>>`); `WorkCard({work, onTap, subtitle})`; `VideoPlayerPage({work, episodes, initialIndex})`; `AnimeHistoryView` — used consistently across tasks.
