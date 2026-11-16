import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/metadata/metadata_service.dart';
import 'package:libiko/core/models/work.dart';
import 'package:libiko/core/theme/app_theme.dart';
import 'package:libiko/modules/anime/anime_providers.dart';
import 'package:libiko/modules/anime/anime_search.dart';

Work _work(String title) => Work(
    id: title,
    sourceId: 'fake',
    sourceName: 'fake',
    type: WorkType.anime,
    title: title);

class _SearchService extends MetadataService {
  final requests = <String, Completer<List<Work>>>{};
  @override
  Future<List<Work>> search(String keyword, {int page = 1}) =>
      requests.putIfAbsent(keyword, Completer<List<Work>>.new).future;
}

Widget _app(_SearchService service, {ThemeData? theme, double scale = 1}) =>
    ProviderScope(
      overrides: [metadataServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
          theme: theme ?? buildAppTheme(),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: const AnimeSearchPage(initialKeyword: '旧关键词')),
    );

void main() {
  testWidgets('a late older search cannot replace the latest results',
      (tester) async {
    final service = _SearchService();
    await tester.pumpWidget(_app(service));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '新关键词');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    service.requests['新关键词']!.complete([_work('最新搜索结果')]);
    await tester.pumpAndSettle();
    expect(find.text('最新搜索结果'), findsOneWidget);
    service.requests['旧关键词']!.complete([_work('过时搜索结果')]);
    await tester.pumpAndSettle();
    expect(find.text('最新搜索结果'), findsOneWidget);
    expect(find.text('过时搜索结果'), findsNothing);
  });

  for (final dark in [false, true]) {
    testWidgets(
        '320px ${dark ? "dark" : "light"} search supports enlarged text and clear input',
        (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = _SearchService();
      await tester.pumpWidget(_app(service,
          theme: dark ? buildAppDarkTheme() : buildAppTheme(), scale: 1.8));
      await tester.pump();
      service.requests['旧关键词']!.complete([_work('足够长的搜索结果用于验证标题换行')]);
      await tester.pumpAndSettle();
      expect(find.text('1 个结果'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('清空输入'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty);
      expect(find.text('足够长的搜索结果用于验证标题换行'), findsOneWidget);
      expect(find.byTooltip('清空输入'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
