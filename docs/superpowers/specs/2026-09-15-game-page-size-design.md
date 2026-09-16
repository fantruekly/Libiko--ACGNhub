# 游戏首页分页密度（48/页）设计

日期：2026-09-15
状态：已作废 —— 分页密度改由 `2026-09-15-game-card-layout-design.md` 规定（24/页）。保留本文件仅作历史记录。

## 背景

游戏模块 v1 的首页每个 App 页对应源站一页，而 `game.galgamezywz.org` 每页只返回 **12** 个游戏；在 6 列网格下仅 2 行，页面下方大片留白。用户要求每页约 50 个且不留空白。

## 目标

- App 每页显示 **48** 个游戏（6 列 × 8 行，非末页刚好填满整行，无空格）。
- 仅改动游戏模块。

## 非目标

- 不改网格列数、卡片样式、分区 chip、详情页。
- 不做触底无限加载。
- 不新增缓存层。
- 末页可能不满 8 行（源站总数不一定是 48 的倍数，无法避免；不补假占位）。

## 来源事实（已实测）

- 源站列表每页固定 **12** 个；首页 `/` 第一页为 16 个（含 4 个 `置顶` 帖子）。
- 站方不支持更大的 `per_page` 参数（`?posts_per_page=48` 无效）。
- WP REST API 被禁用（`/wp-json/...` 返回 401）。
- 结论：要凑够 48，只能在 App 层一次抓取多个源站页再拼接。

## 方案（按偏移抓取）

App 第 N 页抓取源站第 `4N-3 … 4N` 页（4 页 = 48 个），拼接后裁剪到 48。

- 每页固定最多 4 次请求（翻到第 9 页也只抓 4 页），与「从第 1 页累积再切片」的做法相比不会随页数线性变慢。
- 已知取舍：`最近更新` 第 1 页 4 个源页合计 52，裁剪后丢掉最后 4 个（仅此一处）。
- 健壮性：源站总页数不一定是 4 的倍数，因此抓取循环在遇到「当前源页没有下一页」时立即停止，避免请求越界页导致 404。

## 实现

### `lib/core/game/galgamezywz_source.dart`

新增常量：

```dart
const int galgameZywzPageSize = 48;
const int galgameZywzSourcePageSize = 12;
```

改写 `GalgameZywzSource.browse(String optionKey, {int page = 1})`：

```dart
Future<GameList> browse(String optionKey, {int page = 1}) async {
  final pagesPerApp = (galgameZywzPageSize / galgameZywzSourcePageSize).ceil(); // 4
  final startServer = (page - 1) * pagesPerApp + 1;
  final items = <Game>[];
  var hasMore = false;
  for (var i = 0; i < pagesPerApp; i++) {
    final serverPage = startServer + i;
    final String html;
    try {
      html = await _get(galgameZywzBrowsePath(optionKey, serverPage));
    } catch (_) {
      if (i == 0) rethrow;
      break; // 越界/尾页异常：视为列表结束
    }
    final pageItems = parseGameList(html);
    if (pageItems.isEmpty) {
      hasMore = false;
      break;
    }
    items.addAll(pageItems);
    hasMore = parseHasNextPage(html, itemCount: pageItems.length);
    if (!hasMore) break; // 源站没有下一页：列表结束，不再请求后续页
  }
  final trimmed =
      items.length > galgameZywzPageSize ? items.sublist(0, galgameZywzPageSize) : items;
  return GameList(items: trimmed, page: page, hasMore: hasMore);
}
```

- `page` 仍表示 App 页码（每页 48）。
- `hasMore`：正常路径取最后一个成功源页的 `parseHasNextPage`；若后续源页失败或为空（视为列表结束），则 `hasMore = false`，避免「下一页」跳过失败源页造成内容空洞。
- 解析函数、`detail`、常量与其它方法不变。

### `lib/modules/game/game_home.dart`

**不改**。网格保持 6 列；48 个刚好 8 整行，非末页无空格。分页按钮语义（第 N 页）不变。

## 错误处理

- 首个源页请求失败 → 抛异常 → provider error → UI `EmptyState` + 「重试」（与现状一致）。
- 后续源页失败或为空 → 视为列表结束，`hasMore = false`，不报错（覆盖源站总页数非 4 倍数的情况）。
- 源站没有下一页 → 提前结束，不再发多余请求。

## 测试

在 `test/core/game/galgamezywz_source_test.dart` 增加用例（用 `_FakeAdapter` 按路径返回 HTML）：

- `browse('galgame', page: 2)` 依次请求 `/lm/galgame/page/5`、`/page/6`、`/page/7`、`/page/8`，拼接 4 页共 48 个，`hasMore` 取决于第 8 页是否有下一页。
- `browse('galgame', page: 1)` 请求 `/lm/galgame` 与 `/lm/galgame/page/2..4`。
- 某一源页「无下一页」时提前停止：例如第 2 个源页无 next，则只请求 2 页，`hasMore == false`。
- 首页第一页 4 页合计 52 时裁剪为 48。

## 后续迭代（不在本版）

- 若源站每页数量变化，需重新校准 `galgameZywzSourcePageSize`。
- 可选的并行抓取优化（当前顺序抓取，最多 4 次）。
