# 轻小说 / 游戏卡片打开过渡设计

日期：2026-09-15
状态：已与用户确认

## 背景

动漫、漫画模块的卡片打开详情时有「淡入路由 + 封面 `Hero` 共享元素飞行」的过渡；轻小说、游戏模块使用 `noTransitionRoute`（瞬间切换）且卡片/详情均无 `Hero`，观感不一致。用户要求轻小说、游戏对齐动漫/漫画。

## 目标

- 轻小说、游戏模块的卡片 → 详情打开过渡与动漫/漫画一致：`smoothRoute` 淡入 + 封面 `Hero` 共享元素飞行。

## 非目标

- 不改动漫/漫画模块。
- 不改详情页布局（游戏详情封面仍为 100×132 竖图）。
- 不改轻小说历史记录行（它打开阅读器，不是详情页）。
- 不改阅读器/播放器相关过渡。

## 现状（参考实现）

- **动漫**：`anime_home.dart` 用 `DefaultTabController.of(context)` + 每个 tab 包 `HeroMode(enabled: controller.index == i)`；`WorkCard` 封面 `Hero(tag: 'work_<id>')`；`AnimeDetailPage` 封面同名 `Hero`；push 用 `smoothRoute`。
- **漫画**：`comic_home.dart` 同上；`ComicCard` 可选 `heroTag`，封面 `Hero(tag: 'comic_<sourceKey>_<id>')`；`ComicDetailPage` 同名 `Hero`；push 用 `smoothRoute`。
- **轻小说**：`novel_home.dart` push `noTransitionRoute`；`NovelCard` 无 `Hero`；`NovelDetailPage` 无 `Hero`。
- **游戏**：`game_home.dart` push `noTransitionRoute`；`GameCard` 无 `Hero`；`GameDetailPage` 无 `Hero`。

## 设计

### 轻小说

1. `lib/modules/novel/novel_home.dart`
   - `NovelCard` 增加可选 `String? heroTag`；非空时封面用 `Hero` 包裹（内层保留 `ClipRRect` 与占位逻辑）。
   - `NovelHomePage` 改为 `Builder` + `DefaultTabController.of(context)`，三个 tab 各包 `HeroMode(enabled: controller.index == i)`（仿 `anime_home.dart`）。
   - 探索、收藏卡片传 `heroTag: 'novel_${sourceKey}_${novelId}'`。
   - 卡片点击由 `noTransitionRoute` 改为 `smoothRoute`。
2. `lib/modules/novel/novel_detail_page.dart`：`_infoCard` 的封面包 `Hero(tag: 'novel_${widget.sourceKey}_${widget.novelId}')`。
3. `lib/modules/novel/novel_search.dart`：结果 `NovelCard` 传 `heroTag: 'novel_${r.sourceKey}_${r.novel.id}'`，push 改为 `smoothRoute`。

### 游戏

1. `lib/modules/game/game_home.dart`
   - `GameCard` 增加可选 `String? heroTag`；非空时封面用 `Hero` 包裹。
   - 卡片传 `heroTag: 'game_${_sourceId}_${items[i].id}'`。
   - 卡片点击由 `noTransitionRoute` 改为 `smoothRoute`。
2. `lib/modules/game/game_detail_page.dart`：`_infoCard` 的封面包 `Hero(tag: 'game_${sourceKey}_${gameId}')`。

### tag 规则

- 轻小说：`novel_<sourceKey>_<novelId>`
- 游戏：`game_<sourceKey>_<gameId>`

与漫画 `comic_<sourceKey>_<id>` 同构。

## 已知差异

游戏卡片封面为 3:2 横图，详情封面为 100×132 竖图，`Hero` 飞行时比例变化较明显；动漫/漫画两侧比例接近，变化不明显。如观感不佳，后续可把游戏详情封面也改成横图（不在本版）。

## 错误处理

- 封面为空时 `Hero` 仍包裹占位色块，tag 一致即可正常飞行。
- 同 tag 冲突：轻小说首页用 `HeroMode` 只在可见 tab 启用 `Hero`；游戏首页每游戏在列表中唯一。

## 测试

- `test/modules/game/game_home_test.dart`：卡片封面存在 `Hero`，tag 为 `game_galgamezywz_<id>`。
- `test/modules/game/game_detail_page_test.dart`：详情封面存在 `Hero`，tag 为 `game_galgamezywz_1207`。
- `test/modules/novel/novel_card_test.dart`：传入 `heroTag` 时渲染出 `Hero`；未传时无 `Hero`。
- `test/modules/novel/novel_detail_page_test.dart`：详情封面包 `Hero(tag: 'novel_linovelib_5340')`。
- 回归：`test/modules/novel/novel_home_tabs_test.dart`（验证 `HeroMode` 不产生同 tag 冲突）。

## 后续迭代（不在本版）

- 游戏详情封面若改为横图，可让 `Hero` 飞行更平滑。
- 轻小说历史记录行 → 阅读器是否也加封面飞行（当前不做）。
