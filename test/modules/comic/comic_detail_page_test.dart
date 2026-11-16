import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/comic/comic_source.dart';
import 'package:libiko/core/comic/models.dart';
import 'package:libiko/core/storage/database.dart';
import 'package:libiko/core/theme/app_theme.dart';
import 'package:libiko/modules/comic/comic_detail_page.dart';
import 'package:libiko/modules/comic/comic_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _source = ComicSource(name: 'X', key: 'x', version: '1.0.0');
const _longTag = '这是一个非常非常非常非常非常非常长的标签内容';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppDatabase.init();
  });

  for (final dark in [false, true]) {
    testWidgets(
        '320px ${dark ? "dark" : "light"} comic detail supports enlarged text',
        (tester) async {
      tester.view.physicalSize = const Size(320, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            comicSourcesProvider.overrideWith((ref) async => [_source]),
            comicLoginProvider('x').overrideWith((ref) async => false),
            comicDetailProvider(('x', '1')).overrideWith((ref) async =>
                const ComicDetails(
                    id: '1',
                    title: '一个很长的漫画作品标题用于验证窄屏',
                    tags: [_longTag],
                    description: '一段真实的漫画简介。',
                    chapters: {'1': '第一话'})),
          ],
          child: MaterialApp(
              theme: dark ? buildAppDarkTheme() : buildAppTheme(),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(1.6)),
                  child: child!),
              home: const ComicDetailPage(
                  sourceKey: 'x', comicId: '1', title: '测试漫画'))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('收藏'), findsOneWidget);
    });
  }

  testWidgets('over-long tags are ellipsized to a single line', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        comicSourcesProvider.overrideWith((ref) async => [_source]),
        comicLoginProvider('x').overrideWith((ref) async => false),
        comicDetailProvider(('x', '1')).overrideWith((ref) async =>
            const ComicDetails(id: '1', title: '有内容', tags: [_longTag])),
      ],
      child: const MaterialApp(
        home: ComicDetailPage(sourceKey: 'x', comicId: '1', title: '测试漫画'),
      ),
    ));
    await tester.pumpAndSettle();

    final tag = tester.widget<Text>(find.text(_longTag));
    expect(tag.maxLines, 1);
    expect(tag.overflow, TextOverflow.ellipsis);
  });
}
