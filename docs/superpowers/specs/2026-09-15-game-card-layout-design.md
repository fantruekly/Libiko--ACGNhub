# 游戏首页卡片布局与分页密度（4 列 3:2，24/页）设计

日期：2026-09-15
状态：已与用户确认
取代：`2026-09-15-game-page-size-design.md`（48/页）——其分页密度决定作废，本文件为准。

## 背景

游戏首页卡片沿用了小说/漫画的竖版 6 列（`childAspectRatio: 0.58`）布局，与源站 `game.galgamezywz.org` 的列表图不符：源站列表是 **3:2 横图**、桌面 **4 列**，我们的竖版格子把图片严重裁切。用户要求卡片尺寸与源站图片匹配，并把每页改为 **6 行**。

## 目标

- 卡片：**4 列、3:2 横图**（不裁切），与源站列表一致。
- 每页 **24** 个（4 列 × 6 行；24 能被 4 整除，非末页无空行）。

## 非目标

- 不改详情页、分区 chip、解析函数；不改其它模块。
- 不强制 6 行铺满视口高度（窗口过矮时页面内可滚动）。

## 来源事实（已实测）

- 列表项封面容器为 `.entry-media.ratio-3x2`（3:2 横图），站方以 `bg-cover bg-center` 裁切显示。
- 桌面列表为 4 列（`row-cols-lg-4`）。
- 源站每页 12 个；首页 `/` 第一页 16 个（含 4 个置顶）。

## 设计

### 分页密度

- `galgameZywzPageSize` 由 48 改为 **24**；`galgameZywzSourcePageSize` 保持 **12**。
- `GalgameZywzSource.browse` 逻辑不变：`pagesPerApp = ceil(24/12) = 2`；App 第 N 页抓源站第 `2N-1`、`2N` 页，拼接后裁剪到 24。
- 早停与错误处理沿用现状：某源页无下一页则停止；首个源页失败抛异常（UI 重试）；后续源页失败或为空则视为结束且 `hasMore = false`。

### 卡片布局

`lib/modules/game/game_home.dart`：

- `_grid` 改为 `LayoutBuilder`：
  - `cellW = (constraints.maxWidth - 32 - 16 * 3) / 4`
  - `mainAxisExtent = cellW * 2 / 3 + 44`
  - `GridView` 使用 `crossAxisCount: 4`、`crossAxisSpacing: 16`、`mainAxisSpacing: 20`、`padding: EdgeInsets.fromLTRB(16, 8, 16, 24)`。
- `GameCard` 结构不变：`Expanded` 封面（`BoxFit.cover`、`memCacheWidth: 400`、`gameImageHeaders`）+ 6px 间距 + 38px 标题（2 行）。因行高按 3:2 计算，封面恰好为 3:2（`cellW : cellW*2/3 = 3:2`）。
- 加载态：`ShimmerLoader(crossAxisCount: 4, itemCount: 8, aspectRatio: cellW / (cellW * 2 / 3 + 44), padding: 同上)`，用同一公式。

### 测试

`test/core/game/galgamezywz_source_test.dart`：

- `browse('galgame', page: 1)` 请求 `/lm/galgame`、`/lm/galgame/page/2`，返回 24 个。
- `browse('galgame', page: 2)` 请求 `/lm/galgame/page/3`、`/lm/galgame/page/4`，返回 24 个。
- 某源页「无下一页」时提前停止。
- 首页第一页 `16 + 12 = 28` 裁剪到 24。
- 首个源页失败抛异常；后续源页失败时 `hasMore == false` 且返回已抓到的部分。

`test/modules/game/game_home_test.dart`：

- 网格 `crossAxisCount == 4`。
- 卡片封面区域宽高比 ≈ 1.5（`cardWidth / (cardHeight - 44)`）。

## 后续迭代（不在本版）

- 若源站列表图比例变化，需重新校准 3:2 与列数。
- 若窗口很矮，6 行需滚动；如后续要「一屏 6 行」，需按视口高度动态算列/行（本版不做）。
