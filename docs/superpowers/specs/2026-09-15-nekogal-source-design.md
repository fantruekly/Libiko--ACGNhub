# 游戏第二源 nekogal.com 设计

日期：2026-09-15
状态：已与用户确认

## 背景

SPEC 第 4 阶段要求从 `nekogal.com` 与 `game.galgamezywz.org` 汇聚 Galgame 类游戏资源。当前游戏模块只接了 `game.galgamezywz.org`（单源）。本设计接入第二源 `www.nekogal.com`，使游戏首页可切换源，与动漫/漫画/轻小说的多源体验一致。

## 目标

- 新增 `NekogalSource implements GameSource`，游戏首页源 chip 出现两个源：`galgame大玩家`、`NekoGAL`。
- nekogal 分区（浏览 chip）：**PC资源 / 汉化资源 / 生肉资源 / 模拟器资源**。
- 每 App 页仍为 **24** 个（与现有游戏首页一致）。
- 抽出共享分页逻辑，两个源行为一致。

## 非目标

- 不做 nekogal 搜索、网盘下载链接、收藏/历史。
- 不改游戏首页网格/卡片/详情页布局（仅把图片请求头改为按域名选择）。
- 不改其它模块。

## 来源调研结论（已实测）

- `www.nekogal.com` 为 WordPress + zibll 主题，**服务端渲染**，无 Cloudflare/JS 挑战；初始 HTML 已含列表条目。
- 分区路径：`/archives/category/<slug>`，分页 `/archives/category/<slug>/page/N`。
  - 游戏分区 slug：`pcgame`（PC资源）、`pcgame/hhzy`（汉化资源）、`pcgame/srzy`（生肉资源）、`pegame`（模拟器资源）。
  - 非游戏分区（不接入）：`tool`（工具下载）、`guide`（网站教程）。
- 列表条目：`posts.posts-item`（分类页为 `.list`，首页为 `.card`）。
  - 标题/链接 `.item-heading > a`（详情路径 `/archives/<id>`）。
  - 封面 `.item-thumbnail img` 的 `data-src`（懒加载；`src` 为占位 `thumbnail.svg`），图片托管在外部 `pan.nekogal.top`。
  - 简述 `.item-excerpt`；标签 `.item-tags a.but`；日期 `.meta-author span[title]`（`YYYY-MM-DD HH:MM:SS`）；浏览数 `item.meta-view`。
  - **分类页列表无分类字段**（首页卡片有，但分类页没有）。
- 分页：存在 `a.next.page-numbers` 表示还有下一页；总页数在 `.pag-jump input[max]`（pcgame 69 页、pegame 18 页）。
- 详情页：标题 `h1.article-title`；封面 `.single-cover img` 的 `data-src`；正文 `.article-content .wp-posts-content`；分类/子分类/标签在 `.article-tags`（`.c-blue`=分类、`.c-yellow`=子分类、`href*=/archives/tag/`=标签）；日期 `.article-header span[title]`（形如 `2026年09月14日 20:56发布`）；浏览/点赞 `.post-metas item.meta-view/.meta-like`。**无 developer/发售日/平台/大小 等结构化字段**。
- 下载链接经 `?golink=<base64>` 跳转到 `pan.nekogal.top`，匿名可见；本版不接入。
- 搜索 `/?s=<keyword>` 存在且与列表同构，本版不接入。
- 图片防盗链：本机 curl/PowerShell 对该站 TLS 握手失败，无法直接验证；采用「按域名给对应 Referer」的稳妥做法（无论图床是否校验都能加载）。

## 架构与文件布局

```
lib/core/game/
  game_paging.dart    # gamePageSize + GameSourcePage + buildGamePage（共享累积分页）
  game_image.dart     # gameImageHeadersFor(url)：按域名选择 Referer
  nekogal_source.dart # NekogalSource + 纯解析函数
  galgamezywz_source.dart  # 改用共享分页与图片头 helper（小改）
lib/modules/game/
  game_providers.dart      # 注册 NekogalSource()
  game_home.dart           # gameImageHeaders -> gameImageHeadersFor(url)
  game_detail_page.dart    # 同上（封面/画廊/查看器）
test/core/game/
  game_paging_test.dart
  nekogal_parser_test.dart
  nekogal_source_test.dart
```

与现有模块同构：`core` 放源与解析，`modules` 放 UI/provider。无新增依赖。

## 共享分页（`game_paging.dart`）

```dart
const int gamePageSize = 24;

class GameSourcePage {
  final List<Game> items;
  final bool hasMore;
  const GameSourcePage({required this.items, required this.hasMore});
}

Future<GameList> buildGamePage({
  required int page,
  required int sourcePageSize,
  required Future<GameSourcePage> Function(int sourcePage) fetch,
}) async {
  final pagesPerApp = (gamePageSize / sourcePageSize).ceil();
  final startServer = (page - 1) * pagesPerApp + 1;
  final items = <Game>[];
  var hasMore = false;
  for (var i = 0; i < pagesPerApp; i++) {
    final GameSourcePage result;
    try {
      result = await fetch(startServer + i);
    } catch (_) {
      if (i == 0) rethrow;   // 首源页失败 -> 报错（UI 重试）
      hasMore = false;       // 后续源页失败 -> 视为结束，避免内容空洞
      break;
    }
    if (result.items.isEmpty) {
      hasMore = false;
      break;
    }
    items.addAll(result.items);
    hasMore = result.hasMore;
    if (!hasMore) break;     // 无下一页 -> 结束，不再请求
  }
  final trimmed =
      items.length > gamePageSize ? items.sublist(0, gamePageSize) : items;
  return GameList(items: trimmed, page: page, hasMore: hasMore);
}
```

- `GalgameZywzSource.browse` 与 `NekogalSource.browse` 都用它；`galgameZywzPageSize` 常量移除（改用 `gamePageSize`）。
- 语义与现有 `GalgameZywzSource.browse` 完全一致（含首/后续失败处理、无下一页早停、裁剪）。

## 图片请求头（`game_image.dart`）

```dart
const Map<String, String> galgameZywzImageHeaders = {
  'Referer': 'https://game.galgamezywz.org/',
};
const Map<String, String> nekogalImageHeaders = {
  'Referer': 'https://www.nekogal.com/',
};

Map<String, String> gameImageHeadersFor(String? url) {
  if (url != null && url.contains('nekogal')) return nekogalImageHeaders;
  return galgameZywzImageHeaders;
}
```

- `game_home.dart` 的 `GameCard` 封面、`game_detail_page.dart` 的封面/画廊/全屏查看器，全部改为 `gameImageHeadersFor(url)`。
- `galgamezywz_source.dart` 的 `gameImageHeaders` 常量迁移到 `game_image.dart`（改名 `galgameZywzImageHeaders`）。

## `NekogalSource`

```dart
class NekogalSource implements GameSource {
  NekogalSource({Dio? dio});            // baseUrl https://www.nekogal.com，桌面 UA，Accept/Referer，20s
  String get id => 'nekogal';
  String get name => 'NekoGAL';
  String get baseUrl => 'https://www.nekogal.com';
  List<GameBrowseOption> get browseOptions => const [
    GameBrowseOption(key: 'pcgame', label: 'PC资源'),
    GameBrowseOption(key: 'hhzy', label: '汉化资源'),
    GameBrowseOption(key: 'srzy', label: '生肉资源'),
    GameBrowseOption(key: 'pegame', label: '模拟器资源'),
  ];
  Future<GameList> browse(String optionKey, {int page = 1});
  Future<GameDetail> detail(String id);
}
```

- 分区路径映射：`pcgame` → `/archives/category/pcgame`；`hhzy` → `/archives/category/pcgame/hhzy`；`srzy` → `/archives/category/pcgame/srzy`；`pegame` → `/archives/category/pegame`；页 N（N>1）追加 `/page/N`。
- `browse` 用 `buildGamePage(page: page, sourcePageSize: 12, fetch: ...)`；`fetch` 内 `_get` 列表页 → `parseNekogalList` + `parseNekogalHasNext`。

### 解析函数（纯函数，可单测）

- `String? nekogalIdFromHref(String? href)`：从 `/archives/(\d+)` 取数字 id。
- `int? parseNekogalCount(String raw)`：去掉非数字字符后 `int.tryParse`（nekogal 的 `.meta-view` 为纯数字，如 `451`）；在 `nekogal_source.dart` 内实现，不与 galgamezywz 的 `parseCount` 复用。
- `List<Game> parseNekogalList(String html)`：遍历 `posts.posts-item`；标题/链接取 `.item-heading a`（无 `/archives/<id>` 则跳过）；封面取 `.item-thumbnail img` 的 `data-src` 回退 `src`；简述 `.item-excerpt`；日期 `.meta-author span[title]`；浏览数 `.meta-view`；`extra['url']` = 绝对详情地址。
- `bool parseNekogalHasNext(String html, {required int itemCount})`：`a.next.page-numbers` 存在即 true；无分页控件时按 `itemCount >= 12` 兜底。
- `GameDetail parseNekogalDetail(String html, String sourceUrl)`：标题 `h1.article-title`；封面 `.single-cover img` 的 `data-src` 回退 `src`；正文 `.article-content .wp-posts-content`（回退 `.article-content`）；段落取 `p` 文本（无 `p` 时回退整段）；截图取正文 `img` 的 `data-src` 回退 `src`（去 `data:`、去重、排除封面）；分类取 `.article-tags a.c-blue`；标签取 `.article-tags a[href*="/archives/tag/"]`；日期取 `.article-header span[title]`（正则 `(\d{4})年(\d{2})月(\d{2})日` 解析）；浏览数取 `.post-metas item.meta-view`；`size`/`platform`/`updatedAt` 置空；`sourceUrl` 透传。

## Providers 与 UI

- `game_providers.dart`：`GameSourceManager(sources: [GalgameZywzSource(), NekogalSource()])`。
- 首页源 chip 自动变为两项；切换到 NekoGAL 后分区 chip 显示 4 个 nekogal 分区。
- `GameDetailPage` 的「在原站打开」使用 `detail.sourceUrl`（nekogal 为 `https://www.nekogal.com/archives/<id>`），无需改动。

## 错误处理

- 非 200 / 超时 / 解析为空 → 抛异常；UI `EmptyState` + 重试（与现状一致）。
- 首源页失败抛出；后续源页失败或为空 → `hasMore=false` 结束。
- 封面缺失 → 哈希底色占位。

## 测试

- `test/core/game/game_paging_test.dart`：累积到 24、`sourcePageSize` 不整除时的行为、无下一页早停、后续失败结束、首源页失败抛出、裁剪（如 26→24）。
- `test/core/game/nekogal_parser_test.dart`：列表字段（id/标题/封面 `data-src`/简述/日期/浏览数）、跳过无 `/archives/<id>` 条目、分页判定、详情字段（标题/封面/段落/截图去重去 `data:`/分类/标签/日期）。
- `test/core/game/nekogal_source_test.dart`：`browse('pcgame', page: 1)` 请求 `/archives/category/pcgame` 与 `/archives/category/pcgame/page/2`、返回 24；`detail` 请求 `/archives/<id>`。
- 回归：`test/core/game/galgamezywz_source_test.dart`（改用共享 helper 后仍通过）、`test/modules/game/game_home_test.dart`。

## 后续迭代（不在本版）

1. nekogal 搜索（`/?s=`）。
2. 收藏、浏览历史（复用通用 `Work` 桥接）。
3. 网盘下载外链（`?golink=` 解析）。
4. 若 nekogal 列表每页数量变化，需重新校准 `sourcePageSize`。
