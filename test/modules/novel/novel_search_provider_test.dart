import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libiko/core/novel/models.dart';
import 'package:libiko/core/novel/novel_source.dart';
import 'package:libiko/modules/novel/novel_providers.dart';

class _SearchSource extends NovelSource {
  _SearchSource(this.id, this.results, {this.throws = false});
  @override
  final String id;
  final List<Novel> results;
  final bool throws;
  @override
  String get name => id;
  @override
  String get baseUrl => 'https://x';
  @override
  List<NovelBrowseGroup> get browseGroups => const [];
  @override
  Future<NovelHome> home() async => const NovelHome(sections: []);
  @override
  Future<NovelList> browse(String optionKey, {int page = 1}) async =>
      NovelList(items: const [], page: page, hasMore: false);
  @override
  Future<List<Novel>> search(String keyword, {int page = 1}) async {
    if (throws) throw Exception('boom');
    return results;
  }

  @override
  Future<NovelDetail> detail(String id) async =>
      const NovelDetail(novel: Novel(id: 'x', title: 'x'), volumes: []);
  @override
  Future<NovelChapter> chapter(String novelId, String chapterId) async =>
      const NovelChapter(title: 't', blocks: []);
}

ProviderContainer _container(List<NovelSource> sources) {
  final c = ProviderContainer(overrides: [
    novelSourceManagerProvider
        .overrideWithValue(NovelSourceManager(sources: sources)),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('aggregates across sources and dedupes by title', () async {
    final c = _container([
      _SearchSource('a', const [Novel(id: '1', title: 'X'), Novel(id: '2', title: 'Y')]),
      _SearchSource('b', const [Novel(id: '3', title: 'X'), Novel(id: '4', title: 'Z')]),
    ]);
    final results = await c.read(novelSearchProvider('k').future);
    expect(results.map((r) => r.novel.title), ['X', 'Y', 'Z']);
    expect(results.first.sourceKey, 'a');
    expect(results.last.sourceKey, 'b');
  });

  test('skips a failing source', () async {
    final c = _container([
      _SearchSource('a', const [], throws: true),
      _SearchSource('b', const [Novel(id: '4', title: 'Z')]),
    ]);
    final results = await c.read(novelSearchProvider('k').future);
    expect(results.single.novel.title, 'Z');
  });

  test('throws when every source fails', () async {
    final c = _container([_SearchSource('a', const [], throws: true)]);
    await expectLater(c.read(novelSearchProvider('k').future), throwsA(isA<StateError>()));
  });

  test('empty keyword returns no results', () async {
    final c = _container([_SearchSource('a', const [Novel(id: '1', title: 'X')])]);
    expect(await c.read(novelSearchProvider('  ').future), isEmpty);
  });

  test('no sources returns empty', () async {
    final c = _container([]);
    expect(await c.read(novelSearchProvider('k').future), isEmpty);
  });
}
