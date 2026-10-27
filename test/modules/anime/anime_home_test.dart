import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/metadata/metadata_provider.dart';
import 'package:libiko/core/metadata/metadata_service.dart';
import 'package:libiko/core/models/work.dart';
import 'package:libiko/core/models/watch_record.dart';
import 'package:libiko/core/services/watch_history.dart';
import 'package:libiko/core/theme/app_theme.dart';
import 'package:libiko/core/widgets/work_card.dart';
import 'package:libiko/core/widgets/tab_strip.dart';
import 'package:libiko/modules/anime/anime_home.dart';
import 'package:libiko/modules/anime/anime_providers.dart';
import 'package:libiko/modules/anime/anime_home_feature.dart';
import 'package:libiko/modules/anime/anime_detail_page.dart';

class _History extends WatchHistoryNotifier {
  _History([this.records = const []]);
  final List<WatchRecord> records;
  @override
  List<WatchRecord> build() => records;
}

class _RouteObserver extends NavigatorObserver {
  Route<dynamic>? latest;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    latest = route;
  }
}

class _NextPageService extends MetadataService {
  _NextPageService(this.works);
  final List<Work> works;
  final pages = <int>[];
  @override
  Future<List<Work>> feed(AnimeFeed feed, {int page = 1}) async {
    pages.add(page);
    return works;
  }
}

Work _work(String id, {String? title, String source = 'bangumi'}) => Work(
    id: id,
    sourceId: source,
    sourceName: source,
    type: WorkType.anime,
    title: title ?? '作品 $id',
    summary: '来自真实条目的作品简介');

Widget _page(
        {List<Work> works = const [],
        List<Work>? seasonWorks,
        List<WatchRecord> history = const [],
        double scale = 1,
        ThemeData? theme,
        NavigatorObserver? observer,
        MetadataService? service}) =>
    ProviderScope(
        overrides: [
          watchHistoryProvider.overrideWith(() => _History(history)),
          animeFeedProvider(AnimeFeed.trending)
              .overrideWith((ref) async => works),
          animeFeedProvider(AnimeFeed.season)
              .overrideWith((ref) async => seasonWorks ?? works),
          if (service != null)
            metadataServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
            theme: theme ?? buildAppTheme(),
            navigatorObservers: observer == null ? [] : [observer],
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: const Scaffold(body: AnimeHomePage())));

void main() {
  testWidgets('anime opens trending first and can switch to the season feed',
      (tester) async {
    await tester.pumpWidget(_page(
      works: [_work('trending', title: '默认热门作品')],
      seasonWorks: [_work('season', title: '本季作品')],
    ));
    await tester.pumpAndSettle();

    final labels = tester
        .widgetList<Text>(find.descendant(
            of: find.byType(TabStrip), matching: find.byType(Text)))
        .map((t) => t.data)
        .toList();
    expect(labels, ['热门推荐', '本季新番', '追番', '历史']);
    final tabs = DefaultTabController.of(tester.element(find.byType(TabStrip)));
    expect(tabs.index, 0);
    expect(tester.widget<WorkCard>(find.byType(WorkCard).first).work.id,
        'trending');
    await tester.tap(find.descendant(
        of: find.byType(TabStrip), matching: find.text('本季新番')));
    await tester.pumpAndSettle();
    expect(tabs.index, 1);
    expect(find.text('本季作品'), findsOneWidget);
  });

  testWidgets(
      'catalog starts directly with work cards and short pages do not spin',
      (tester) async {
    final work = _work('real', title: '真实的新番标题');
    await tester.pumpWidget(_page(works: [work, work]));
    await tester.pumpAndSettle();
    expect(find.text('作品速览'), findsNothing);
    expect(find.text('来自真实条目的作品简介'), findsNothing);
    expect(find.text('查看详情'), findsNothing);
    expect(find.byType(WorkCard), findsOneWidget);
    final gridTop = tester.getTopLeft(find.byType(WorkCard)).dy;
    expect(gridTop, lessThan(180));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('加载更多'), findsNothing);
    expect(find.text('继续观看'), findsNothing);
  });

  testWidgets('empty catalog keeps the empty state', (tester) async {
    await tester.pumpWidget(_page());
    await tester.pumpAndSettle();
    expect(find.text('暂无内容'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
      'pagination deduplicates overlapping pages and stops after a short response',
      (tester) async {
    final service = _NextPageService([_work('19'), _work('20')]);
    await tester.pumpWidget(_page(
        works: [for (var i = 0; i < 20; i++) _work('$i')], service: service));
    await tester.pumpAndSettle();
    await tester.drag(
        find.byType(CustomScrollView).first, const Offset(0, -5000));
    await tester.pumpAndSettle();
    final grid = tester.widget<SliverGrid>(find.byType(SliverGrid).first);
    expect(grid.delegate.estimatedChildCount, 21);
    expect(service.pages, [2]);
    expect(find.text('加载更多'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
      'continue watching keeps two newest unfinished records and resumes the saved entry',
      (tester) async {
    WatchRecord record(String id, int day,
            {bool done = false, bool deleted = false}) =>
        WatchRecord(
            work: _work(id),
            episodeTitle: '第 3 集',
            episodeIndex: 2,
            watchedAt: DateTime(2026, 1, day),
            completed: done,
            deleted: deleted,
            positionMs: 60000,
            durationMs: 120000);
    final newest = record('newest', 5);
    final observer = _RouteObserver();
    await tester.pumpWidget(_page(works: [
      _work('feed')
    ], history: [
      record('oldest', 1),
      record('deleted', 7, deleted: true),
      newest,
      record('finished', 6, done: true),
      record('second', 4),
    ], observer: observer));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('继续观看'));
    await tester.pumpAndSettle();
    final cards = tester
        .widgetList<AnimeResumeCard>(find.byType(AnimeResumeCard))
        .toList();
    expect(cards.map((card) => card.record.work.id), ['newest', 'second']);
    final scroll = find.byType(CustomScrollView).first;
    await tester.drag(scroll, const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AnimeResumeCard).first);
    final route = observer.latest! as PageRouteBuilder;
    final page = route.pageBuilder(
        tester.element(find.byType(AnimeHomePage)),
        const AlwaysStoppedAnimation(1),
        const AlwaysStoppedAnimation(0)) as AnimeDetailPage;
    expect(page.resumeRecord, same(newest));
    expect(page.autoResume, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  for (final dark in [false, true]) {
    testWidgets(
        '320px ${dark ? "dark" : "light"} layout supports enlarged text without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_page(works: [
        for (var i = 0; i < 4; i++) _work('$i', title: '很长的动漫作品名称用于验证换行')
      ], history: [
        WatchRecord(
            work: _work('recent'),
            episodeTitle: '第三集',
            episodeIndex: 2,
            watchedAt: DateTime(2026),
            positionMs: 1000,
            durationMs: 10000)
      ], scale: 1.8, theme: dark ? buildAppDarkTheme() : buildAppTheme()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(
          find.byType(CustomScrollView).first, const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final grid = tester.widget<SliverGrid>(find.byType(SliverGrid).first);
      expect(
          (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
              .crossAxisCount,
          2);
    });
  }
}
