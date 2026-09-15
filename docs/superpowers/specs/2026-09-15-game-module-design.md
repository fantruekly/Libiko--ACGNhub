# 游戏模块设计（首版：首页浏览 / 详情展示）

日期：2026-09-15
状态：已与用户确认

## 背景

`lib/shell/main_shell.dart` 中「游戏」目前是「即将推出」占位页。`WorkType.game` 已存在但无实现。SPEC 第 4 阶段要求汇聚 Galgame 类日式游戏资源，来源为 `nekogal.com` 与 `game.galgamezywz.org`，app 提供游戏主页并展示从站点获取的信息。

本设计为第 4 阶段首版：接入单源 `game.galgamezywz.org`，把占位页替换为可用的游戏首页，并提供信息型详情页。

## 目标（v1）

- 接入第一个游戏源 **game.galgamezywz.org**（站名「galgame大玩家」）。
- 首页可按分区浏览：**最近更新 / 玩家热评 / 资源推荐 / 好游推荐 / 玩家最爱**，游戏以网格展示，支持手动翻页。
- 详情页展示：封面、标题、分类、标签、发布时间 / 最近更新 / 游戏大小 / 游戏平台 / 浏览热度、简介正文段落、正文内截图画廊，并提供「在原站打开」外链。
- 抽出 `GameSource` 抽象接口，后续可再接 nekogal。

## 非目标（v1 不做）

- 搜索页（首页顶栏搜索按钮对游戏模块不启用）。
- 收藏、浏览历史。
- 网盘下载链接、任何下载/播放行为。
- 第二源（nekogal）；首页 Hero 轮播；品牌索引（该站无品牌数据）。

## 来源调研结论

- `game.galgamezywz.org` 可正常抓取（本机直连返回完整服务端渲染 HTML），WordPress + ripro-v5 主题，UTF-8，无 Cloudflare/JS 挑战，内容不依赖 JS。
- 分区（分类 slug）：
  - 最近更新 = 首页全站文章流 `/`，分页 `/page/N`。
  - `玩家热评游戏` = `/lm/wanjiareping`。
  - `galgame资源推荐` = `/lm/galgame`。
  - `好游推荐` = `/lm/haoyoutuijian`。
  - `玩家最爱` = `/lm/wanjiazuiai`。
  - 分类分页 = `/lm/<slug>/page/N`。
- 列表项封面为懒加载：缩略图无 `src`，真实地址在 `data-bg`。
- 浏览数在列表页是预格式化字符串（`6.2K`、`125.2K`），需按后缀解析。
- 列表页日期文本是相对时间（`1 周前`），机器可读值在 `time.pub-date[datetime]`。
- 详情页**没有**品牌 / 原画 / 剧本 / 发售日等结构化字段，只有若干纯文本元信息行。
- `nekogal.com` 亦可访问，但为博客式文章流（PC资源/模拟器/工具/教程），留待后续迭代作为第二源。

## 架构与文件布局

```
lib/core/game/
  game_source.dart         # GameSource 抽象 + GameSourceManager
  models.dart              # Game / GameBrowseOption / GameList / GameDetail
  galgamezywz_source.dart  # GalgameZywzSource（dio + html，含可单测的纯解析函数）
lib/modules/game/
  game_providers.dart      # Riverpod providers
  game_home.dart           # GameHomePage + GameCard
  game_detail_page.dart    # GameDetailPage + 截图画廊
lib/shell/main_shell.dart  # 用 GameHomePage 替换 index 3 占位页
test/core/game/
  galgamezywz_parser_test.dart
test/modules/game/
  game_home_test.dart
  game_detail_page_test.dart
```

与动漫/漫画/轻小说模块同构：`core` 放「源」与解析，`modules` 放「UI + provider」。复用现有组件 `ChipBar` / `ShimmerLoader` / `EmptyState` / `SmoothRoute` / `WindowControls`。不引入新的状态管理或网络库（`dio` + `html` 已有）。

## 数据模型

```dart
class Game {
  final String id;              // 站内数字 id，如 '1207'
  final String title;
  final String? coverUrl;
  final String? summary;        // 列表页简述
  final String? category;       // 分类名，如 '玩家热评游戏'
  final List<String> tags;
  final DateTime? publishedAt;
  final int? views;             // '4.3K' -> 4300
  final Map<String, dynamic> extra; // {'url': 原站详情页}
  // fromJson / toJson（为将来收藏/历史复用而保留）
}

class GameBrowseOption {
  final String key;
  final String label;
}

class GameList {
  final List<Game> items;
  final int page;
  final bool hasMore;
}

class GameDetail {
  final Game game;
  final String? size;            // 游戏大小，如 '14.3GB'
  final String? platform;        // 游戏平台
  final DateTime? updatedAt;
  final List<String> paragraphs; // 正文纯文本段落
  final List<String> screenshots;// 正文内图片 URL
  final String sourceUrl;        // 原站详情页
}
```

模型自建（`Game`），与漫画/轻小说模块一致；后续做收藏/追更时再写 `Game -> Work` 转换以复用通用层。

## `GameSource` 接口

```dart
abstract class GameSource {
  String get id;        // 'galgamezywz'
  String get name;      // 'galgame大玩家'
  String get baseUrl;   // 'https://game.galgamezywz.org'

  /// 该源声明的浏览分区（首页顶部 chip）。
  List<GameBrowseOption> get browseOptions;

  /// 按分区选项分页拉取。
  Future<GameList> browse(String optionKey, {int page = 1});

  /// 详情。
  Future<GameDetail> detail(String id);
}
```

`GameSourceManager`：注册 / 按 id 取用 / 重复 id 抛 `ArgumentError`，与 `NovelSourceManager` 同构。

**不引入 `home()`**：「最近更新」本身就是分区分页，无需单独首页书单。

## Providers（`game_providers.dart`）

```dart
gameSourceManagerProvider   // Provider<GameSourceManager>，内置 GalgameZywzSource()
gameSourcesProvider         // Provider<List<GameSource>>
gameBrowseProvider((String sourceId, String optionKey, int page)) // FutureProvider<GameList>
gameDetailProvider((String sourceId, String gameId))              // FutureProvider<GameDetail>
```

- 首页/分区数据不 autoDispose（切来切去不重载）。
- 每个分区每页一个 provider 实例；点「下一页」page+1（手动换页），不自动触底加载。

## 抓取细节（`GalgameZywzSource`）

- HTTP：`dio`，桌面 Chrome UA，带 `Accept` / `Accept-Language` / `Referer: https://game.galgamezywz.org/`，超时 20s，响应按 UTF-8 解码。
- **分区 key → 路径**：
  - `latest` 最近更新：p1 `/`，pN `/page/N`
  - `wanjiareping` 玩家热评：`/lm/wanjiareping`，pN `/lm/wanjiareping/page/N`
  - `galgame` 资源推荐：`/lm/galgame`
  - `haoyoutuijian` 好游推荐：`/lm/haoyoutuijian`
  - `wanjiazuiai` 玩家最爱：`/lm/wanjiazuiai`
- **列表解析** `parseGameList(String html)`：
  - 条目 `article.post-item`。
  - id：从 `.entry-title a[href]` 取 `/game/(\d+)`，取不到则跳过该条目。
  - 标题：`.entry-title a` 文本。
  - 封面：`a.media-img` 的 `data-bg`，回退 `data-src`，再回退 `src`；相对地址补全为绝对地址。
  - 简述：`.entry-desc`。
  - 分类：`.entry-cat-dot a`。
  - 日期：`.entry-meta time.pub-date[datetime]`。
  - 浏览数：`.meta-views` 文本经 `parseCount` 解析（支持 `K`/`M` 后缀）。
- **分页解析** `parseHasNextPage(String html)`：
  - 存在 `nav.page-nav` 时，以 `a.page-link.page-next` 是否存在判定（存在即还有下一页）。
  - 无分页控件时，按「本页条目数 ≥ 12」兜底。
- **详情解析** `parseGameDetail(String html, String sourceUrl)`：
  - 标题：`h1.post-title`（回退 `.entry-title`）。
  - 封面：`.archive-shop .img-box img` 的 `src`（回退 `data-src`）。
  - 元信息：遍历 `.archive-shop .info-box .article-meta li`，按文本前缀匹配：
    - `资源分类` → `category`（取其中 `a` 文本）
    - `浏览热度` → `views`
    - `发布时间` → `publishedAt`
    - `最近更新` → `updatedAt`
    - `游戏大小` → `size`
    - `游戏平台` → `platform`
  - 标签：`.entry-tags a[rel="tag"]`。
  - 正文：`article.post-content`；段落取其中 `p` 的文本（去空、trim）；若没有 `p`，回退取整段文本。
  - 截图：取 `article.post-content` 内 `img` 的 `src`，过滤 `data:`、去重、排除与封面相同者。
- 图片请求头：`gameImageHeaders = {'Referer': 'https://game.galgamezywz.org/'}`，用于 `CachedNetworkImage`（防外链盗链）。

## 首页 UI（`game_home.dart`）

与轻小说首页同构：

- 第 1 行：源 chip（当前仅「galgame大玩家」）。
- 第 2 行：分区 chip：`最近更新 / 玩家热评 / 资源推荐 / 好游推荐 / 玩家最爱`，默认选中「最近更新」。
- 下方：网格 `GridView`（`crossAxisCount: 6`、`mainAxisSpacing: 20`、`crossAxisSpacing: 16`、`childAspectRatio: 0.58`）。
- 网格底部：「上一页 / 第 N 页 / 下一页」手动分页；「下一页」按 `hasMore` 启用/禁用。
- `GameCard`：封面（`CachedNetworkImage`，`gameImageHeaders`，`memCacheWidth: 400`）+ 标题（两行，13px，`w500`）；封面缺失用哈希底色占位（同 `NovelCard` 思路）。
- 点卡片用 `noTransitionRoute` 进 `GameDetailPage`。
- 加载中：`ShimmerLoader`（6 列、12 项、`aspectRatio: 0.58`）。

## 详情页 UI（`game_detail_page.dart`）

- 顶栏：返回 + 标题（单行省略）+ 「在原站打开」图标按钮（`url_launcher` 调系统浏览器）+ `WindowControls`。
- 正文滚动区：
  1. **信息卡**（白底圆角）：左侧封面 100×132；右侧标题、分类标签 + `tags` 胶囊；下方元信息行（发布时间 / 最近更新 / 游戏大小 / 游戏平台 / 浏览热度，空值不显示）。
  2. **简介**：`paragraphs` 逐段 `Text`。
  3. **截图**：横向滚动画廊（16:9 缩略图），点击用全屏 `InteractiveViewer` 放大查看。
  4. 底部标注「数据来源 game.galgamezywz.org」。
- 封面缺失 → 占位色块。

## 错误处理

- 非 200 / 超时 / 解析为空 → 抛异常；UI 用 `EmptyState`（「加载失败」+「重试」，重试 `ref.invalidate` 对应 provider）。
- 封面缺失 → 占位色块。

## 测试

- `test/core/game/galgamezywz_parser_test.dart`（必做，纯 Dart）：把真实抓取的 HTML 精简成 fixture，喂给解析函数，断言：
  - 列表解析出正确 id / 标题 / 封面（来自 `data-bg`）/ 简述 / 分类 / 日期 / 浏览数。
  - 无 `/game/<id>` 链接的条目被跳过。
  - 分页 URL 拼接正确；`parseHasNextPage` 判定正确。
  - 详情解析出标题 / 封面 / 元信息（分类、日期、大小、平台、浏览热度）/ 标签 / 段落 / 截图（去重、排除封面）。
- `test/modules/game/game_home_test.dart`、`game_detail_page_test.dart`：仿照 `test/modules/novel`，用 `ProviderScope` override 注入 fake `GameSource`，断言分区 chip、网格卡片、分页按钮、详情字段与画廊渲染。
- 网络层不打桩（靠手动跑应用验证）。

## 依赖变更

- `pubspec.yaml` 新增 `url_launcher`（Windows 与 Android 均支持），用于详情页「在原站打开」。

## 后续迭代（不在本版）

1. 站内搜索（`/?s=keyword`，分页 `?page/N?s=keyword`）。
2. 收藏、浏览历史（复用通用 `Work` 桥接与 `FavoriteManager`）。
3. 第二源 nekogal.com（博客式文章流，需另写解析）。
4. 首页 Hero 轮播（最新游戏自动播放）。
5. 网盘下载链接展示（外链，链接易失效）。
