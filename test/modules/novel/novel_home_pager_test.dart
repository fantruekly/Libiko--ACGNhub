import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:acgnhub/core/novel/models.dart';
import 'package:acgnhub/core/novel/novel_source.dart';
import 'package:acgnhub/modules/novel/novel_home.dart';
import 'package:acgnhub/modules/novel/novel_providers.dart';

class _FakeSource extends NovelSource {
  @override
  String get id => 'linovelib';
  @override
  String get name => 'Fake';
  @override
  String get baseUrl => 'https://fake';
  @override
  Future<NovelHome> home() async => const NovelHome(sections: [
        NovelSection(title: 's', items: [Novel(id: '1', title: 'A')]),
      ]);
  @override
  Future<NovelList> browse(NovelBrowse browse, {int page = 1}) async =>
      NovelList(
        items: [for (var i = 0; i < 30; i++) Novel(id: '$i', title: 'Book$i')],
        page: page,
        hasMore: true,
      );
  @override
  Future<List<Novel>> search(String keyword, {int page = 1}) async => const [];
  @override
  Future<NovelDetail> detail(String id) async =>
      const NovelDetail(novel: Novel(id: 'x', title: 'x'), volumes: []);
  @override
  Future<NovelChapter> chapter(String novelId, String chapterId) async =>
      const NovelChapter(title: 't', content: 'c');
}

void main() {
  testWidgets('排行 pager lays out under the app outlined-button theme',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        novelSourceManagerProvider
            .overrideWithValue(NovelSourceManager(sources: [_FakeSource()])),
      ],
      child: MaterialApp(
        // Mirrors main.dart's global theme: an infinite minimum button size.
        // Without an explicit pager button width this triggers an endless
        // "RenderBox was not laid out" loop inside a Row.
        theme: ThemeData(
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),
        home: const Scaffold(body: NovelHomePage()),
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('排行'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('上一页'), findsOneWidget);
    expect(find.text('下一页'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
