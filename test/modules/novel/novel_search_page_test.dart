import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/theme/app_theme.dart';
import 'package:libiko/core/novel/models.dart';
import 'package:libiko/core/novel/novel_source.dart';
import 'package:libiko/modules/novel/novel_providers.dart';
import 'package:libiko/modules/novel/novel_search.dart';

class _FakeSource extends NovelSource {
  _FakeSource(this.results, {this.delay = Duration.zero, String id = 'fake'})
      : _id = id;
  final List<Novel> results;
  final Duration delay;
  final String _id;
  @override
  String get id => _id;
  @override
  String get name => _id;
  @override
  String get baseUrl => 'https://x';
  @override
  List<NovelBrowseGroup> get browseGroups => const [];
  @override
  Future<NovelHome> home() async => const NovelHome(sections: []);
  @override
  Future<NovelList> browse(String optionKey, {int page = 1}) async =>
      NovelList(items: const [], page: page, hasMore: false);
  @override
  Future<List<Novel>> search(String keyword, {int page = 1}) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return results;
  }

  @override
  Future<NovelDetail> detail(String id) async =>
      const NovelDetail(novel: Novel(id: 'x', title: 'x'), volumes: []);
  @override
  Future<NovelChapter> chapter(String novelId, String chapterId) async =>
      const NovelChapter(title: 't', blocks: []);
}

Widget _app(List<Novel> results, {ThemeData? theme}) => ProviderScope(
      overrides: [
        novelSourceManagerProvider.overrideWithValue(
            NovelSourceManager(sources: [_FakeSource(results)])),
      ],
      child: MaterialApp(
          theme: theme, home: const NovelSearchPage(initialKeyword: '关键词')),
    );

void main() {
  for (final dark in [false, true]) {
    testWidgets(
        '320px ${dark ? "dark" : "light"} search preserves metadata with enlarged text',
        (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(_app(const [
        Novel(
            id: '1',
            title: '测试小说的长标题',
            author: '小说作者',
            extra: {'version': '典藏版'})
      ], theme: dark ? buildAppDarkTheme() : buildAppTheme()));
      await tester.pumpAndSettle();
      expect(find.text('来源：fake'), findsOneWidget);
      expect(find.text('作者：小说作者'), findsOneWidget);
      expect(find.text('版本：典藏版'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('renders results from the sources', (tester) async {
    await tester.pumpWidget(_app(const [Novel(id: '1', title: '结果书')]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('结果书'), findsOneWidget);
  });

  testWidgets('shows a prompt before searching', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: NovelSearchPage()),
    ));
    expect(find.text('输入关键词搜索轻小说'), findsOneWidget);
  });

  testWidgets('shows empty message when there are no results', (tester) async {
    await tester.pumpWidget(_app(const []));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('没有找到轻小说'), findsOneWidget);
  });

  testWidgets('shows fast source results without waiting for a slow source',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        novelSourceManagerProvider.overrideWithValue(NovelSourceManager(
          sources: [
            _FakeSource(const [Novel(id: '1', title: '快源结果')], id: 'fast'),
            _FakeSource(const [Novel(id: '2', title: '慢源结果')],
                id: 'slow', delay: const Duration(seconds: 5)),
          ],
        )),
      ],
      child: MaterialApp(home: const NovelSearchPage(initialKeyword: '关键词')),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('快源结果'), findsOneWidget);
    expect(find.text('慢源结果'), findsNothing);

    await tester.pump(const Duration(seconds: 6));
    expect(find.text('慢源结果'), findsOneWidget);
  });
  testWidgets('same-title results expose both sources and authors',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(overrides: [
      novelSourceManagerProvider.overrideWithValue(NovelSourceManager(sources: [
        _FakeSource(const [Novel(id: '1', title: '同名作品', author: '作者甲')],
            id: 'alpha'),
        _FakeSource(const [Novel(id: '1', title: '同名作品', author: '作者乙')],
            id: 'beta'),
      ])),
    ], child: const MaterialApp(home: NovelSearchPage(initialKeyword: '同名'))));
    await tester.pumpAndSettle();
    expect(find.text('同名作品'), findsNWidgets(2));
    expect(find.text('来源：alpha'), findsOneWidget);
    expect(find.text('来源：beta'), findsOneWidget);
    expect(find.text('作者：作者甲'), findsOneWidget);
    expect(find.text('作者：作者乙'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
