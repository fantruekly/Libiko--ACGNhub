# 轻小说阅读进度与收藏设计

日期：2026-09-14
状态：已与用户确认
前置：`docs/superpowers/specs/2026-09-14-novel-module-design.md`、`2026-09-14-novel-detail-design.md`、`2026-09-14-novel-reader-design.md`

## 背景与目标

轻小说模块目前没有阅读进度与收藏：阅读器不记录读到哪里，详情页也没有收藏按钮。本增量做三件事：

1. 记录**阅读进度**（读到哪一章），并在详情页与首页「历史」中续读。
2. 增加**收藏**，并在首页「收藏」中查看。
3. 把轻小说首页改造成「探索 / 收藏 / 历史」三个 Tab（镜像漫画首页 `comic_home.dart` 的做法）。

## 非目标

- 账号云同步（现有 `sync_service` 只同步动漫追番/观看记录，本轮不接入）。
- 把漫画/动漫记录并入同一个书架页。
- 章内滚动位置（本轮只记到章节）。
- 侧边栏改动（「书架」不做成独立侧边栏入口）。

## 数据层（`lib/core/novel/`，镜像 `comic_history.dart` / `comic_favorite.dart`）

### `novel_history.dart`

```dart
class NovelHistoryEntry {
  final String sourceKey;
  final String novelId;
  final String title;
  final String? cover;
  final String chapterId;
  final String chapterTitle;
  final DateTime updatedAt;
}
```

- `fromJson`/`toJson`（`updatedAt` 存 `millisecondsSinceEpoch`）。
- `NovelHistoryManager`：SharedPreferences key `novel_history`（`AppDatabase().getStringList`/`setStringList`）。
  - `all()`：解析、跳过坏数据、按 `updatedAt` 倒序。
  - `forNovel(sourceKey, novelId)`：返回该书最新一条。
  - `record(entry)`：串行队列（`_pending`/`_enqueue`）里 `upsert` 后保存。
  - `clear()`。
  - `@visibleForTesting static upsert(current, entry)`：按 `(sourceKey, novelId)` 去重后插入到队首。
- `NovelHistoryNotifier extends Notifier<List<NovelHistoryEntry>>`（`build` → `all()`；`record`/`clear` 后刷新 `state`）。
- `final novelHistoryProvider = NotifierProvider<...>(NovelHistoryNotifier.new);`

### `novel_favorite.dart`

```dart
class NovelFavorite {
  final String sourceKey;
  final String novelId;
  final String title;
  final String? cover;
  final DateTime addedAt;
}
```

- `NovelFavoriteManager`：key `novel_favorites`；`all()`（按 `addedAt` 倒序）、`isFavorite`、`toggle(favorite)`（存在则删、否则 `upsert` 到队首）、`remove(sourceKey, novelId)`、`clear()`、`@visibleForTesting upsert`。
- `NovelFavoritesNotifier`（`build`/`toggle`/`clear`）+ `novelFavoritesProvider`。

## 首页改造（`lib/modules/novel/novel_home.dart`）

镜像 `comic_home.dart`：

- `NovelHomePage` 改为 `DefaultTabController(length: 3)`，顶部 `TabBar`（`labelColor` 主题蓝 `0xFF007AFF`、`indicatorColor` 同色、`dividerColor 0xFFE5E5EA`）三个 Tab：`探索` / `收藏` / `历史`。
- `TabBarView` 三个子页：
  - `_ExploreTab`（`ConsumerStatefulWidget` + `AutomaticKeepAliveClientMixin`，`wantKeepAlive => true`）：现有首页内容整体搬入——源 chips、`[推荐] + browseGroups` 分组 chips、组内选项 chips、网格与分页。切 Tab 后状态保留。
  - `_FavoritesTab`（`ConsumerWidget`）：`ref.watch(novelFavoritesProvider)`；空 → `EmptyState(icon: Icons.favorite_border_rounded, message: '还没有收藏')`；否则 6 列网格，用现有 `NovelCard`（已带 `novelImageHeaders`）→ 点击 `Navigator.push(noTransitionRoute(NovelDetailPage(...)))`。
  - `_HistoryTab`（`ConsumerWidget`）：顶部行「历史记录」标题 + 右侧「清空历史」`TextButton`（空记录时禁用，点击弹确认 `AlertDialog`「清空历史记录？」）；空 → `EmptyState(icon: Icons.history_rounded, message: '还没有阅读记录')`；否则 `ListView` 列表行：`InkWell` → `Navigator.push(smoothRoute(NovelReaderPage(...)))` 到该章；行内左侧 56×76 封面（`CachedNetworkImage` + `novelImageHeaders`），右侧书名、「读到 <chapterTitle>」、相对时间。
- 复用现有 `NovelCard`、`_grid`、`_pager`、`_chip` 等（搬迁到 `_ExploreTab`）。相对时间格式化函数（`刚刚 / N 分钟前 / N 小时前 / N 天前 / YYYY-MM-DD`）与漫画 `_relativeTime` 相同。

## 阅读器记录进度（`lib/modules/novel/novel_reader_page.dart`）

- `NovelReaderPage` 增加 `final String? cover;` 构造参数。
- 在 `build` 中：
  ```dart
  ref.listen(novelChapterProvider((widget.sourceKey, widget.novelId, _chapterId)),
      (_, next) {
    next.whenData((chapter) {
      ref.read(novelHistoryProvider.notifier).record(NovelHistoryEntry(
            sourceKey: widget.sourceKey,
            novelId: widget.novelId,
            title: widget.title,
            cover: widget.cover,
            chapterId: _chapterId,
            chapterTitle: chapter.title.isEmpty ? '第 $_chapterId 章' : chapter.title,
            updatedAt: DateTime.now(),
          ));
    });
  });
  ```
  章节加载成功即记录；`upsert` 去重，切上一/下一章自动更新到最新章。

## 详情页（`lib/modules/novel/novel_detail_page.dart`）

- `_infoCard` 内、简介下方增加一行操作区，放收藏按钮：镜像漫画 `_favoriteButton` —— `FilledButton.icon`，`isFavorite` 取 `ref.watch(novelFavoritesProvider)`，点击 `toggle(NovelFavorite(sourceKey, novelId, title: novel.title, cover: novel.coverUrl, addedAt: DateTime.now()))`；文案「已收藏 / 收藏」，图标 `bookmark_added_rounded / bookmark_add_outlined`。
- `_infoCard` 与分卷目录之间增加全宽「继续阅读」按钮（镜像漫画 `_continueReading`）：仅当 `ref.watch(novelHistoryProvider)` 中 `forNovel(sourceKey, novelId)` 有历史时显示，点击 `Navigator.push(smoothRoute(NovelReaderPage(..., chapterId: entry.chapterId, ...)))`。
- `_openChapter` 打开阅读器时传入 `cover: novel.coverUrl`。

## 错误处理

- 存储层坏数据跳过（`try/catch`），不影响其余条目。
- 历史/收藏为空时显示 `EmptyState`，不报错。

## 测试

- `test/core/novel/novel_history_test.dart`：`upsert` 去重（同书新章替换旧章、置顶）、排序、`fromJson`/`toJson` 往返、坏数据跳过。
- `test/core/novel/novel_favorite_test.dart`：`toggle` 添加/移除、`upsert` 去重、排序。
- `test/modules/novel/novel_home_tabs_test.dart`：override `novelFavoritesProvider`/`novelHistoryProvider`，切到「收藏」渲染书卡、「历史」渲染记录行与「清空历史」；空态断言。
- `test/modules/novel/novel_detail_page_test.dart`（扩展）：收藏切换后图标/文案变化；有历史时显示「继续阅读」。

## 接线

- 无侧边栏/`main_shell` 改动；`NovelHomePage` 仍在模块索引 2。

## 后续迭代

1. 账号云同步阅读进度/收藏。
2. 章内滚动位置恢复。
3. 统一书架（轻小说 + 漫画 + 动漫）。
