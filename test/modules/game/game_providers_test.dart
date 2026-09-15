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
}
