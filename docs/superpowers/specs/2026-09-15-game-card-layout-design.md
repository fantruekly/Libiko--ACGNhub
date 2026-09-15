# 游戏首页卡片布局（4 列 3:2 横卡）设计

日期：2026-09-15
状态：已与用户确认

## 背景

游戏首页目前沿用小说/漫画的竖版卡片：6 列、`childAspectRatio: 0.58`，封面被拉成竖长条。而 `game.galgamezywz.org` 的列表项是 **3:2 横图**（`.entry-media.ratio-3x2`，`bg-cover bg-center` 裁切显示），桌面布局是 **4 列**（`row-cols-lg-4`）。结果：源站图片在 App 里被严重裁切，卡片尺寸也与源站不符。

## 目标

- 游戏首页网格改为 **4 列**，封面为 **精确 3:2 横图**，不裁切。
- 与源站列表的展示（4 列、3:2）一致。
- 维持「每页 48 个、非末页无空白」（48 ÷ 4 = 12 整行）。

## 非目标

- 不改详情页封面（`game_detail_page.dart` 的 100×132 信息卡封面是另一元素）。
- 不改卡片文字样式、分区 chip、分页逻辑。
- 不改其它模块的卡片。

## 实现

### `lib/modules/game/game_home.dart`

常量：`cols = 4`、`crossAxisSpacing = 16`、`mainAxisSpacing = 20`、水平内边距共 `32`、标题区高度 `44`（= 6 间距 + 38 标题）。

`_grid` 改为用 `LayoutBuilder` 按可用宽度计算行高，保证封面正好 3:2：

```dart
  Widget _grid(List<Game> items) {
    if (items.isEmpty) {
      return const EmptyState(icon: Icons.games_rounded, message: '暂无内容');
    }
    return LayoutBuilder(builder: (context, constraints) {
      const cols = 4;
      const spacing = 16.0;
      const titleExtent = 44.0;
      final cellW = (constraints.maxWidth - 32 - spacing * (cols - 1)) / cols;
      final extent = cellW * 2 / 3 + titleExtent;
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 20,
          crossAxisSpacing: spacing,
          mainAxisExtent: extent,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => GameCard(
          game: items[i],
          onTap: () => Navigator.push(
            context,
            noTransitionRoute(GameDetailPage(
              sourceKey: _sourceId,
              gameId: items[i].id,
              title: items[i].title,
              cover: items[i].coverUrl,
            )),
          ),
        ),
      );
    });
  }
```

`GameCard` 结构不变（`Expanded` 封面 + `SizedBox(height: 6)` + `SizedBox(height: 38)` 标题）；因行高按 `cellW × 2/3 + 44` 计算，封面正好得到 `cellW × cellW×2/3`，即 3:2。

加载态改为 4 列、同比例（用同一公式算 `aspectRatio`）：

```dart
      loading: () => LayoutBuilder(builder: (context, constraints) {
        const cols = 4;
        const spacing = 16.0;
        const titleExtent = 44.0;
        final cellW = (constraints.maxWidth - 32 - spacing * (cols - 1)) / cols;
        final extent = cellW * 2 / 3 + titleExtent;
        return ShimmerLoader(
          crossAxisCount: cols,
          itemCount: 8,
          aspectRatio: cellW / extent,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        );
      }),
```

### 不改动

- `GameCard` 的封面加载、占位、标题样式不变。
- `game_detail_page.dart`、分页与抓取逻辑不变。

## 错误处理

无变化（沿用现有 `EmptyState` + 重试）。

## 测试

在 `test/modules/game/game_home_test.dart` 增加断言：

- 网格 `crossAxisCount == 4`（读取 `GridView` 的 `SliverGridDelegateWithFixedCrossAxisCount`）。
- 卡片封面区域宽高比 ≈ 1.5：`tester.getSize(find.byType(GameCard).first)` 得到卡片尺寸，`coverHeight = height - 44`，断言 `width / coverHeight` 约等于 1.5（容差 0.02）。

现有「源/分区 chip、网格、翻页」断言保留不变。

## 后续迭代（不在本版）

- 若源站改版为其它比例/列数，需同步调整常量。
