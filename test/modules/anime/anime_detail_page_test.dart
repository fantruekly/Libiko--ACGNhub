import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:libiko/core/metadata/metadata_provider.dart';
import 'package:libiko/core/metadata/metadata_service.dart';
import 'package:libiko/core/models/work.dart';
import 'package:libiko/core/storage/database.dart';
import 'package:libiko/core/widgets/rating_stars.dart';
import 'package:libiko/modules/anime/anime_detail_page.dart';
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

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppDatabase.init();
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
}
