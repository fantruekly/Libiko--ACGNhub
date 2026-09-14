import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acgnhub/core/novel/models.dart';
import 'package:acgnhub/core/novel/novel_favorite.dart';
import 'package:acgnhub/core/novel/novel_history.dart';
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
  List<NovelBrowseGroup> get browseGroups => const [];
  @override
  Future<NovelHome> home() async => const NovelHome(sections: []);
  @override
  Future<NovelList> browse(String optionKey, {int page = 1}) async =>
      NovelList(items: const [], page: page, hasMore: false);
  @override
  Future<List<Novel>> search(String keyword, {int page = 1}) async => const [];
  @override
  Future<NovelDetail> detail(String id) async =>
      const NovelDetail(novel: Novel(id: 'x', title: 'x'), volumes: []);
  @override
  Future<NovelChapter> chapter(String novelId, String chapterId) async =>
      const NovelChapter(title: 't', blocks: []);
}

class _FavNotifier extends NovelFavoritesNotifier {
  @override
  List<NovelFavorite> build() => [
        NovelFavorite(
          sourceKey: 'linovelib',
          novelId: '1',
          title: '收藏的书',
          addedAt: DateTime.fromMillisecondsSinceEpoch(1),
        ),
      ];
}

class _HistNotifier extends NovelHistoryNotifier {
  @override
  List<NovelHistoryEntry> build() => [
        NovelHistoryEntry(
          sourceKey: 'linovelib',
          novelId: '1',
          title: '收藏的书',
          chapterId: 'c1',
          chapterTitle: '第一章',
          updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
        ),
      ];
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppDatabase.init();
  });

  testWidgets('收藏 and 历史 tabs render their data', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        novelSourceManagerProvider
            .overrideWithValue(NovelSourceManager(sources: [_FakeSource()])),
        novelFavoritesProvider.overrideWith(_FavNotifier.new),
        novelHistoryProvider.overrideWith(_HistNotifier.new),
      ],
      child: const MaterialApp(home: Scaffold(body: NovelHomePage())),
    ));
    await tester.pump();

    await tester.tap(find.text('收藏'));
    await tester.pumpAndSettle();
    expect(find.text('收藏的书'), findsOneWidget);
    expect(find.text('还没有收藏'), findsNothing);

    await tester.tap(find.text('历史'));
    await tester.pumpAndSettle();
    expect(find.text('读到 第一章'), findsOneWidget);
    expect(find.text('清空历史'), findsOneWidget);
  });

  testWidgets('收藏 and 历史 tabs show empty states', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        novelSourceManagerProvider
            .overrideWithValue(NovelSourceManager(sources: [_FakeSource()])),
      ],
      child: const MaterialApp(home: Scaffold(body: NovelHomePage())),
    ));
    await tester.pump();

    await tester.tap(find.text('收藏'));
    await tester.pumpAndSettle();
    expect(find.text('还没有收藏'), findsOneWidget);

    await tester.tap(find.text('历史'));
    await tester.pumpAndSettle();
    expect(find.text('还没有阅读记录'), findsOneWidget);
  });
}
