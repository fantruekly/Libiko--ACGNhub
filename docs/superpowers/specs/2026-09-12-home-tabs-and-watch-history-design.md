# Home Tabs and Watch History — Design

> Date: 2026-09-12
> Status: Approved (design)
> Scope: Home-page tab rework + a local watch-history tab. The 追番 button and account sync are a separate spec.

## 1. Goal

1. Replace the home page's pill buttons with the detail page's `TabBar` + `TabBarView` paging style.
2. Add a 4th tab, 历史记录 (watch history): one entry per work, newest first, same card grid as the other tabs, with a `看到 第N集` line under the cover.
3. Record history automatically when an episode starts playing, and offer a 清空历史 action.

## 2. Background

- The home page (`lib/modules/anime/anime_home.dart`) currently renders three pill buttons above a `PageView` of `_FeedView`s (本季新番 / 热门推荐 / 今日放送).
- The detail page (`lib/modules/anime/anime_detail_page.dart:133-147`) already uses the target style: `TabBar(labelColor #007AFF, unselectedLabelColor #8E8E93, indicatorColor #007AFF, dividerColor #E5E5EA)` inside a `DefaultTabController` + `TabBarView`.
- Local persistence precedent: `AppDatabase` wraps `SharedPreferences`, and `FavoriteManager` (`lib/core/services/favorite_manager.dart`) stores a JSON list under one key. History follows the same pattern.
- `Work` (`lib/core/models/work.dart`) already serializes to/from JSON and carries `id`, `title`, `coverUrl`, `extra`.

## 3. Data layer

**`lib/core/models/watch_record.dart`** (new)

```dart
class WatchRecord {
  final Work work;
  final String episodeTitle;
  final int episodeIndex;
  final DateTime watchedAt;
  const WatchRecord({required this.work, required this.episodeTitle,
                     required this.episodeIndex, required this.watchedAt});
  factory WatchRecord.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}
```

**`lib/core/services/watch_history.dart`** (new)

`WatchHistoryManager`:
- `List<WatchRecord> all()` — records sorted by `watchedAt` descending.
- `Future<void> record(Work work, VideoEpisode episode)` — upsert by `work.id`: replace any existing record for that work, set the new episode + timestamp, and put it first.
- `Future<void> clear()`.
- Storage: `AppDatabase` under key `watch_history`, a JSON list of `WatchRecord.toJson()` (mirrors `FavoriteManager`). Malformed entries are skipped.
- `@visibleForTesting static List<WatchRecord> upsert(List<WatchRecord> current, WatchRecord record)` — pure; removes any record with the same `work.id`, then inserts `record` at index 0.

**`watchHistoryProvider`** (new, in `watch_history.dart`)

`NotifierProvider<WatchHistoryNotifier, List<WatchRecord>>`:
- `build()` returns `WatchHistoryManager().all()`.
- `void record(Work work, VideoEpisode episode)` calls the manager then `state = ...all()`.
- `void clear()` calls the manager then `state = const []`.

## 4. UI layer

**`lib/modules/anime/anime_home.dart`** (modified)

Replace the pill `Row` + `PageView` with:

```dart
DefaultTabController(
  length: 4,
  child: Column(children: [
    const TabBar(
      labelColor: Color(0xFF007AFF),
      unselectedLabelColor: Color(0xFF8E8E93),
      indicatorColor: Color(0xFF007AFF),
      dividerColor: Color(0xFFE5E5EA),
      tabs: [Tab(text: '本季新番'), Tab(text: '热门推荐'),
              Tab(text: '今日放送'), Tab(text: '历史记录')],
    ),
    Expanded(child: TabBarView(children: [
      _FeedView(feed: AnimeFeed.season),
      _FeedView(feed: AnimeFeed.trending),
      _FeedView(feed: AnimeFeed.today),
      const AnimeHistoryView(),
    ])),
  ]),
)
```

`_FeedView` and `AnimeFeed` are unchanged (the existing `AutomaticKeepAliveClientMixin` keeps visited tabs alive). The `AnimeHomePage` widget no longer needs its own `PageController`/`_index`/`_pill`/`_goTo`.

**`lib/modules/anime/anime_history.dart`** (new)

`AnimeHistoryView` (`ConsumerWidget`):
- Watches `watchHistoryProvider`.
- Header row: title `历史记录` + a `清空历史` `TextButton` (disabled when empty; shows a confirm dialog, then calls `clear()`).
- Body: `GridView` with the same delegate as `_FeedView` (`crossAxisCount: 5`, `mainAxisSpacing`/`crossAxisSpacing` 16, `childAspectRatio: 0.66`, padding `fromLTRB(16, 8, 16, 24)`) rendering `WorkCard(work: r.work, subtitle: '看到 ${r.episodeTitle}', onTap: → AnimeDetailPage(work: r.work))`.
- Empty state: the existing `EmptyState` with `Icons.history_rounded` and `还没有观看记录`.

**`lib/core/widgets/work_card.dart`** (modified)

Add an optional `final String? subtitle;` constructor param, rendered under the title (fontSize 12, muted `#8E8E93`, single line, ellipsis). The existing `Expanded` cover absorbs the extra height, so the grid's aspect ratio is unchanged.

**`lib/modules/anime/video_player_page.dart`** (modified)

- Change to a `ConsumerStatefulWidget`.
- Replace the `title` parameter with `final Work work;` (the header uses `widget.work.title`).
- After a successful resolve and `await _player.open(Media(url))` in `_playIndex`, call `ref.read(watchHistoryProvider.notifier).record(widget.work, widget.episodes[i])`.

**`lib/modules/anime/anime_detail_page.dart`** (modified)

`_playEpisode` passes `work: _work` instead of `title: _work.title`.

## 5. Data flow

Pick an episode → `StreamResolver` resolves → `player.open` → `record(work, episode)` → manager upserts + persists → `watchHistoryProvider` state updates → the history tab (if built) rebuilds.

## 6. Error Handling

- Empty history → `EmptyState` (`还没有观看记录`).
- A malformed stored entry is skipped rather than failing the whole list (same as `FavoriteManager`).
- A failed stream resolve does not record anything.

## 7. Testing

- `test/core/models/watch_record_test.dart`: `toJson`/`fromJson` round-trip (including `Work.extra`).
- `test/core/services/watch_history_test.dart`: `WatchHistoryManager.upsert` — dedupes by `work.id`, keeps the newest episode, puts the record first, and preserves other works' order.
- Widget tests are not added for the tabs; the tab layout and the history grid are verified in-app.
- Re-run `flutter analyze lib test`, `flutter test`, `flutter build windows --debug`.

## 8. Files

**New**
- `lib/core/models/watch_record.dart`
- `lib/core/services/watch_history.dart`
- `lib/modules/anime/anime_history.dart`
- `test/core/models/watch_record_test.dart`
- `test/core/services/watch_history_test.dart`

**Modified**
- `lib/modules/anime/anime_home.dart`
- `lib/modules/anime/video_player_page.dart`
- `lib/modules/anime/anime_detail_page.dart`
- `lib/core/widgets/work_card.dart`

## 9. Out of Scope

- The 追番 button, account login and syncing (separate spec).
- Per-episode history entries; deleting a single history entry.
- Recording playback position within an episode.
