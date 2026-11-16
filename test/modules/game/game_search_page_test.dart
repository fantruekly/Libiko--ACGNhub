import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/theme/app_theme.dart';
import 'package:libiko/core/game/game_source.dart';
import 'package:libiko/core/game/models.dart';
import 'package:libiko/modules/game/game_providers.dart';
import 'package:libiko/modules/game/game_search.dart';

class _FakeSource implements GameSource {
  _FakeSource(this.results, {this.delay = Duration.zero, String id = 'fake'})
      : _id = id;
  final List<Game> results;
  final Duration delay;
  final String _id;
  @override
  String get id => _id;
  @override
  String get name => _id;
  @override
  String get baseUrl => 'https://x';
  @override
  List<GameBrowseOption> get browseOptions => const [];
  @override
  Future<GameList> browse(String optionKey, {int page = 1}) async =>
      GameList(items: const [], page: page, hasMore: false);
  @override
  Future<GameDetail> detail(String id) async =>
      GameDetail(game: Game(id: id, title: id), sourceUrl: 'https://x/$id');
  @override
  Future<List<Game>> search(String keyword) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return results;
  }
}

Widget _app(List<Game> results, {ThemeData? theme}) => ProviderScope(
      overrides: [
        gameSourceManagerProvider.overrideWithValue(
            GameSourceManager(sources: [_FakeSource(results)])),
      ],
      child: MaterialApp(
          theme: theme, home: const GameSearchPage(initialKeyword: '关键词')),
    );

void main() {
  for (final dark in [false, true]) {
    testWidgets(
        '320px ${dark ? "dark" : "light"} search uses a readable card with enlarged text',
        (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(_app(const [
        Game(id: '1', title: '测试游戏的长标题', extra: {'version': '典藏版'})
      ], theme: dark ? buildAppDarkTheme() : buildAppTheme()));
      await tester.pumpAndSettle();
      expect(find.text('来源：fake'), findsOneWidget);
      expect(find.text('版本：典藏版'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('renders results from the sources', (tester) async {
    await tester.pumpWidget(_app(const [Game(id: '1', title: '结果游戏')]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('结果游戏'), findsOneWidget);
  });

  testWidgets('shows a prompt before searching', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: GameSearchPage()),
    ));
    expect(find.text('输入关键词搜索游戏'), findsOneWidget);
  });

  testWidgets('shows empty message when there are no results', (tester) async {
    await tester.pumpWidget(_app(const []));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('没有找到游戏'), findsOneWidget);
  });

  testWidgets('shows fast source results without waiting for a slow source',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        gameSourceManagerProvider.overrideWithValue(GameSourceManager(
          sources: [
            _FakeSource(const [Game(id: '1', title: '快源结果')], id: 'fast'),
            _FakeSource(const [Game(id: '2', title: '慢源结果')],
                id: 'slow', delay: const Duration(seconds: 5)),
          ],
        )),
      ],
      child: MaterialApp(home: const GameSearchPage(initialKeyword: '关键词')),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('快源结果'), findsOneWidget);
    expect(find.text('慢源结果'), findsNothing);

    await tester.pump(const Duration(seconds: 6));
    expect(find.text('慢源结果'), findsOneWidget);
  });
  testWidgets('same-title versions retain separate source cards',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(overrides: [
      gameSourceManagerProvider.overrideWithValue(GameSourceManager(sources: [
        _FakeSource(const [
          Game(id: '1', title: '同名游戏', extra: {'version': '原版'})
        ], id: 'alpha'),
        _FakeSource(const [
          Game(id: '1', title: '同名游戏', extra: {'version': '重制版'})
        ], id: 'beta'),
      ])),
    ], child: const MaterialApp(home: GameSearchPage(initialKeyword: '同名'))));
    await tester.pumpAndSettle();
    expect(find.text('同名游戏'), findsNWidgets(2));
    expect(find.text('来源：alpha'), findsOneWidget);
    expect(find.text('来源：beta'), findsOneWidget);
    expect(find.text('版本：原版'), findsOneWidget);
    expect(find.text('版本：重制版'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
