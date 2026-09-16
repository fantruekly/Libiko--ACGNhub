# 轻小说 / 游戏卡片打开过渡 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让轻小说、游戏模块的卡片打开详情时拥有与动漫/漫画一致的过渡：`smoothRoute` 淡入 + 封面 `Hero` 共享元素飞行。

**Architecture:** 给 `NovelCard`/`GameCard` 增加可选 `heroTag`（非空时用 `Hero` 包住封面，仿 `ComicCard`），详情页封面使用同名 `Hero`，卡片点击由 `noTransitionRoute` 改为 `smoothRoute`。轻小说首页用 `HeroMode` 按可见 tab 启用 Hero，避免同 tag 冲突。

**Tech Stack:** Flutter (Dart 3.6)、flutter_riverpod（均已有，无新增依赖）。

## Global Constraints

- 不改动漫/漫画模块；不改详情页布局；不改阅读器/播放器过渡；不改轻小说历史记录行。
- 无新增依赖。不添加代码注释（除非下方给定代码已含）。
- tag 规则：轻小说 `novel_<sourceKey>_<novelId>`；游戏 `game_<sourceKey>_<gameId>`。
- 在 `dev` 分支开发；每个任务结束提交一次。
- 测试命令：`C:\flutter\bin\flutter.bat test <path>`；静态检查：`C:\flutter\bin\flutter.bat analyze`。

---

## Task 1: 轻小说卡片打开过渡

**Files:**
- Modify: `lib/modules/novel/novel_home.dart`
- Modify: `lib/modules/novel/novel_detail_page.dart`
- Modify: `lib/modules/novel/novel_search.dart`
- Test: `test/modules/novel/novel_card_test.dart`
- Test: `test/modules/novel/novel_detail_page_test.dart`

**Interfaces:**
- Consumes: `smoothRoute` / `noTransitionRoute`（`core/widgets/smooth_route.dart`，均已导出）。
- Produces: `NovelCard({..., String? heroTag})`；`NovelHomePage` 各 tab 的 `HeroMode`；详情页封面 `Hero(tag: 'novel_<sourceKey>_<novelId>')`。

### Step 1: 写测试（先失败）

在 `test/modules/novel/novel_card_test.dart` 的 `main()` 末尾追加：

```dart
  testWidgets('NovelCard wraps the cover in a Hero when heroTag is given',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 120,
          height: 200,
          child: NovelCard(
              novel: Novel(id: '1', title: '安达与岛村'),
              heroTag: 'novel_linovelib_1'),
        ),
      ),
    ));
    final hero = tester.widget<Hero>(find.byType(Hero));
    expect(hero.tag, 'novel_linovelib_1');
  });

  testWidgets('NovelCard has no Hero without a heroTag', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 120,
          height: 200,
          child: NovelCard(novel: Novel(id: '1', title: '安达与岛村')),
        ),
      ),
    ));
    expect(find.byType(Hero), findsNothing);
  });
```

在 `test/modules/novel/novel_detail_page_test.dart` 的 `main()` 内追加（放在已有测试之后）：

```dart
  testWidgets('NovelDetailPage wraps the cover in a Hero', (tester) async {
    const detail = NovelDetail(
      novel: Novel(id: '5340', title: '不相容的異種族妻子們'),
      volumes: [],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        novelDetailProvider(('linovelib', '5340'))
            .overrideWith((ref) async => detail),
      ],
      child: const MaterialApp(
        home: NovelDetailPage(
            sourceKey: 'linovelib', novelId: '5340', title: '不相容的異種族妻子們'),
      ),
    ));
    await tester.pumpAndSettle();
    final hero = tester.widget<Hero>(find.byType(Hero));
    expect(hero.tag, 'novel_linovelib_5340');
  });
```

Run: `C:\flutter\bin\flutter.bat test test/modules/novel/novel_card_test.dart test/modules/novel/novel_detail_page_test.dart`
Expected: FAIL —— `NovelCard` 无 `heroTag` 参数（编译错误）；详情页无 `Hero`。

### Step 2: 改 `NovelCard`

把 `lib/modules/novel/novel_home.dart` 的 `NovelCard`（第 23–81 行）替换为：

```dart
class NovelCard extends StatelessWidget {
  final Novel novel;
  final VoidCallback? onTap;
  final String? heroTag;
  const NovelCard({super.key, required this.novel, this.onTap, this.heroTag});

  @override
  Widget build(BuildContext context) {
    Widget image = RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: novel.coverUrl != null && novel.coverUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: novel.coverUrl!,
                fit: BoxFit.cover,
                memCacheWidth: 400,
                fadeInDuration: Duration.zero,
                httpHeaders: novelImageHeaders,
                placeholder: (_, __) => _placeholder(),
                errorWidget: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
    if (heroTag != null) {
      image = Hero(tag: heroTag!, child: image);
    }
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: image),
          const SizedBox(height: 6),
          SizedBox(
            height: 38,
            child: Text(
              novel.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500, height: 1.45, color: _fg),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    final hash = novel.title.hashCode.abs();
    const bg = [Color(0xFFF3E5F5), Color(0xFFEDE7F6), Color(0xFFE8EAF6), Color(0xFFE0F2F1)];
    return Container(
      color: bg[hash % bg.length],
      child: Center(
        child: Text(
          novel.title.isEmpty ? '书' : novel.title.characters.first,
          style: TextStyle(
              color: _accent.withValues(alpha: 0.2), fontSize: 28, fontWeight: FontWeight.w400),
        ),
      ),
    );
  }
}
```

### Step 3: 改 `NovelHomePage`（HeroMode）

把 `lib/modules/novel/novel_home.dart` 的 `NovelHomePage`（第 83–103 行）替换为：

```dart
class NovelHomePage extends ConsumerWidget {
  const NovelHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Builder(builder: (context) {
        final controller = DefaultTabController.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TabStrip(labels: ['探索', '收藏', '历史']),
            Expanded(
              child: TabBarView(
                children: [
                  _heroTab(controller, 0, const _ExploreTab()),
                  _heroTab(controller, 1, const _FavoritesTab()),
                  _heroTab(controller, 2, const _HistoryTab()),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  static Widget _heroTab(TabController controller, int index, Widget child) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) =>
          HeroMode(enabled: controller.index == index, child: child),
    );
  }
}
```

### Step 4: 改探索/收藏卡片与路由

在 `_ExploreTabState._grid`（第 256–278 行）中，把 `itemBuilder` 替换为：

```dart
      itemBuilder: (_, i) => NovelCard(
        novel: items[i],
        heroTag: 'novel_${_sourceId}_${items[i].id}',
        onTap: () => Navigator.push(
          context,
          smoothRoute(NovelDetailPage(
            sourceKey: _sourceId,
            novelId: items[i].id,
            title: items[i].title,
            cover: items[i].coverUrl,
          )),
        ),
      ),
```

在 `_FavoritesTab.build`（第 296–311 行）中，把 `itemBuilder` 替换为：

```dart
      itemBuilder: (_, i) => NovelCard(
        novel: Novel(
          id: favorites[i].novelId,
          title: favorites[i].title,
          coverUrl: favorites[i].cover,
        ),
        heroTag: 'novel_${favorites[i].sourceKey}_${favorites[i].novelId}',
        onTap: () => Navigator.push(
          context,
          smoothRoute(NovelDetailPage(
            sourceKey: favorites[i].sourceKey,
            novelId: favorites[i].novelId,
            title: favorites[i].title,
            cover: favorites[i].cover,
          )),
        ),
      ),
```

### Step 5: 详情页封面 Hero

把 `lib/modules/novel/novel_detail_page.dart` 的 `_infoCard` 里封面 `ClipRRect`（第 160–175 行）替换为：

```dart
              Hero(
                tag: 'novel_${widget.sourceKey}_${widget.novelId}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 100,
                    height: 132,
                    child: cover != null
                        ? CachedNetworkImage(
                            imageUrl: cover,
                            fit: BoxFit.cover,
                            httpHeaders: novelImageHeaders,
                            placeholder: (_, __) => _coverPlaceholder(),
                            errorWidget: (_, __, ___) => _coverPlaceholder(),
                          )
                        : _coverPlaceholder(),
                  ),
                ),
              ),
```

### Step 6: 搜索页卡片 Hero + smoothRoute

把 `lib/modules/novel/novel_search.dart` 的 `_grid` 中 `itemBuilder`（第 205–219 行）替换为：

```dart
      itemBuilder: (_, i) {
        final r = results[i];
        return NovelCard(
          novel: r.novel,
          heroTag: 'novel_${r.sourceKey}_${r.novel.id}',
          onTap: () => Navigator.push(
            context,
            smoothRoute(NovelDetailPage(
              sourceKey: r.sourceKey,
              novelId: r.novel.id,
              title: r.novel.title,
              cover: r.novel.coverUrl,
            )),
          ),
        );
      },
```

### Step 7: 运行测试确认通过

Run:
- `C:\flutter\bin\flutter.bat test test/modules/novel/novel_card_test.dart`
- `C:\flutter\bin\flutter.bat test test/modules/novel/novel_detail_page_test.dart`
- `C:\flutter\bin\flutter.bat test test/modules/novel/novel_home_tabs_test.dart`
Expected: 均 PASS。

### Step 8: 静态检查 + 提交

Run: `C:\flutter\bin\flutter.bat analyze`
Expected: `No issues found!`

```bash
git add lib/modules/novel/novel_home.dart lib/modules/novel/novel_detail_page.dart lib/modules/novel/novel_search.dart test/modules/novel/novel_card_test.dart test/modules/novel/novel_detail_page_test.dart
git commit -m "feat(novel): cover hero transition when opening a detail page"
```

---

## Task 2: 游戏卡片打开过渡

**Files:**
- Modify: `lib/modules/game/game_home.dart`
- Modify: `lib/modules/game/game_detail_page.dart`
- Test: `test/modules/game/game_home_test.dart`
- Test: `test/modules/game/game_detail_page_test.dart`

**Interfaces:**
- Consumes: `smoothRoute`（`core/widgets/smooth_route.dart`）。
- Produces: `GameCard({..., String? heroTag})`；详情页封面 `Hero(tag: 'game_<sourceKey>_<gameId>')`。

### Step 1: 写测试（先失败）

在 `test/modules/game/game_home_test.dart` 的 `main()` 末尾追加：

```dart
  testWidgets('game card cover has a Hero tagged by source and id',
      (tester) async {
    final container = ProviderContainer(overrides: [
      gameSourceManagerProvider
          .overrideWithValue(GameSourceManager(sources: [_FakeSource()])),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: GameHomePage())),
    ));
    await tester.pumpAndSettle();

    final hero = tester.widget<Hero>(find.byType(Hero));
    expect(hero.tag, 'game_galgamezywz_latest-1');
  });
```

在 `test/modules/game/game_detail_page_test.dart` 的第一个测试（`renders title, meta, tags, paragraphs and source button`）末尾、`expect(find.text('数据来源 game.galgamezywz.org'), findsOneWidget);` 之后追加：

```dart
    final hero = tester.widget<Hero>(find.byType(Hero));
    expect(hero.tag, 'game_galgamezywz_1207');
```

Run:
- `C:\flutter\bin\flutter.bat test test/modules/game/game_home_test.dart`
- `C:\flutter\bin\flutter.bat test test/modules/game/game_detail_page_test.dart`
Expected: FAIL —— 卡片/详情均无 `Hero`。

### Step 2: 改 `GameCard`

把 `lib/modules/game/game_home.dart` 的 `GameCard`（第 29–74 行，`build` 方法部分）替换为：

```dart
class GameCard extends StatelessWidget {
  final Game game;
  final VoidCallback? onTap;
  final String? heroTag;
  const GameCard({super.key, required this.game, this.onTap, this.heroTag});

  @override
  Widget build(BuildContext context) {
    Widget image = RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: game.coverUrl != null && game.coverUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: game.coverUrl!,
                fit: BoxFit.cover,
                memCacheWidth: 400,
                fadeInDuration: Duration.zero,
                httpHeaders: gameImageHeaders,
                placeholder: (_, __) => _placeholder(),
                errorWidget: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
    if (heroTag != null) {
      image = Hero(tag: heroTag!, child: image);
    }
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: image),
          const SizedBox(height: 6),
          SizedBox(
            height: 38,
            child: Text(
              game.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                  color: _fg),
            ),
          ),
        ],
      ),
    );
  }
```

（`GameCard` 的 `_placeholder()` 方法保持不变，保留在类内。）

### Step 3: 改游戏首页卡片与路由

在 `lib/modules/game/game_home.dart` 的 `_grid`（第 215–243 行）中，把 `itemBuilder` 替换为：

```dart
        itemBuilder: (_, i) => GameCard(
          game: items[i],
          heroTag: 'game_${_sourceId}_${items[i].id}',
          onTap: () => Navigator.push(
            context,
            smoothRoute(GameDetailPage(
              sourceKey: _sourceId,
              gameId: items[i].id,
              title: items[i].title,
              cover: items[i].coverUrl,
            )),
          ),
        ),
```

### Step 4: 详情页封面 Hero

把 `lib/modules/game/game_detail_page.dart` 的 `_infoCard` 里封面（第 164–167 行）替换为：

```dart
              Hero(
                tag: 'game_${sourceKey}_$gameId',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child:
                      SizedBox(width: 100, height: 132, child: _cover(coverUrl)),
                ),
              ),
```

### Step 5: 运行测试确认通过

Run:
- `C:\flutter\bin\flutter.bat test test/modules/game/game_home_test.dart`
- `C:\flutter\bin\flutter.bat test test/modules/game/game_detail_page_test.dart`
Expected: 均 PASS。

### Step 6: 静态检查 + 提交

Run: `C:\flutter\bin\flutter.bat analyze`
Expected: `No issues found!`

```bash
git add lib/modules/game/game_home.dart lib/modules/game/game_detail_page.dart test/modules/game/game_home_test.dart test/modules/game/game_detail_page_test.dart
git commit -m "feat(game): cover hero transition when opening a detail page"
```

---

## 手动验证（合并前，由用户执行）

在 Windows 上运行应用：
1. 轻小说：探索/收藏 tab 点卡片 → 封面从卡片飞到详情页封面（淡入）。
2. 轻小说搜索：点结果 → 同样有封面飞行。
3. 游戏：点卡片 → 封面飞到详情页封面（注意游戏卡片 3:2 横图 → 详情 100×132 竖图，比例会变化）。
4. 返回时封面飞回原位。
5. 切换轻小说 tab 不报 `Hero` tag 冲突。

## 自查记录（Self-Review）

- **Spec 覆盖**：轻小说（卡片/首页 HeroMode/详情/搜索）→ Task 1；游戏（卡片/详情）→ Task 2；tag 规则见 Global Constraints。
- **类型一致性**：`NovelCard.heroTag`/`GameCard.heroTag` 均为 `String?`；`Hero(tag: ...)` 接收 `String`；tag 拼接两侧一致（卡片用 `_sourceId`/`sourceKey`，详情用 `widget.sourceKey`/`sourceKey`）。
- **占位符**：无 TBD/TODO；每步给出完整代码与命令。
- **注意**：`NovelHomePage` 由 `const DefaultTabController` 改为非 const（需要 `Builder` 取 controller）；`novel_search.dart` 的 import 已含 `smooth_route.dart`，无需新增。
