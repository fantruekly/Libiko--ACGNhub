import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/metadata/metadata_provider.dart';
import 'package:libiko/core/metadata/metadata_service.dart';
import 'package:libiko/core/models/work.dart';
import 'package:libiko/modules/anime/anime_home.dart';
import 'package:libiko/modules/anime/anime_providers.dart';

class _EmptyProvider implements MetadataProvider {
  _EmptyProvider(this.id);
  @override
  final String id;
  @override
  Future<List<Work>> feed(AnimeFeed feed, {int page = 1}) async => const [];
  @override
  Future<List<Work>> search(String keyword, {int page = 1}) async => const [];
  @override
  Future<Work> detail(Work work) async => work;
}

void main() {
  testWidgets('anime tabs list 追番 before 历史记录', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        metadataServiceProvider.overrideWithValue(MetadataService(
          bangumi: _EmptyProvider('bangumi'),
          anilist: _EmptyProvider('anilist'),
          jikan: _EmptyProvider('jikan'),
        )),
      ],
      child: const MaterialApp(home: Scaffold(body: AnimeHomePage())),
    ));
    await tester.pump();

    final labels =
        tester.widgetList<Tab>(find.byType(Tab)).map((t) => t.text).toList();
    expect(labels, ['本季新番', '热门推荐', '今日放送', '追番', '历史记录']);
  });
}
