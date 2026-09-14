# 轻小说阅读器设计

日期：2026-09-14
状态：已与用户确认
前置：`docs/superpowers/specs/2026-09-14-novel-module-design.md`、`2026-09-14-novel-detail-design.md`

## 背景与目标

详情页已能展示分卷目录，但点章节只弹「阅读器开发中」。本增量实现**正文阅读器**：抓取并清洗章节正文，支持上一/下一章、目录跳转、阅读设置（字号/行距/主题），打通完整阅读链路。

## 非目标

- 搜索、书架/收藏、阅读历史/续读（后续）。
- 离线缓存、TTS、字体选择（后续）。
- 图片章节（插图的 `<img>`）——v1 只取文字段落，插图以占位忽略。

## 接口与数据（`lib/core/novel/`）

- `models.dart` 已有 `NovelChapter { String title; String content; }`（沿用）。
- 新增纯解析函数（`linovelib_source.dart`）：
  - `NovelChapter parseChapter(String html, String fallbackTitle)` — 从 `#mlfy_main_text h1` 取标题（回退 `fallbackTitle`），从 `div#TextContent` 的 `<p>` 取段落，按 `\n\n` 拼接为 `content`。
  - `String? nextPageHref(String html, String novelId, String chapterId)` — 从 `div.mlfy_page` 的「下一页」`<a>` 取 `href`；仅当形如 `/novel/<novelId>/<chapterId>_<n>.html`（同章分页）时返回该 href，否则返回 `null`。
- `LinovelibSource.chapter(novelId, chapterId)`：
  1. 抓 `/novel/<novelId>/<chapterId>.html`。
  2. `parseChapter` 取标题与首段；`nextPageHref` 若返回非空则继续抓取该页并把段落追加，循环直到 `null`。
  3. 返回合并后的 `NovelChapter`。
  - 保护：最多抓取 50 页，防止异常页面导致无限循环。

## 阅读器 UI（`lib/modules/novel/novel_reader_page.dart` 新增）

- `NovelReaderPage extends ConsumerStatefulWidget { final String sourceKey; final String novelId; final String chapterId; final String title; }`。
- 正文：`SingleChildScrollView`，每段一个 `Text`，`fontSize`/`lineHeight`/`color` 取自阅读设置。
- 顶部栏：返回 + 章节标题（`AppBar`，`backgroundColor` 随主题）。
- 底部栏：`上一章` / `目录` / `下一章`。上一/下一章基于 `novelDetailProvider(sourceKey, novelId)` 的**扁平化章节列表**（`flattenChapters(NovelDetail)`）按当前 `chapterId` 的索引前后跳（越界则禁用）。
- 「目录」：`showModalBottomSheet` 列出分卷与章节，点击切换章节。
- 点击正文区域切换顶/底栏显隐（`_chromeVisible`）。
- 三态：loading（`ShimmerLoader` 或居中转圈）、error（`EmptyState` + 重试）、data。
- 切换章节时：`chapterId` 变化 → 重新 `watch` provider；并滚动回顶部（`ScrollController.jumpTo(0)`）。

## 阅读设置（`lib/core/novel/novel_reader_settings.dart` 新增）

- `enum NovelReaderTheme { light, sepia, dark }`。
- `NovelReaderSettings { double fontSize; double lineHeight; NovelReaderTheme theme }`，`copyWith`，`fromJson`/`toJson`。
  - 默认：`fontSize: 17`、`lineHeight: 1.8`、`theme: light`。
  - `fontSize` 限制 12–28；`lineHeight` 限制 1.2–2.6。
- `NovelReaderSettingsManager`：`read()`/`write()`，存 `AppDatabase` key `novel_reader_settings`（JSON），参照 `comic_reader_settings.dart`。
- Provider：`novelReaderSettingsProvider`（`NotifierProvider`，方法 `setFontSize`/`setLineHeight`/`setTheme`）。
- 主题配色：
  - light：背景 `0xFFFFFFFF`、文字 `0xFF1C1C1E`。
  - sepia：背景 `0xFFF5EFE0`、文字 `0xFF3B3226`。
  - dark：背景 `0xFF1C1C1E`、文字 `0xFFD8D8DC`。

## Providers（`lib/modules/novel/novel_providers.dart`）

- `novelChapterProvider = FutureProvider.family<NovelChapter, (String, String, String)>`，key = `(sourceId, novelId, chapterId)`；source 不存在抛 `StateError`。
- `List<NovelChapterRef> flattenChapters(NovelDetail detail)` — 按分卷顺序扁平化章节（供上一/下一章与目录）。

## 错误处理

- 网络/解析失败 → 抛异常；阅读器 `EmptyState`（「加载失败」+「重试」`ref.invalidate(novelChapterProvider(key))`）。
- 正文为空 → 显示「本章暂无内容」。

## 接线

- `novel_detail_page.dart` 的章节点击从 SnackBar 改为 `Navigator.push(smoothRoute(NovelReaderPage(...)))`。

## 测试

- `test/core/novel/linovelib_chapter_parser_test.dart`：
  - `parseChapter`：从精简 fixture 解析标题 + 多段正文（`\n\n` 连接）。
  - `nextPageHref`：同章分页 href 返回该值；下一章 href 返回 `null`；无「下一页」返回 `null`。
- `test/core/novel/novel_reader_settings_test.dart`：默认值、`copyWith`、JSON 往返、越界 clamp。
- `test/modules/novel/novel_reader_page_test.dart`：provider override 渲染章节标题与正文文本；点击「下一章」用 fake detail 切换到下一章。

## 后续迭代

1. 阅读历史与续读（记录 `(novelId, chapterId)` 并恢复）。
2. 书架/收藏。
3. 搜索。
4. 离线缓存、字体选择、插图显示。
