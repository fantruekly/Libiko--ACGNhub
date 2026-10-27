import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:libiko/core/comic/comic_history.dart';
import 'package:libiko/core/models/watch_record.dart';
import 'package:libiko/core/models/work.dart';
import 'package:libiko/core/novel/models.dart';
import 'package:libiko/core/novel/novel_history.dart';
import 'package:libiko/core/services/recent_activity.dart';
import 'package:libiko/core/storage/database.dart';
import 'package:libiko/modules/novel/novel_providers.dart';
import 'package:libiko/modules/novel/novel_reader_page.dart';
import 'package:libiko/shell/recent_activity_page.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppDatabase.init();
  });

  test(
      'recent activity orders mixed content and keeps source-qualified identities',
      () {
    final records = buildRecentActivity([
      WatchRecord(
          work: const Work(
              id: '1',
              sourceId: 'm',
              sourceName: 'M',
              type: WorkType.anime,
              title: '动漫'),
          episodeTitle: '1',
          episodeIndex: 0,
          watchedAt: DateTime(2026, 1, 1)),
    ], [
      ComicHistoryEntry(
          sourceKey: 's',
          comicId: '1',
          title: '漫画',
          chapterId: 'c',
          chapterTitle: '章',
          page: 2,
          readAt: DateTime(2026, 1, 3)),
    ], [
      NovelHistoryEntry(
          sourceKey: 's',
          novelId: '1',
          title: '小说',
          chapterId: 'c',
          chapterTitle: '章',
          updatedAt: DateTime(2026, 1, 2)),
    ]);
    expect(records.map((r) => r.title), ['漫画', '小说', '动漫']);
    expect(records.map((r) => r.id).toSet().length, 3);
  });

  testWidgets('empty state explains how recent activity appears',
      (tester) async {
    await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: RecentActivityPage())));
    expect(find.text('还没有记录，开始观看或阅读后会显示在这里'), findsOneWidget);
  });

  testWidgets('history cards wrap at narrow widths and filters still work',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          recentActivityProvider.overrideWithValue([
            RecentActivity(
                type: WorkType.anime,
                id: 'test',
                title: '很长的动漫标题用于验证历史卡片换行',
                subtitle: '第十二集 · 12 分钟',
                updatedAt: DateTime(2026, 10, 27))
          ]),
        ],
        child: MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.8)),
                child: child!),
            home: const RecentActivityPage())));
    await tester.pumpAndSettle();
    expect(find.text('第十二集 · 12 分钟'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('漫画'));
    await tester.pumpAndSettle();
    expect(find.text('还没有记录，开始观看或阅读后会显示在这里'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening a recent novel resumes its saved chapter',
      (tester) async {
    await NovelHistoryManager().record(NovelHistoryEntry(
        sourceKey: 'linovelib',
        novelId: 'n',
        title: '我的小说',
        chapterId: 'ch2',
        chapterTitle: '第二章',
        updatedAt: DateTime.now()));
    final container = ProviderContainer(overrides: [
      novelChapterProvider(('linovelib', 'n', 'ch2')).overrideWith(
          (ref) async =>
              const NovelChapter(title: '第二章', blocks: [NovelText('续读正文')])),
      novelDetailProvider(('linovelib', 'n')).overrideWith((ref) async =>
          const NovelDetail(novel: Novel(id: 'n', title: '我的小说'), volumes: [])),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RecentActivityPage())));
    await tester.tap(find.byKey(const ValueKey('novel:linovelib:n')));
    await tester.pumpAndSettle();
    expect(find.byType(NovelReaderPage), findsOneWidget);
    expect(find.text('续读正文'), findsOneWidget);
    expect(
        tester.widget<NovelReaderPage>(find.byType(NovelReaderPage)).chapterId,
        'ch2');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    container.dispose();
    await tester.pump();
  });
}
