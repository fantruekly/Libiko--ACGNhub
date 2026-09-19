import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/comic/comic_source.dart';
import 'package:libiko/core/comic/models.dart';
import 'package:libiko/core/storage/database.dart';
import 'package:libiko/modules/comic/comic_detail_page.dart';
import 'package:libiko/modules/comic/comic_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _source = ComicSource(
  name: '需要登录的源',
  key: 'needlogin',
  version: '1.0.0',
  hasLogin: true,
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppDatabase.init();
  });

  testWidgets('shows a login prompt when the source needs login',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        comicSourcesProvider.overrideWith((ref) async => [_source]),
        comicLoginProvider('needlogin').overrideWith((ref) async => false),
        comicDetailProvider(('needlogin', '1'))
            .overrideWith((ref) async => throw Exception('need login')),
      ],
      child: const MaterialApp(
        home: ComicDetailPage(
            sourceKey: 'needlogin', comicId: '1', title: '测试漫画'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('该源需要登录'), findsOneWidget);
    expect(find.text('去登录'), findsOneWidget);
    expect(find.text('加载失败'), findsNothing);
  });

  testWidgets(
      'shows a login prompt when a login-capable source returns empty details',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        comicSourcesProvider.overrideWith((ref) async => [_source]),
        comicLoginProvider('needlogin').overrideWith((ref) async => false),
        comicDetailProvider(('needlogin', '1')).overrideWith(
            (ref) async => const ComicDetails(id: '1', title: '')),
      ],
      child: const MaterialApp(
        home: ComicDetailPage(
            sourceKey: 'needlogin', comicId: '1', title: '测试漫画'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('该源需要登录'), findsOneWidget);
    expect(find.text('去登录'), findsOneWidget);
  });

  testWidgets('does not prompt when the details have usable content',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        comicSourcesProvider.overrideWith((ref) async => [_source]),
        comicLoginProvider('needlogin').overrideWith((ref) async => false),
        comicDetailProvider(('needlogin', '1')).overrideWith((ref) async =>
            const ComicDetails(
                id: '1', title: '有内容', chapters: {'1': '第一话'})),
      ],
      child: const MaterialApp(
        home: ComicDetailPage(
            sourceKey: 'needlogin', comicId: '1', title: '测试漫画'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('该源需要登录'), findsNothing);
    expect(find.text('去登录'), findsNothing);
  });
}
