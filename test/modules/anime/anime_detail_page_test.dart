import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:libiko/core/metadata/metadata_provider.dart';
import 'package:libiko/core/metadata/metadata_service.dart';
import 'package:libiko/core/models/work.dart';
import 'package:libiko/core/models/watch_record.dart';
import 'package:libiko/core/services/watch_history.dart';
import 'package:libiko/core/storage/database.dart';
import 'package:libiko/core/theme/app_theme.dart';
import 'package:libiko/core/video/cancellation.dart';
import 'package:libiko/core/video/video_source.dart';
import 'package:libiko/core/video/video_sources.dart';
import 'package:libiko/core/widgets/button_grid.dart';
import 'package:libiko/core/widgets/rating_stars.dart';
import 'package:libiko/core/widgets/work_card.dart';
import 'package:libiko/modules/anime/anime_detail_page.dart';
import 'package:libiko/modules/anime/anime_history.dart';
import 'package:libiko/modules/anime/anime_providers.dart';

class _FailingProvider implements MetadataProvider {
  @override
  String get id => 'fail';
  @override
  Future<List<Work>> feed(AnimeFeed feed, {int page = 1}) async =>
      throw Exception('offline');
  @override
  Future<List<Work>> search(String keyword, {int page = 1}) async =>
      throw Exception('offline');
  @override
  Future<Work> detail(Work work) async => throw Exception('offline');
}

MetadataService _offlineService() => MetadataService(
      anilist: _FailingProvider(),
      jikan: _FailingProvider(),
      seedLoader: () async => const [],
      intervals: const {},
    );

class _VideoSource implements VideoSource {
  @override
  String get id => 'test-source';
  @override
  String get name => '测试源';
  @override
  String get baseUrl => 'https://source.test';
  @override
  Future<List<VideoItem>> search(String keyword,
          {CancellationToken? cancel}) async =>
      const [VideoItem(id: 'item', title: 'Test Anime', detailUrl: 'detail')];
  @override
  Future<List<VideoEpisode>> episodes(String detailUrl,
          {CancellationToken? cancel}) async =>
      const [
        VideoEpisode(
            id: 'a1',
            title: 'A 第1集',
            index: 0,
            playUrl: 'a1',
            sourceId: 'test-source',
            lineId: 'a',
            lineName: '高清线路',
            episodeKey: 'episode:1'),
        VideoEpisode(
            id: 'a2',
            title: 'A 第2集',
            index: 1,
            playUrl: 'a2',
            sourceId: 'test-source',
            lineId: 'a',
            lineName: '高清线路',
            episodeKey: 'episode:2'),
        VideoEpisode(
            id: 'b1',
            title: 'B 第1集',
            index: 2,
            playUrl: 'b1',
            sourceId: 'test-source',
            lineId: 'b',
            lineName: '备用线路',
            episodeKey: 'episode:1'),
      ];
}

class _MatchingSource extends _VideoSource {
  _MatchingSource(this.find);
  final List<VideoItem> Function(String) find;
  final queries = <String>[];
  int episodeRequests = 0;
  @override
  Future<List<VideoItem>> search(String keyword,
      {CancellationToken? cancel}) async {
    queries.add(keyword);
    return find(keyword);
  }

  @override
  Future<List<VideoEpisode>> episodes(String detailUrl,
      {CancellationToken? cancel}) {
    episodeRequests++;
    return super.episodes(detailUrl, cancel: cancel);
  }
}

const _playbackWork = Work(
    id: 'test',
    sourceId: 'seed',
    sourceName: 'Offline',
    type: WorkType.anime,
    title: 'Test Anime');

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppDatabase.init();
  });

  for (final dark in [false, true]) {
    testWidgets(
        '320px ${dark ? "dark" : "light"} anime detail supports enlarged text',
        (tester) async {
      tester.view.physicalSize = const Size(320, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const work = Work(
          id: 'responsive',
          sourceId: 'seed',
          sourceName: 'Offline',
          type: WorkType.anime,
          title: '这是一个比较长的动漫标题用于验证窄屏',
          summary: '一段作品介绍。',
          extra: {
            'score': 8.5,
            'episodes': 24,
            'seasonYear': 2026,
            'status': 'Finished Airing',
            'format': 'TV'
          });
      await tester.pumpWidget(ProviderScope(
          overrides: [
            metadataServiceProvider.overrideWithValue(_offlineService()),
            videoSourcesProvider.overrideWith((ref) async => []),
          ],
          child: MaterialApp(
              theme: dark ? buildAppDarkTheme() : buildAppTheme(),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(1.6)),
                  child: child!),
              home: const AnimeDetailPage(work: work))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('追番'), findsOneWidget);
    });
  }

  testWidgets('episodes are grouped under their own line names',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(overrides: [
      metadataServiceProvider.overrideWithValue(_offlineService()),
      videoSourcesProvider.overrideWith((ref) async => [_VideoSource()]),
    ], child: const MaterialApp(home: AnimeDetailPage(work: _playbackWork))));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('测试源'));
    await tester.pumpAndSettle();
    expect(find.text('高清线路'), findsOneWidget);
    expect(find.text('备用线路'), findsOneWidget);
    final grids = find.byType(ButtonGrid);
    expect(grids, findsNWidgets(2));
    expect(find.descendant(of: grids.at(0), matching: find.text('A 第1集')),
        findsOneWidget);
    expect(find.descendant(of: grids.at(0), matching: find.text('A 第2集')),
        findsOneWidget);
    expect(find.descendant(of: grids.at(0), matching: find.text('B 第1集')),
        findsNothing);
    expect(find.descendant(of: grids.at(1), matching: find.text('B 第1集')),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('resume record exposes a continue-watching entry',
      (tester) async {
    final record = WatchRecord(
        work: _playbackWork,
        episodeTitle: '第2集',
        episodeIndex: 1,
        watchedAt: DateTime(2026),
        positionMs: 12000,
        sourceId: 'missing',
        lineId: 'a',
        episodeKey: 'episode:2');
    await tester.pumpWidget(ProviderScope(
        overrides: [
          metadataServiceProvider.overrideWithValue(_offlineService()),
          videoSourcesProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
            home: AnimeDetailPage(work: _playbackWork, resumeRecord: record))));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    final resume = find.byKey(const ValueKey('resume-playback'));
    expect(find.text('继续观看 · 第2集'), findsOneWidget);
    expect(tester.widget<TextButton>(resume).onPressed, isNotNull);
    await tester.ensureVisible(resume);
    await tester.tap(resume);
    await tester.pumpAndSettle();
    expect(find.text('原播放源暂不可用，请手动选择线路与集数'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('history navigation passes saved progress into the detail page',
      (tester) async {
    const episode = VideoEpisode(
        id: 'a2',
        title: '第2集',
        index: 1,
        playUrl: 'a2',
        sourceId: 'test-source',
        lineId: 'a',
        episodeKey: 'episode:2');
    await WatchHistoryManager()
        .record(_playbackWork, episode, positionMs: 12000, durationMs: 90000);
    await tester.pumpWidget(ProviderScope(overrides: [
      metadataServiceProvider.overrideWithValue(_offlineService()),
      videoSourcesProvider.overrideWith((ref) async => []),
    ], child: const MaterialApp(home: Scaffold(body: AnimeHistoryView()))));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(WorkCard));
    await tester.pumpAndSettle();
    final detail = tester.widget<AnimeDetailPage>(find.byType(AnimeDetailPage));
    expect(detail.resumeRecord!.positionMs, 12000);
    expect(detail.resumeRecord!.durationMs, 90000);
    expect(detail.resumeRecord!.sourceId, 'test-source');
    expect(detail.resumeRecord!.lineId, 'a');
    expect(detail.resumeRecord!.episodeKey, 'episode:2');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shows summary and rating when present', (tester) async {
    const work = Work(
      id: 'anilist_1',
      sourceId: 'anilist',
      sourceName: 'AniList',
      type: WorkType.anime,
      title: 'Test Anime',
      summary: 'A short summary.',
      extra: {'anilistId': 1, 'score': 8.5},
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [metadataServiceProvider.overrideWithValue(_offlineService())],
      child: const MaterialApp(home: AnimeDetailPage(work: work)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('A short summary.'), findsOneWidget);
    expect(find.byType(RatingStars), findsOneWidget);
  });

  testWidgets('shows empty text and no stars when missing', (tester) async {
    const work = Work(
      id: 'seed_1',
      sourceId: 'seed',
      sourceName: 'Offline',
      type: WorkType.anime,
      title: 'No Info',
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [metadataServiceProvider.overrideWithValue(_offlineService())],
      child: const MaterialApp(home: AnimeDetailPage(work: work)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('暂无简介'), findsOneWidget);
    expect(find.byType(RatingStars), findsNothing);
  });

  testWidgets('shows basic-info chips including translated status',
      (tester) async {
    const work = Work(
      id: 'anilist_2',
      sourceId: 'anilist',
      sourceName: 'AniList',
      type: WorkType.anime,
      title: 'Chips',
      summary: 'S.',
      extra: {
        'anilistId': 2,
        'score': 8.5,
        'episodes': 12,
        'seasonYear': 2024,
        'status': 'Finished Airing',
        'format': 'TV',
      },
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [metadataServiceProvider.overrideWithValue(_offlineService())],
      child: const MaterialApp(home: AnimeDetailPage(work: work)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('12 话'), findsOneWidget);
    expect(find.text('2024'), findsOneWidget);
    expect(find.text('已完结'), findsOneWidget);
    expect(find.text('TV'), findsOneWidget);
  });
  testWidgets(
      'low confidence is visible and requires explicit candidate confirmation',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = _MatchingSource((_) => const [
          VideoItem(id: 'wrong', title: '完全无关的作品', detailUrl: 'wrong'),
        ]);
    await tester.pumpWidget(ProviderScope(overrides: [
      metadataServiceProvider.overrideWithValue(_offlineService()),
      videoSourcesProvider.overrideWith((ref) async => [source]),
    ], child: const MaterialApp(home: AnimeDetailPage(work: _playbackWork))));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('待确认匹配'), findsOneWidget);
    expect(source.episodeRequests, 0);
    await tester.ensureVisible(find.text('测试源'));
    await tester.tap(find.text('测试源'));
    await tester.pumpAndSettle();
    expect(source.episodeRequests, 0);
    final candidate = find.widgetWithText(ActionChip, '完全无关的作品');
    await tester.ensureVisible(candidate);
    await tester.tap(candidate);
    await tester.pumpAndSettle();
    expect(source.episodeRequests, 1);
    expect(find.text('待确认匹配'), findsNothing);
    expect(find.text('高清线路'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('metadata native title is searched when the display title misses',
      (tester) async {
    final source = _MatchingSource((query) => query == '日本語別名'
        ? const [VideoItem(id: 'matched', title: '日本語別名', detailUrl: 'matched')]
        : const []);
    const work = Work(
        id: 'alias',
        sourceId: 'seed',
        sourceName: 'Offline',
        type: WorkType.anime,
        title: '中文显示标题',
        extra: {'titleNative': '日本語別名'});
    await tester.pumpWidget(ProviderScope(overrides: [
      metadataServiceProvider.overrideWithValue(_offlineService()),
      videoSourcesProvider.overrideWith((ref) async => [source]),
    ], child: const MaterialApp(home: AnimeDetailPage(work: work))));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(source.queries, ['中文显示标题', '日本語別名']);
    expect(find.text('日本語別名'), findsOneWidget);
    expect(find.text('待确认匹配'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'auto resume runs once after discovery and does not guess a missing episode',
      (tester) async {
    final source = _MatchingSource((_) => const [
          VideoItem(id: 'matched', title: 'Test Anime', detailUrl: 'matched'),
        ]);
    final record = WatchRecord(
        work: _playbackWork,
        episodeTitle: '不存在的剧集',
        episodeIndex: 99,
        watchedAt: DateTime(2026),
        sourceId: 'test-source',
        lineId: 'a',
        episodeKey: 'episode:99');
    await tester.pumpWidget(ProviderScope(
        overrides: [
          metadataServiceProvider.overrideWithValue(_offlineService()),
          videoSourcesProvider.overrideWith((ref) async => [source]),
        ],
        child: MaterialApp(
            home: AnimeDetailPage(
                work: _playbackWork, resumeRecord: record, autoResume: true))));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(source.episodeRequests, 1);
    expect(find.text('无法确定上次观看的剧集，请手动选集'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(source.episodeRequests, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('auto resume stops at a low-confidence work match',
      (tester) async {
    final source = _MatchingSource((_) => const [
          VideoItem(id: 'other', title: '完全不相干作品', detailUrl: 'other'),
        ]);
    final record = WatchRecord(
        work: _playbackWork,
        episodeTitle: '第1集',
        episodeIndex: 0,
        watchedAt: DateTime(2026),
        sourceId: 'test-source',
        lineId: 'a',
        episodeKey: 'episode:1');
    await tester.pumpWidget(ProviderScope(
        overrides: [
          metadataServiceProvider.overrideWithValue(_offlineService()),
          videoSourcesProvider.overrideWith((ref) async => [source]),
        ],
        child: MaterialApp(
            home: AnimeDetailPage(
                work: _playbackWork, resumeRecord: record, autoResume: true))));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(source.episodeRequests, 0);
    expect(find.text('原播放源的作品匹配待确认，请手动核对后继续观看'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
