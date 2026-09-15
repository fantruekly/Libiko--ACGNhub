import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/game/game_source.dart';
import 'package:acgnhub/core/game/models.dart';
import 'package:acgnhub/modules/game/game_providers.dart';

class _FakeSource implements GameSource {
  @override
  String get id => 'fake';
  @override
  String get name => 'Fake';
  @override
  String get baseUrl => 'https://fake';
  @override
  List<GameBrowseOption> get browseOptions =>
      const [GameBrowseOption(key: 'latest', label: '最近更新')];
  @override
  Future<GameList> browse(String optionKey, {int page = 1}) async =>
      GameList(
        items: [Game(id: '$optionKey-$page', title: '游戏$optionKey')],
        page: page,
        hasMore: false,
      );
  @override
  Future<GameDetail> detail(String id) async => GameDetail(
        game: Game(id: id, title: '游戏$id'),
        sourceUrl: 'https://fake/game/$id',
      );
  @override
  Future<List<Game>> search(String keyword) async =>
      [Game(id: 's-$keyword', title: '搜索结果$keyword')];
}

class _TitleSource implements GameSource {
  _TitleSource(this._id, this._title);
  final String _id;
  final String _title;
  @override
  String get id => _id;
  @override
  String get name => _id;
  @override
  String get baseUrl => 'https://fake';
  @override
  List<GameBrowseOption> get browseOptions => const [];
  @override
  Future<GameList> browse(String optionKey, {int page = 1}) async =>
      GameList(items: const [], page: page, hasMore: false);
  @override
  Future<GameDetail> detail(String id) async =>
      GameDetail(game: Game(id: id, title: id), sourceUrl: 'https://fake/$id');
  @override
  Future<List<Game>> search(String keyword) async =>
      [Game(id: _id, title: _title)];
}

class _FailingSource implements GameSource {
  @override
  String get id => 'failing';
  @override
  String get name => 'failing';
  @override
  String get baseUrl => 'https://fake';
  @override
  List<GameBrowseOption> get browseOptions => const [];
  @override
  Future<GameList> browse(String optionKey, {int page = 1}) async =>
      GameList(items: const [], page: page, hasMore: false);
  @override
  Future<GameDetail> detail(String id) async =>
      GameDetail(game: Game(id: id, title: id), sourceUrl: 'https://fake/$id');
  @override
  Future<List<Game>> search(String keyword) async => throw Exception('boom');
}

ProviderContainer _container() => ProviderContainer(overrides: [
      gameSourceManagerProvider
          .overrideWithValue(GameSourceManager(sources: [_FakeSource()])),
    ]);

void main() {
  test('gameBrowseProvider delegates to the registered source', () async {
    final container = _container();
    addTearDown(container.dispose);
    final list =
        await container.read(gameBrowseProvider(('fake', 'latest', 2)).future);
    expect(list.page, 2);
    expect(list.items.single.title, '游戏latest');
  });

  test('gameDetailProvider delegates to the registered source', () async {
    final container = _container();
    addTearDown(container.dispose);
    final detail = await container.read(gameDetailProvider(('fake', '1')).future);
    expect(detail.game.id, '1');
    expect(detail.sourceUrl, 'https://fake/game/1');
  });

  test('unknown source id throws', () async {
    final container = _container();
    addTearDown(container.dispose);
    expect(
      container.read(gameBrowseProvider(('nope', 'latest', 1)).future),
      throwsStateError,
    );
  });

  test('default manager registers both game sources', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(gameSourceManagerProvider).sources.map((s) => s.id),
      ['galgamezywz', 'nekogal'],
    );
  });

  test('gameSearchSourceProvider delegates to the source', () async {
    final container = _container();
    addTearDown(container.dispose);
    final results =
        await container.read(gameSearchSourceProvider(('fake', '魔女')).future);
    expect(results.single.game.title, '搜索结果魔女');
    expect(results.single.sourceKey, 'fake');
  });

  test('gameSearchSourceProvider is empty for a blank keyword', () async {
    final container = _container();
    addTearDown(container.dispose);
    expect(
        await container.read(gameSearchSourceProvider(('fake', '  ')).future),
        isEmpty);
  });

  test('gameSearchProvider merges and dedupes by title', () async {
    final container = ProviderContainer(overrides: [
      gameSourceManagerProvider.overrideWithValue(GameSourceManager(
          sources: [_TitleSource('a', '同名游戏'), _TitleSource('b', '同名游戏')])),
    ]);
    addTearDown(container.dispose);
    final results = await container.read(gameSearchProvider('x').future);
    expect(results, hasLength(1));
  });

  test('gameSearchProvider isolates a failing source', () async {
    final container = ProviderContainer(overrides: [
      gameSourceManagerProvider.overrideWithValue(GameSourceManager(
          sources: [_TitleSource('a', '好结果'), _FailingSource()])),
    ]);
    addTearDown(container.dispose);
    final results = await container.read(gameSearchProvider('x').future);
    expect(results.single.game.title, '好结果');
  });

  test('gameSearchProvider throws when all sources fail', () async {
    final container = ProviderContainer(overrides: [
      gameSourceManagerProvider.overrideWithValue(
          GameSourceManager(sources: [_FailingSource()])),
    ]);
    addTearDown(container.dispose);
    expect(container.read(gameSearchProvider('x').future), throwsStateError);
  });
}
