# 轻之国度（lknovel）书源设计

日期：2026-09-14
状态：已与用户确认
前置：`docs/superpowers/specs/2026-09-14-novel-module-design.md`、`2026-09-14-novel-detail-design.md`、`2026-09-14-novel-reader-design.md`

## 背景与目标

现有轻小说模块只有一个书源（哔哩轻小说 linovelib），且首页的「排行/文库」标签与子选项写死了 linovelib 的配置。本增量做两件事：

1. 把「浏览分组」通用化：由每个书源自己声明分组与选项，首页通用渲染。
2. 新增第二个书源**轻之国度（lknovel）**，覆盖首页书单、排行/分类浏览、详情目录、正文阅读，功能与 linovelib 对齐。

## 非目标

- 搜索（界面无搜索框，接口留空）。
- 书架/收藏、阅读进度同步、评论/评分。
- 月度榜（lknovel 接口不支持 `monthly_hot`/`monthly_fresh`）。

## lknovel 站点与接口

站点：`https://www.lightnovel.fun`（`lknovel.lightnovel.cn` 会 301 跳转到此）。
接口：全部为 `POST https://www.lightnovel.fun/api/pc-proxy/api/<endpoint>`，JSON 请求体，**游客可用、无需签名**。响应形如 `{"code":0,"data":{...},"t":...}`，`code != 0` 视为失败。

用到的 endpoint：

| 用途 | endpoint | 请求体 | 关键响应字段 |
| --- | --- | --- | --- |
| 首页 feed | `bff/home-lightnovel-feed-v1` 等 | `{page,page_size}` | `data.list[]`、`data.pagination` |
| 排行 | `bff/book-rank-list-v1` | `{rank_scene,page,page_size}` | `data.list[]`（含 `rank_position`）、`data.pagination` |
| 书籍详情 | `new-content-read/get-book-detail` | `{book_id,with_volumes:1}` | `data.{title,author_name,cover_url,summary,tags,...}`、`data.volumes[]` |
| 分卷列表 | `new-content-read/get-book-volumes` | `{book_id,page,page_size}` | `data.list[]` |
| 卷内章节 | `new-content-read/get-volume-chapters` | `{book_id,volume_id,page,page_size}` | `data.list[]`、`data.pagination` |
| 章节正文 | `new-content-read/get-chapter-detail` | `{book_id,chapter_id}` | `data.title`、`data.body_snapshot.body_html`、`data.navigation` |

首页 feed 的 5 个场景：`home-feed-v1`(新书)、`home-lightnovel-feed-v1`(轻小说)、`home-original-feed-v1`(原创)、`home-fanfic-feed-v1`(同人)、`home-recent-updates-feed-v1`(最近更新)。

排行 `rank_scene` 有效值：`weekly_hot`(综合热度)、`daily_hot`(日热度)、`daily_fresh`(日新书)、`weekly_fresh`(周新书)、`daily_all`。

`page_size` 上限 50。

书籍卡片字段映射到 `Novel`：`book_id`→`id`，`title`→`title`，`author_name`→`author`，`cover_url`→`coverUrl`，`tags`/`visible_tags`→`tags`，`summary`/`summary_short`→`summary`，`rank_position`→`extra['rank']`。

封面/插图托管在 `api.lightnovel.fun`，**无防盗链**（任意或无 Referer 均返回 200），沿用现有全局 `novelImageHeaders` 即可。

## 1. 浏览分组通用化

`lib/core/novel/models.dart` 新增：

```dart
class NovelBrowseOption { final String key; final String label; }
class NovelBrowseGroup  { final String label; final List<NovelBrowseOption> options; }
```

`lib/core/novel/novel_source.dart` 调整：

- 新增 `List<NovelBrowseGroup> get browseGroups;`
- `Future<NovelList> browse(String optionKey, {int page = 1});`
- 删除 `NovelBrowse`、`NovelBrowseKind`（仅内部使用，无外部兼容负担）。

`lib/core/novel/linovelib_source.dart`：

- 把原 `novel_home.dart` 里的 `_rankingOptions`、`_bunkoOptions` 搬成 `browseGroups`（两组：「排行」「文库」）。
- `browse(optionKey, page)`：内部维护排行 key 集合，命中走 `rankPath`，否则走 `bunkoPath`。

`lib/modules/novel/novel_home.dart`：

- 删除硬编码的 `_rankingOptions`/`_bunkoOptions` 与 `_NovelSection` 枚举。
- 区块标签 = `[推荐]` + 当前源 `browseGroups.map(label)`。
- 选中某个浏览分组后，渲染该分组的选项 chips（选中项默认第一个），下方复用现有网格 + 分页。
- 切换源时重置分组、选项与页码。

`lib/modules/novel/novel_providers.dart`：

- `novelBrowseProvider` 键改为 `(String sourceId, String optionKey, int page)`。

## 2. `LknovelSource`（新增 `lib/core/novel/lknovel_source.dart`）

- 常量：`lknovelBaseUrl = 'https://www.lightnovel.fun'`；`lknovelUserAgent`（同 linovelib 风格）。
- `class LknovelSource implements NovelSource`：`id: 'lknovel'`，`name: '轻之国度'`，`baseUrl: lknovelBaseUrl`。
- Dio：`baseUrl: lknovelBaseUrl`，20s 超时，默认头 `User-Agent` / `Accept: application/json` / `Content-Type: application/json` / `Referer: https://www.lightnovel.fun/`。
- 私有 `Future<Map<String, dynamic>> _post(String endpoint, Map<String, dynamic> body)`：POST `/api/pc-proxy/api/$endpoint`，校验 `code == 0`，否则抛异常（带 endpoint 与 message）。
- 纯解析函数（便于单测）：
  - `Novel parseLkBook(Map<String, dynamic> json)`
  - `List<Novel> parseLkList(Map<String, dynamic> data)` — 取 `data.list`（回退 `data.cards`）
  - `List<NovelVolume> parseLkVolumes(Map<String, dynamic> data)` — 取 `data.volumes`（详情）或 `data.list`（分卷接口）
  - `List<NovelChapterRef> parseLkVolumeChapters(Map<String, dynamic> data)` — 取 `data.list`
  - `NovelChapter parseLkChapter(Map<String, dynamic> data, String fallbackTitle)` — 标题取 `data.title`；遍历 `data.body_snapshot.body_html` 的 `<p>`→`NovelText`、`<img src>`→`NovelImage`
- `home()`：并发请求 4 个 feed（轻小说 / 原创 / 同人 / 最近更新），各自转成一个 `NovelSection`；空区块跳过。单个 feed 失败只跳过该区块，不影响其余（全部失败才抛异常）。
- `browseGroups`：
  - 「排行」：综合热度 `weekly_hot`、日热度 `daily_hot`、日新书 `daily_fresh`、周新书 `weekly_fresh`
  - 「分类」：轻小说 `lightnovel`、原创 `original`、同人 `fanfic`、最近更新 `recent_updates`、新书 `new_books`
- `browse(optionKey, page)`：
  - optionKey 属于排行集合 → `bff/book-rank-list-v1`，body `{rank_scene: optionKey, page, page_size: 30}`。
  - 否则 → 对应 `home-*-feed-v1`，body `{page, page_size: 30}`。
  - `hasMore` 取 `data.pagination`（`page < page_count` 或 `has_more`）。
- `detail(id)`：
  1. `get-book-detail {book_id: id, with_volumes: 1}` → 书信息 + 卷列表（无章节）。
  2. 对每个卷并发（限并发，如 6）请求 `get-volume-chapters {book_id, volume_id, page:1, page_size:50}`；若某卷 `chapter_count > 50` 则继续翻页。
  3. 组装 `NovelDetail`。单卷失败不阻塞整体，该卷章节留空。
- `chapter(novelId, chapterId)`：`get-chapter-detail {book_id, chapter_id}` → `parseLkChapter`。
- `search` → `UnimplementedError`。

## 3. 注册

`lib/modules/novel/novel_providers.dart`：`NovelSourceManager(sources: [LinovelibSource(), LknovelSource()])`。

## 错误处理

- 网络/解析失败 → 抛异常；首页/详情/阅读器沿用现有 `EmptyState`（「加载失败」+「重试」）。
- `code != 0` → 抛带 message 的异常。
- 详情分卷章节拉取：单卷失败留空，不整体失败。

## 测试

- `test/core/novel/lknovel_source_test.dart`：用已抓取的 API 响应做 fixture，覆盖 `parseLkBook`、`parseLkList`、`parseLkVolumes`、`parseLkVolumeChapters`、`parseLkChapter`（`<p>` 与 `<img>`）。
- `test/core/novel/linovelib_browse_test.dart`：`browseGroups` 含排行/文库两组；`browse('allvisit')` 走排行路径、`browse('dengekibunko')` 走文库路径（可用 Dio mock 或断言路径映射函数）。
- 更新 `test/modules/novel/novel_home_pager_test.dart` 以适配新的分组渲染。

## 后续迭代

1. 搜索（lknovel 已有 `apk-search-*` 接口）。
2. 更多书源。
3. 阅读进度同步、书架。
