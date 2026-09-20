import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/game/game_source.dart';
import 'package:libiko/core/game/models.dart';
import 'package:libiko/modules/game/game_home.dart';
import 'package:libiko/modules/game/game_providers.dart';

class _FakeSource implements GameSource {
  @override
  String get id => 'galgamezywz';
  @override
  String get name => 'galgame大玩家';
  @override
  String get baseUrl => 'https://fake';
  @override
  List<GameBrowseOption> get browseOptions => const [
        GameBrowseOption(key: 'latest', label: '最近更新'),
        GameBrowseOption(key: 'wanjiareping', label: '玩家热评'),
      ];
  @override
  Future<GameList> browse(String optionKey, {int page = 1}) async => GameList(
        items: [Game(id: '$optionKey-$page', title: '游戏$optionKey$page')],
        page: page,
        hasMore: optionKey == 'latest' && page == 1,
      );
  @override
  Future<GameDetail> detail(String id) async =>
      GameDetail(game: Game(id: id, title: id), sourceUrl: 'https://fake/$id');
  @override
  Future<List<Game>> search(String keyword) async => const [];
}

class _NekoFakeSource implements GameSource {
  @override
  String get id => 'nekogal';
  @override
  String get name => 'NekoGAL';
  @override
  String get baseUrl => 'https://fake';
  @override
  List<GameBrowseOption> get browseOptions =>
      const [GameBrowseOption(key: 'pcgame', label: 'PC资源')];
  @override
  Future<GameList> browse(String optionKey, {int page = 1}) async => GameList(
        items: [Game(id: '$optionKey-$page', title: '游戏$optionKey$page')],
        page: page,
        hasMore: false,
      );
  @override
  Future<GameDetail> detail(String id) async =>
      GameDetail(game: Game(id: id, title: id), sourceUrl: 'https://fake/$id');
  @override
  Future<List<Game>> search(String keyword) async => const [];
}

void main() {
  testWidgets('renders source/section chips, grid and pager', (tester) async {
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

    expect(find.text('galgame大玩家'), findsOneWidget);
    expect(find.text('最近更新'), findsOneWidget);
    expect(find.text('玩家热评'), findsOneWidget);
    expect(find.text('游戏latest1'), findsOneWidget);
    expect(find.text('第 1 页'), findsOneWidget);

    await tester.tap(find.byTooltip('下一页'));
    await tester.pumpAndSettle();

    expect(find.text('第 2 页'), findsOneWidget);
    expect(find.text('游戏latest2'), findsOneWidget);
    // 第 2 页 hasMore=false → 下一页禁用
    final next = tester.widget<InkWell>(find.descendant(
      of: find.byTooltip('下一页'),
      matching: find.byType(InkWell),
    ));
    expect(next.onTap, isNull);
  });

  testWidgets('grid uses 4 columns with 3:2 covers', (tester) async {
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

    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 4);

    final surfaceWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final expectedCellWidth = (surfaceWidth - 32 - 16 * 3) / 4;
    final expectedExtent = expectedCellWidth * 2 / 3 + 44;
    expect(delegate.mainAxisExtent, closeTo(expectedExtent, 0.5));

    final card = find.byType(GameCard).first;
    expect(tester.getSize(card).width, closeTo(expectedCellWidth, 0.5));

    final cover = tester.getSize(find
        .descendant(of: card, matching: find.byType(ClipRRect))
        .first);
    expect(cover.width / cover.height, closeTo(1.5, 0.01));
  });

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

  testWidgets('switching to the second source shows its sections',
      (tester) async {
    final container = ProviderContainer(overrides: [
      gameSourceManagerProvider.overrideWithValue(
          GameSourceManager(sources: [_FakeSource(), _NekoFakeSource()])),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: GameHomePage())),
    ));
    await tester.pumpAndSettle();

    expect(find.text('galgame大玩家'), findsOneWidget);
    expect(find.text('NekoGAL'), findsOneWidget);
    expect(find.text('最近更新'), findsOneWidget);

    await tester.tap(find.text('NekoGAL'));
    await tester.pumpAndSettle();

    expect(find.text('PC资源'), findsOneWidget);
    expect(find.text('最近更新'), findsNothing);
  });

  testWidgets('swiping past the last section moves to the next source',
      (tester) async {
    final container = ProviderContainer(overrides: [
      gameSourceManagerProvider.overrideWithValue(
          GameSourceManager(sources: [_FakeSource(), _NekoFakeSource()])),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: GameHomePage())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('游戏latest1'), findsOneWidget);

    // 前进到第二个选项
    await tester.fling(find.byType(GridView), const Offset(-300, 0), 1200);
    await tester.pumpAndSettle();
    expect(find.text('游戏wanjiareping1'), findsOneWidget);

    // 已是最后一个选项，继续前进 -> 跨到下一个源的首个选项
    await tester.fling(find.byType(GridView), const Offset(-300, 0), 1200);
    await tester.pumpAndSettle();
    expect(find.text('PC资源'), findsOneWidget);
    expect(find.text('游戏pcgame1'), findsOneWidget);
  });
}
