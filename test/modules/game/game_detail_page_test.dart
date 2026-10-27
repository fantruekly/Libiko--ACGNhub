import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/game/models.dart';
import 'package:libiko/core/theme/app_theme.dart';
import 'package:libiko/modules/game/game_detail_page.dart';
import 'package:libiko/modules/game/game_providers.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
        '320px ${dark ? "dark" : "light"} game detail supports enlarged text',
        (tester) async {
      tester.view.physicalSize = const Size(320, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            gameDetailProvider(('galgamezywz', 'responsive')).overrideWith(
                (ref) async => const GameDetail(
                    game: Game(
                        id: 'responsive',
                        title: '很长的游戏标题用于验证窄屏排版',
                        tags: ['汉化', 'PC']),
                    sourceUrl: 'https://example.com/game',
                    paragraphs: ['一段游戏介绍。'],
                    platform: 'Windows 与 Android')),
          ],
          child: MaterialApp(
              theme: dark ? buildAppDarkTheme() : buildAppTheme(),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(1.6)),
                  child: child!),
              home: const GameDetailPage(
                  sourceKey: 'galgamezywz',
                  gameId: 'responsive',
                  title: '测试游戏'))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('在原站打开'), findsOneWidget);
    });
  }
  testWidgets('renders title, meta, tags, paragraphs and source button',
      (tester) async {
    final detail = GameDetail(
      game: Game(
        id: '1207',
        title: '金辉恋曲四重奏',
        category: '玩家热评游戏',
        tags: const ['汉化', 'PC'],
        publishedAt: DateTime(2026, 9, 11),
        views: 4300,
      ),
      size: '14.3GB',
      platform: 'PC+安卓直装',
      updatedAt: DateTime(2026, 9, 12),
      paragraphs: const ['第一段简介。', '第二段简介。'],
      sourceUrl: 'https://game.galgamezywz.org/game/1207',
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        gameDetailProvider(('galgamezywz', '1207'))
            .overrideWith((ref) async => detail),
      ],
      child: const MaterialApp(
        home: GameDetailPage(
            sourceKey: 'galgamezywz', gameId: '1207', title: '金辉恋曲四重奏'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('金辉恋曲四重奏'), findsWidgets);
    expect(find.text('玩家热评游戏'), findsOneWidget);
    expect(find.text('汉化'), findsOneWidget);
    expect(find.text('PC'), findsOneWidget);
    expect(find.text('14.3GB'), findsOneWidget);
    expect(find.text('PC+安卓直装'), findsOneWidget);
    expect(find.text('第一段简介。'), findsOneWidget);
    expect(find.text('第二段简介。'), findsOneWidget);
    expect(find.text('简介'), findsOneWidget);
    expect(find.text('在原站打开'), findsOneWidget);
    expect(find.byTooltip('在原站打开'), findsNothing);
    expect(find.text('数据来源 game.galgamezywz.org'), findsOneWidget);

    final hero = tester.widget<Hero>(find.byType(Hero));
    expect(hero.tag, 'game_galgamezywz_1207');
  });

  testWidgets('shows a retry action on error', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        gameDetailProvider(('galgamezywz', '404'))
            .overrideWith((ref) async => throw Exception('boom')),
      ],
      child: const MaterialApp(
        home: GameDetailPage(
            sourceKey: 'galgamezywz', gameId: '404', title: '加载失败'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('加载失败'), findsWidgets);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('GameDetailPage shows the cover Hero while loading',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        gameDetailProvider(('galgamezywz', '1207'))
            .overrideWith((ref) => Completer<GameDetail>().future),
      ],
      child: const MaterialApp(
        home: GameDetailPage(
            sourceKey: 'galgamezywz', gameId: '1207', title: '金辉恋曲四重奏'),
      ),
    ));
    await tester.pump();

    final hero = tester.widget<Hero>(find.byType(Hero));
    expect(hero.tag, 'game_galgamezywz_1207');
  });
}
