import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:acgnhub/core/novel/models.dart';
import 'package:acgnhub/core/novel/novel_source.dart';
import 'package:acgnhub/core/storage/database.dart';
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
  List<NovelBrowseGroup> get browseGroups => const [
        NovelBrowseGroup(label: '排行', options: [
          NovelBrowseOption(key: 'allvisit', label: '人气榜'),
        ]),
      ];
  @override
  Future<NovelList> browse(String optionKey, {int page = 1}) async =>
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
      const NovelChapter(title: 't', blocks: [NovelText('c')]);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppDatabase.init();
  });

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
    // The 推荐 -> 排行 switch must actually run the slide transition
    // (an outgoing + an incoming child), not silently swap.
    expect(find.byType(SlideTransition), findsNWidgets(2));
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    expect(find.text('第 1 页'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
