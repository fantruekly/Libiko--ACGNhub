import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acgnhub/core/metadata/metadata_provider.dart';
import 'package:acgnhub/core/metadata/metadata_service.dart';
import 'package:acgnhub/core/models/work.dart';
import 'package:acgnhub/core/widgets/rating_stars.dart';
import 'package:acgnhub/modules/anime/anime_detail_page.dart';
import 'package:acgnhub/modules/anime/anime_providers.dart';

class _FailingProvider implements MetadataProvider {
  @override
  String get id => 'fail';
  @override
  Future<List<Work>> feed(AnimeFeed feed, {int page = 1}) async => throw Exception('offline');
  @override
  Future<List<Work>> search(String keyword, {int page = 1}) async => throw Exception('offline');
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
  setUp(() => SharedPreferences.setMockInitialValues({}));

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
}
