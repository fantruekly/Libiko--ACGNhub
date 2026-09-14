# 轻小说详情 + 分卷目录设计

日期：2026-09-14
状态：已与用户确认
前置：`docs/superpowers/specs/2026-09-14-novel-module-design.md`（v1 首页浏览/排行，已完成）

## 背景与目标

v1 首页已能浏览/排行，但点卡片无反应。本增量让用户点卡片进入**书籍详情页**：展示封面/书名/作者/标签/简介 + **分卷目录**（分卷 + 章节列表）。为下一步的阅读器铺路。

## 非目标（本增量不做）

- 正文阅读器（点章节只弹提示「阅读器开发中」）。
- 搜索、书架/收藏、阅读历史、离线。
- 相关推荐。

## 模型（`lib/core/novel/models.dart`）

- 新增 `NovelChapterRef { String id; String title; }`，`const NovelChapterRef({required id, required title})`。
- 新增 `NovelVolume { String title; String? url; List<NovelChapterRef> chapters; }`，`const NovelVolume({required title, url, chapters = const []})`。
- `NovelDetail` 由 `{ Novel novel; Map<String,String> chapters }` 改为 `{ Novel novel; List<NovelVolume> volumes }`。

## 接口（`lib/core/novel/linovelib_source.dart`）

- 实现 `LinovelibSource.detail(String id) -> Future<NovelDetail>`：
  1. 抓 `GET /novel/<id>.html` → 书名、封面、作者、标签、状态、简介、`og:novel:latest_chapter_url`。
  2. 抓 `GET /novel/<id>/catalog` → 分卷 + 章节。
  3. 合并为 `NovelDetail`。
- 新增纯解析函数（便于单测）：
  - `Novel parseNovelDetailHeader(String html, String id)` — 书名/封面/作者/标签/简介；状态存入 `extra['status']`（如「连载」）。
  - `List<NovelVolume> parseCatalog(String html, String novelId)` — 分卷+章节。

## 抓取细节

- 详情页 `GET /novel/<id>.html`：
  - 书名：`h1.book-name` 文本。
  - 封面：`div.book-img img` 的 `data-original`（回退 `src`）。
  - 作者：`meta[property="og:novel:author"]` 的 `content`。
  - 标签：`meta[property="og:novel:tags"]` 的 `content`（空格分隔 → `List<String>`）。
  - 状态：`meta[property="og:novel:status"]` 的 `content`（如「连载」）。
  - 简介：`div.book-dec` 文本（回退 `meta[name="description"]` 的 `content`）。
  - 详情页的 `div.book-vol-chapter` 只列**卷**，不列章节，故章节从目录页取。
- 目录页 `GET /novel/<id>/catalog`：
  - 分卷：`div.volume-list div.volume`；卷名 `h2.v-line a` 文本；卷链接 `h2.v-line a[href]`。
  - 章节：该 `div.volume` 内 `ul.chapter-list li a[href="/novel/<id>/<cid>.html"]`；章节 id 用 `novelIdFromHref` 取（正则 `/novel/(\d+)/(\d+)\.html` → 第二个数字）。**注意**：现有 `novelIdFromHref` 取的是第一个数字（书 id），章节需要单独的函数 `chapterIdFromHref(String? href)` 取第二段。
- HTTP 复用 `LinovelibSource._get`（已带 UA/Accept/Accept-Language/Referer）。

## UI（`lib/modules/novel/novel_detail_page.dart` 新增）

- `NovelDetailPage extends ConsumerStatefulWidget { final String sourceKey; final String novelId; final String title; final String? cover; }`。
- 结构：
  - `AppBar`（返回 + 书名）。
  - 头部卡片：封面（`CachedNetworkImage`，失败显示占位）+ 书名 + 作者 + 状态/标签 chips + 简介（`maxLines: 3` + `ellipsis`，超出时显示「展开/收起」切换为不限行数）。
  - 分卷目录：每卷一个 `Text` 卷标题 + 章节 `Wrap`（`PillButton(label: chapter.title, onTap: () => 提示)`）。
  - 三态：loading `ShimmerLoader`、error `EmptyState`（重试）、data。
- 点章节：`ScaffoldMessenger.showSnackBar(SnackBar(content: Text('阅读器开发中')))`。
- 首页 `NovelCard` 的 `onTap` 从 `null` 改为 push `NovelDetailPage`（用 `smoothRoute`）。

## Providers（`lib/modules/novel/novel_providers.dart`）

- 新增 `novelDetailProvider = FutureProvider.family<NovelDetail, (String, String)>((ref, key) async { ... })`，key = `(sourceId, novelId)`；source 不存在时抛 `StateError`。

## 错误处理

- 网络/解析失败 → 抛异常；详情页 `EmptyState`（「加载失败」+「重试」`ref.invalidate(novelDetailProvider(key))`）。
- 目录为空 → 显示「暂无章节」`EmptyState`。

## 测试

- `test/core/novel/linovelib_parser_test.dart` 追加：
  - `parseNovelDetailHeader`：从精简 fixture 解析出书名/作者/标签/封面/简介。
  - `parseCatalog`：解析出 2 卷、每卷章节数正确、章节 id 取自 URL 第二段。
  - `chapterIdFromHref`：`/novel/5340/333607.html` → `333607`；非章节链接 → `null`。
- `test/modules/novel/novel_detail_page_test.dart`（可选）：`NovelDetailPage` 在 provider override 下渲染书名与章节按钮。若 provider override 成本高则只做解析单测。

## 后续迭代

1. 阅读器（正文 `/novel/<id>/<cid>.html`、上一/下一章、阅读设置）。
2. 搜索。
3. 书架/收藏、阅读历史与续读。
