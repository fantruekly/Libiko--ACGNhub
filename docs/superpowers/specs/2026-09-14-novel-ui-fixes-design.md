# 轻小说界面修复与优化设计

日期：2026-09-14
状态：已与用户确认
前置：`docs/superpowers/specs/2026-09-14-novel-module-design.md`、`2026-09-14-lknovel-source-design.md`、`2026-09-14-novel-library-design.md`

## 背景与目标

四项修复/优化：

1. 哔哩轻小说（linovelib）的**文库**页面加载失败。
2. 轻之国度（lknovel）打开书详情偏慢。
3. 轻小说首页底部分页样式改为与漫画一致。
4. 章节名显示不全时，鼠标悬停自动滚动显示完整文字。

## #1 文库改用移动端域名（linovelib）

**根因**：`https://www.linovelib.com/wenku/...` 全部返回 403，响应体是 Cloudflare 的 `Just a moment...` 挑战页（`cf-mitigated: challenge`）；`/top/...` 与 `/novel/...` 不受影响。移动端域名 `https://w.linovelib.com` 未被挑战。

**改动**（`lib/core/novel/linovelib_source.dart`）：

- 新增常量 `linovelibMobileBaseUrl = 'https://w.linovelib.com'`。
- 新增 `List<Novel> parseMobileBookList(String html)`：
  - 遍历 `ol.book-ol li.book-li`；
  - `a.book-layout[href]` → `novelIdFromHref` 取 id；
  - 标题 `h4.book-title`；
  - 封面 `div.book-cover img` 的 `data-src`（回退 `src`），绝对地址（`https://www.bilinovel.com/...`）；
  - 作者 `span.book-author`：先移除其内嵌 `svg` 再取 `text.trim()`（否则会带上 svg 的 `<title>作者</title>`）；
  - 标签 `em.tag-small.yellow` 文本按空白拆分。
- 新增 `bool mobileHasNextPage(String html, int page)`：取 `div.pagelink a.last` 文本为最大页 `max`，返回 `page < max`；无 `a.last` 时回退 `false`。
- `LinovelibSource.browse`：
  - 排行（`rankingKeys`）分支不变（www + `rankPath` + `parseRankRows` + `hasNextPage`）；
  - 文库分支改为请求绝对地址 `'$linovelibMobileBaseUrl/wenku/$key/$page.html'`，用 `parseMobileBookList` + `mobileHasNextPage`。
  - 需要一个按绝对 URL 抓取的私有方法（`_dio.get` 传完整 URL，仍带浏览器头与 `Referer`）。
- 封面域名 `bilinovel.com` 无防盗链，沿用 `novelImageHeaders`。

## #2 lknovel 详情并发

**根因**：lknovel 单次 API 约 0.5–2s；`LknovelSource.detail` 需 1 次书信息 + N 次「分卷章节」（N=分卷数），当前并发上限 6。

**改动**（`lib/core/novel/lknovel_source.dart`）：`detail` 中分卷批次大小 `batchSize` 由 `6` 改为 `12`。

## #3 首页分页样式

**改动**（`lib/modules/novel/novel_home.dart`）：`_ExploreTabState._pager` 改为漫画 `comic_home.dart` 的 `_paginationBar` 风格：

- 外层 `Container(height: 44)`，顶部 `Border(top: 0.5px #E5E5EA)`；
- `Row(mainAxisAlignment: center)`：`IconButton(Icons.chevron_left_rounded, tooltip: '上一页', onPressed: _page > 1 ? ... : null)`、`SizedBox(16)`、`Text('第 $_page 页')`、`SizedBox(16)`、`IconButton(Icons.chevron_right_rounded, tooltip: '下一页', onPressed: hasMore ? ... : null)`。
- 移除 `_pagerButtonStyle`（`OutlinedButton`）与其相关代码。

## #4 章节名悬停滚动（MarqueeText）

**新增** `lib/core/widgets/marquee_text.dart`：

```dart
class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final double gap;       // 循环之间的间隔，默认 40
  final double velocity;  // 每秒滚动逻辑像素，默认 40
  const MarqueeText({super.key, required this.text, this.style, this.gap = 40, this.velocity = 40});
}
```

行为：

- `LayoutBuilder` + `TextPainter`（`maxLines: 1`、`textScaler: MediaQuery.textScalerOf(context)`）测量文字宽度；`overflow = textWidth - maxWidth`。
- `overflow <= 0`：渲染普通 `Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)`。
- `overflow > 0`：`ClipRect` → `MouseRegion`（`onEnter`/`onExit`）→ `AnimatedBuilder(animation: _controller)` → `Transform.translate(offset: Offset(-_controller.value * (overflow + gap), 0), child: Text(text, maxLines: 1, softWrap: false, style: style))`。
- `onEnter`：设置 `_controller.duration = (overflow + gap) / velocity 秒`，`_controller.repeat()`。
- `onExit`：`_controller.stop()` 且 `_controller.value = 0`。
- `dispose` 释放控制器。

**应用**：

- `lib/core/widgets/pill_button.dart`：把 label 的 `Text` 换成 `MarqueeText(text: label, style: ...)`（不溢出时行为不变）。
- `lib/modules/novel/novel_reader_page.dart` 的目录弹层：`ListTile` 的 `title: Text(c.title, maxLines: 1, overflow: ellipsis)` 换成 `title: MarqueeText(text: c.title)`。

## 测试

- `test/core/novel/linovelib_mobile_test.dart`：用精简移动端 HTML fixture，断言 `parseMobileBookList` 的 id/标题/封面/作者（不含「作者」二字）/标签，以及 `mobileHasNextPage`（有更大页码 → true；只有当前页 → false）。
- `test/core/widgets/marquee_text_test.dart`：
  - 短文本在受限宽度内不溢出 → 无滚动（不出现 `MouseRegion`）；
  - 长文本溢出 → 有 `MouseRegion`，鼠标悬停并 `pump` 后内部 `Transform` 的 x 位移 < 0。
- 更新 `test/modules/novel/novel_home_pager_test.dart`：断言分页区出现 `chevron_left_rounded`/`chevron_right_rounded` 图标且无异常（替换原「上一页/下一页」文字断言）。

## 非目标

- 不改排行榜/详情/章节的抓取域名（仍用 www）。
- 不为 lknovel 做目录懒加载或持久缓存。
- 不给历史列表的「读到 …」加悬停滚动。
- 不改动漫/漫画模块的逻辑（`PillButton` 的改动仅在其被复用处生效，且只在悬停+溢出时）。
