# 游戏搜索设计

日期：2026-09-15
状态：已与用户确认

## 背景

动漫、漫画、轻小说模块都有搜索页（主壳顶部搜索按钮）。游戏模块目前没有搜索。两个游戏源都支持站内搜索：`game.galgamezywz.org` 与 `www.nekogal.com` 的 `/?s=<keyword>`。本设计为游戏模块加入跨源搜索页。

## 目标

- 游戏模块新增搜索页，一次跨两个源搜索并按标题去重，结果渐进展示。
- 主壳游戏 Tab（index 3）启用顶部搜索按钮，打开游戏搜索页。
- 结果卡片与游戏首页一致（4 列、3:2）。

## 非目标

- 搜索分页（仅取每个源的第一页，与轻小说搜索一致）。
- 按源筛选 chip。
- 网盘下载外链、收藏/历史。
- 不改其它模块的搜索。

## 来源调研结论（已实测）

- `game.galgamezywz.org`：`GET /?s=<urlencoded>`；结果与分类页同构（`article.post-item`），`parseGameList` 可直接解析。实测 `魔女`→12、`PC`→12、`ADV`→12、`金辉`→1、`galgame`→3（`制服`→0，即该站无结果）。
- `www.nekogal.com`：`GET /?s=<urlencoded>`；结果与分类页同构（`posts.posts-item`），`parseNekogalList` 可直接解析。实测 `制服`→12。
- 两源的 `_get` 均已处理请求（nekogal 含间歇性 TLS 失败重试）。

## 架构与文件布局

```
lib/modules/game/
  game_grid.dart     # 共享网格度量（列数/间距/标题高/格宽/格高）
  game_search.dart   # GameSearchPage（+ 结果网格）
  game_home.dart     # 改用 game_grid.dart 的度量
  game_providers.dart# GameSearchResult + gameSearchSourceProvider + gameSearchProvider
lib/core/game/
  game_source.dart       # GameSource 新增 search
  galgamezywz_source.dart# 实现 search
  nekogal_source.dart    # 实现 search
lib/shell/main_shell.dart# index 3 启用搜索按钮 -> GameSearchPage
test/...
```

与现有模块同构：搜索页放 `modules`，源实现放 `core`。无新增依赖。

## 接口变更

```dart
abstract class GameSource {
  // ...现有成员
  Future<List<Game>> search(String keyword);
}
```

- `GalgameZywzSource.search`：`_get('/?s=${Uri.encodeQueryComponent(keyword)}')` → `parseGameList(html)`。
- `NekogalSource.search`：`_get('/?s=${Uri.encodeQueryComponent(keyword)}')` → `parseNekogalList(html)`。
- 空关键词（trim 后）返回 `const []`。

## 共享网格（`game_grid.dart`）

把游戏首页的网格度量抽出，供首页与搜索页共用：

```dart
const int gameGridColumns = 4;
const double gameGridSpacing = 16;
const double gameGridTitleExtent = 44;

double gameGridCellWidth(double maxWidth) =>
    (maxWidth - 32 - gameGridSpacing * (gameGridColumns - 1)) / gameGridColumns;

double gameGridCellExtent(double maxWidth) =>
    gameGridCellWidth(maxWidth) * 2 / 3 + gameGridTitleExtent;
```

- `game_home.dart` 的 `_grid`/加载态改用这些；删除其私有 `_gridColumns`/`_gridSpacing`/`_gridTitleExtent`/`_gridCellWidth`/`_gridCellExtent`。
- 行为与现状一致（4 列、3:2、`mainAxisExtent`）。

## Providers（`game_providers.dart`）

```dart
class GameSearchResult {
  final Game game;
  final String sourceKey;
  const GameSearchResult({required this.game, required this.sourceKey});
}

const Duration gameSearchTimeout = Duration(seconds: 10);

final gameSearchSourceProvider =
    FutureProvider.family<List<GameSearchResult>, (String, String)>((ref, key) async {
  final (sourceId, keyword) = key;
  final k = keyword.trim();
  if (k.isEmpty) return const [];
  final source = ref.watch(gameSourceManagerProvider).byId(sourceId);
  if (source == null) return const [];
  final games = await source.search(k).timeout(gameSearchTimeout);
  return [for (final g in games) GameSearchResult(game: g, sourceKey: sourceId)];
});

final gameSearchProvider =
    FutureProvider.family<List<GameSearchResult>, String>((ref, keyword) async {
  // 并发所有源、单源失败隔离、按标题去重、全失败抛 StateError（与 novelSearchProvider 同构）
});
```

## 搜索页（`game_search.dart`）

镜像 `lib/modules/novel/novel_search.dart`：

- 顶部：返回按钮 + 搜索框（hint「搜索游戏...」）+「搜索」按钮；`onSubmitted` 触发。
- `_body`：空关键词显示 `EmptyState`（「输入关键词搜索游戏」）；否则遍历 `gameSourcesProvider`，用 `gameSearchSourceProvider((source.id, keyword))` 按源渐进聚合，按标题去重；有 pending 时显示顶部 `LinearProgressIndicator`；全部失败显示 `EmptyState` + 重试（invalidate 各源 provider）；无结果且无 pending 显示「没有找到游戏」；有结果用 4 列 3:2 网格。
- 结果卡片：`GameCard`（复用 `game_home.dart` 的 `GameCard`），`heroTag: 'game_${r.sourceKey}_${r.game.id}'`，点击 `smoothRoute(GameDetailPage(...))`。

## 主壳入口（`main_shell.dart`）

- 搜索按钮条件由 `_currentIndex >= 0 && _currentIndex <= 2` 放宽到 `<= 3`。
- 按 index 打开：0→Anime、1→Comic、2→Novel、3→`GameSearchPage`。

## 错误处理

- 单源搜索失败：该源结果为空，不阻塞其它源；有结果时照常展示。
- 全部源失败：显示错误 `EmptyState` + 重试。
- 超时：单源 10s 超时（视为该源失败）。

## 测试

- `test/core/game/galgamezywz_source_test.dart`：`search('魔女')` 请求 `/?s=%E9%AD%94%E5%A5%B3` 并解析出条目；空关键词不发请求。
- `test/core/game/nekogal_source_test.dart`：同上（`parseNekogalList`）。
- `test/modules/game/game_providers_test.dart`：`gameSearchSourceProvider` 委托与空关键词；`gameSearchProvider` 合并去重、单源失败隔离、全失败抛错。
- `test/modules/game/game_search_page_test.dart`：输入关键词后渲染结果；全失败显示重试。
- `test/shell/main_shell_test.dart`：游戏 Tab（index 3）出现搜索按钮。
- 回归：`game_source_test` / `game_home_test` / `game_providers_test` 里的假 `GameSource` 补 `search` 实现。

## 后续迭代（不在本版）

1. 搜索分页（`/page/N?s=`）。
2. 按源筛选。
3. 收藏/历史、网盘下载外链。
