# 轻小说搜索设计

日期：2026-09-14
状态：已与用户确认
前置：`docs/superpowers/specs/2026-09-14-novel-module-design.md`、`2026-09-14-lknovel-source-design.md`

## 背景与目标

轻小说模块目前没有搜索：`NovelSource.search` 是 `UnimplementedError`，顶栏也没有搜索入口。本增量实现**跨书源搜索**：在顶栏加入口，输入关键词后聚合 lknovel 与 linovelib 的搜索结果，点结果进详情。

## 非目标

- 搜索历史、搜索建议/热词。
- 分页 / 加载更多（本轮单页，与漫画搜索一致）。
- 按书源筛选/Tab（聚合展示，不标源）。

## 源层：实现 `search`

### lknovel（`lib/core/novel/lknovel_source.dart`）

`Future<List<Novel>> search(String keyword, {int page = 1})`：

- `POST /api/bff/apk-search-result-v1`，body `{q: keyword, page: page, page_size: 20, pageSize: 20}`（经 `_post`）。
- 用 `parseLkList(lkData(json))` 解析（结果条目与 feed 同结构，`parseLkBook` 直接可用）。

### linovelib（`lib/core/novel/linovelib_source.dart`）

`Future<List<Novel>> search(String keyword, {int page = 1})`：

- `POST https://www.linovelib.com/S6/`，表单体 `searchkey=<关键词>`（Dio：`contentType: Headers.formUrlEncodedContentType`，`data: {'searchkey': keyword}`），沿用浏览器头。
- 新增纯解析函数 `List<Novel> parseSearchResults(String html)`：
  - 遍历 `div.search-result-list`；
  - `h2.tit a[href]` → `novelIdFromHref` 取 id、文本取标题；
  - `div.imgbox img` 的 `data-original`（回退 `src`）→ 封面（`_absUrl`）；
  - `div.bookinfo a` 的第一个 → 作者；
  - `p` → 简介；
  - `extra['url'] = '$linovelibBaseUrl/novel/$id.html'`。
- 忽略 `page`（该页无分页）。

## Provider（`lib/modules/novel/novel_providers.dart`）

- 新增：

```dart
class NovelSearchResult {
  final Novel novel;
  final String sourceKey;
  const NovelSearchResult({required this.novel, required this.sourceKey});
}
```

- 新增 `novelSearchProvider = FutureProvider.family<List<NovelSearchResult>, String>`：
  - 取 `novelSourceManagerProvider.sources`；
  - 逐个源 `source.search(keyword)`，成功的结果包成 `NovelSearchResult(novel, source.id)`；单源失败跳过（记录错误）；
  - 全部源失败 → 抛 `StateError('所有轻小说源搜索失败：$lastError')`；
  - 按 `novel.title.trim()` 去重（同名只保留第一个），保持顺序。

## 搜索页（新增 `lib/modules/novel/novel_search.dart`）

镜像 `lib/modules/comic/comic_search.dart`：

- `NovelSearchPage extends ConsumerStatefulWidget`，可选 `initialKeyword`。
- 顶部 48px 搜索栏（白底、底部分隔线）：返回按钮 + 圆角输入框（`搜索轻小说...` 提示、清除按钮）+「搜索」`TextButton`；`autofocus`（无 `initialKeyword` 时）。
- 空关键词 → `EmptyState(icon: Icons.search_rounded, message: '输入关键词搜索轻小说')`。
- 结果 → 6 列 `GridView`（`mainAxisSpacing: 20, crossAxisSpacing: 16, childAspectRatio: 0.58`），每项复用 `NovelCard`（`lib/modules/novel/novel_home.dart`）；点击 `Navigator.push(noTransitionRoute(NovelDetailPage(sourceKey: r.sourceKey, novelId: r.novel.id, title: r.novel.title, cover: r.novel.coverUrl)))`。
- 加载 `ShimmerLoader`；出错 `EmptyState` + 「重试」`ref.invalidate(novelSearchProvider(_keyword))`；空结果 `EmptyState(icon: Icons.search_off_rounded, message: '没有找到轻小说')`。

## 入口（`lib/shell/main_shell.dart`）

- 顶栏搜索图标条件由 `_currentIndex == 0 || _currentIndex == 1` 改为 `_currentIndex >= 0 && _currentIndex <= 2`；点击时按 index 分别 push `AnimeSearchPage` / `ComicSearchPage` / `NovelSearchPage`。

## 错误处理

- 单源失败跳过，不影响其它源；全部失败抛错，页面显示「加载失败」+ 重试。
- 关键词为空不发起请求。

## 测试

- `test/core/novel/linovelib_search_parser_test.dart`：`parseSearchResults` 从精简 fixture 解析 id/标题/封面/作者/简介；无结果时返回空。
- `test/core/novel/lknovel_source_test.dart`（扩展）：`LknovelSource(poster: ...)` 调 `search('x')`，断言请求 endpoint 为 `bff/apk-search-result-v1`、body 带 `q == 'x'`，返回 1 条。
- `test/modules/novel/novel_search_page_test.dart`：override `novelSearchProvider('关键词')` 渲染结果卡片标题；空关键词显示提示；空结果显示「没有找到轻小说」。

## 后续迭代

1. 搜索历史与热词。
2. 搜索分页 / 加载更多。
3. 按源筛选。
