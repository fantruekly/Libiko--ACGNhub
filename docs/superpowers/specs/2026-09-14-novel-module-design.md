# 轻小说模块设计（首版：首页浏览/排行）

日期：2026-09-14
状态：已与用户确认

## 背景

`lib/shell/main_shell.dart` 中「轻小说」目前是「即将推出」占位页。`WorkType.novel` 已存在但无实现。目标是把该占位页替换为可用的轻小说浏览首页，并为后续（搜索 / 详情 / 阅读器 / 书架 / 历史）留出可扩展的源接口。

## 目标（v1）

- 接入第一个小说源（linovelib / 哔哩轻小说）。
- 首页可浏览：**推荐**、**排行**、**文库分类**，书籍以网格展示，支持翻页/触底加载。
- 抽出 `NovelSource` 抽象接口，后续可加站或加源引擎。

## 非目标（v1 不做）

- 搜索、书籍详情、目录、正文阅读器。
- 书架/收藏、阅读历史、离线缓存。
- 多源聚合；仅接入 linovelib 单源。

## 来源调研结论

- `www.wenku8.net`：本机所有请求返回 **403**（反爬/区域限制），浏览器 UA 无效。
- `www.wenku8.cc`：镜像，首页声明「本站正式关闭（2015 年停站）」，无内容。
- `www.linovelib.com`（哔哩轻小说）：可正常访问，**UTF-8**，结构清晰。**选它作为首个源。**

## 架构与文件布局

```
lib/core/novel/
  novel_source.dart      # NovelSource 抽象类 + NovelSourceManager
  linovelib_source.dart  # LinovelibSource（dio + html 包抓取）
  models.dart            # Novel / NovelSection / NovelHome / NovelList / NovelBrowse
lib/modules/novel/
  novel_providers.dart   # 所有 Riverpod provider
  novel_home.dart        # NovelHomePage（+ NovelCard）
lib/shell/main_shell.dart  # 用 NovelHomePage 替换占位页（仅 index 2）
test/core/novel/
  linovelib_parser_test.dart  # 解析函数单测（HTML fixture）
```

与漫画模块同构：`core` 放「源」与解析，`modules` 放「UI + provider」。不引入新依赖（复用已有的 `dio` 与 `html`）。

## `NovelSource` 接口

```dart
abstract class NovelSource {
  String get id;        // 'linovelib'
  String get name;      // '哔哩轻小说'
  String get baseUrl;   // 'https://www.linovelib.com'

  /// 首页：若干带标题的书单（强推榜等）。
  Future<NovelHome> home();

  /// 排行 / 文库分类，分页。
  Future<NovelList> browse(NovelBrowse browse, {int page = 1});

  // v1 仅声明，后续实现：
  Future<List<Novel>> search(String keyword, {int page = 1});
  Future<NovelDetail> detail(String id);
  Future<NovelChapter> chapter(String novelId, String chapterId);
}
```

`NovelSourceManager`：注册/按 id 取用。v1 直接内置 `LinovelibSource()`（无动态加载）。

## 模型

- `Novel { String id; String title; String? author; String? coverUrl; List<String> tags; String? summary; Map<String,dynamic> extra; }`
  - `id` = 小说站内的数字 id（如 `2059`），`extra` 存原始链接、文库名等。
- `NovelSection { String title; List<Novel> items; }`
- `NovelHome { List<NovelSection> sections; }`
- `NovelList { List<Novel> items; int page; bool hasMore; }`
- `NovelBrowse { NovelBrowseKind kind; String key; }`，`enum NovelBrowseKind { ranking, bunko }`
  - `ranking` 的 key 如 `allvisit`/`monthvisit`/`weekvote`/`goodnum`…；`bunko` 的 key 如 `dengekibunko`。

模型自建（`Novel`），与漫画模块一致；后续做收藏/追更时再写 `Novel -> Work` 转换以复用 `FavoriteManager`/`FollowManager`。

## 首页 UI

与漫画首页同构：

- 第 1 行：**源 chip**（当前仅「哔哩轻小说」）。
- 第 2 行：**分区 chip**：`推荐` / `排行` / `文库`。
- 第 3 行（条件出现）：
  - 「排行」→ 子 chip：`人气榜`/`月点击`/`周点击`/`月推荐`/`周推荐`/`月鲜花`/`周鲜花`/`月鸡蛋`/`周鸡蛋`/`最近更新`/`最新入库`/`收藏榜`/`新书榜`。其中 `人气榜`（`allvisit`，`/top.html`）为**单页**，不显示分页。
  - 「文库」→ 子 chip：`电击`/`富士见`/`角川`/`MF文库J`/`Fami通`/`GA`/`HJ`/`一迅社`/`集英社`/`小学馆`/`讲谈社`/`少女文库`/`其他文库`/`华文轻小说`。
- 下方：**网格**（`NovelCard`：封面 + 书名 + 作者）。
- 「排行」/「文库」在网格底部提供「上一页 / 第 N 页 / 下一页」**手动换页**按钮（不做自动触底加载）。

- 「推荐」= 把 `home()` 的多个书单**合并去重**成一个网格（不做横向书单，保持网格一致性）；一次性加载，不分页。
- 「排行」/「文库」按页取；`hasMore` 优先看分页控件（`div.pagination`）是否有「下一页」链接，若无分页控件则按「本页条目数 >= 10」判定。分页按钮的「下一页」按 `hasMore` 启用/禁用。

## Providers

```dart
novelSourceManagerProvider                              // Provider<NovelSourceManager>
novelSourcesProvider                                    // Provider<List<NovelSource>>
novelHomeProvider(String sourceId)                      // FutureProvider<NovelHome>（推荐）
novelBrowseProvider((String sourceId, NovelBrowseKind kind, String key, int page)) // FutureProvider<NovelList>
```

- 与漫画一致：首页/分区数据不 autoDispose（切来切去不重载）。
- 排行/文库每页一个 provider 实例，触底时 page+1。

## 抓取细节（`LinovelibSource`）

- HTTP：`dio`，UA 用桌面 Chrome，并带 `Accept` / `Accept-Language` / `Referer: https://www.linovelib.com/`，超时 20s。响应按 UTF-8 解码。（缺 `Accept`/`Accept-Language` 会被 Cloudflare 挑战。）
- **首页** `GET /`：
  - 区块：`div.tab-lists`；区块标题 `div.top-title .title`。
  - 条目 `div.lists ul li`：封面 `div.imgbox img[data-original]`（回退 `src`）、书名 `a.title[href=/novel/<id>.html]`、作者 `a.author`、文库 `a.cate`。
  - 注意：部分 `li` 是纯文本条目（`a.author2` + 无名 `a[title]`），需按有无 `a.title` 过滤。
- **排行** `GET /top/<key>/<page>.html`（如 `/top/monthvote/1.html`）；人气榜为 `/top.html`：
  - 行 `div.rank_i_li`：名次 `div.rank_i_num`、书名 `div.rank_i_bname a.rank_i_l_a_book`（或首个 `a[href=/novel/<id>.html]`）、作者 `a.rank_i_l_a_author`、文库 `a.rank_i_l_a_category`、封面 `div.rank_i_bcount img[data-original]`。
- **文库** `GET /wenku/<key>/<page>.html`：与首页 `div.lists ul li` 同构。
- id 提取：从 `/novel/<id>.html` 取数字。

## 错误处理

- 非 200 / 超时 / 解析为空 → 抛异常；UI 用 `EmptyState`（「加载失败」+「重试」，重试 `ref.invalidate` 对应 provider）。
- 封面缺失时 `NovelCard` 显示占位（沿用 `WorkCard` 的哈希底色占位思路）。

## 测试

- 纯 Dart 单测：把真实抓下的 HTML 精简成 fixture，喂给解析函数，断言：
  - 首页解析出非空书单与正确字段（书名、id、封面、作者）。
  - 排行解析出名次/书名/链接/封面。
  - 分页 URL 拼接正确。
  - 文本型 `li` 被正确过滤。
- 网络层不打桩（v1 靠手动跑应用验证）。

## 后续迭代（不在本版）

1. 搜索（`/search.php` 或站内搜索）。
2. 书籍详情 + 分卷目录（`/novel/<id>.html`）。
3. 阅读器（`/novel/<id>/<cid>.html` 正文提取、字号/主题/翻页、上一/下一章）。
4. 书架/收藏、阅读历史与续读（复用通用 `Work` 桥接）。
5. 更多源（含用 WebView 抓 wenku8）。
