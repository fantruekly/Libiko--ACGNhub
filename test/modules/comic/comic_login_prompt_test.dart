import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/comic/comic_source.dart';
import 'package:libiko/modules/comic/comic_detail_page.dart';
import 'package:libiko/modules/comic/comic_providers.dart';

const _source = ComicSource(
  name: '需要登录的源',
  key: 'needlogin',
  version: '1.0.0',
  hasLogin: true,
);

void main() {
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
}
