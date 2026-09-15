import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/game/game_source.dart';
import 'package:acgnhub/core/game/models.dart';

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
      GameList(items: const [], page: page, hasMore: false);
  @override
  Future<GameDetail> detail(String id) async =>
      GameDetail(game: Game(id: id, title: id), sourceUrl: 'https://fake/$id');
}

void main() {
  test('manager exposes registered sources', () {
    final m = GameSourceManager(sources: [_FakeSource()]);
    expect(m.sources.map((s) => s.id), ['fake']);
    expect(m.byId('fake')!.name, 'Fake');
    expect(m.byId('nope'), isNull);
  });

  test('manager rejects duplicate ids', () {
    final m = GameSourceManager(sources: [_FakeSource()]);
    expect(() => m.register(_FakeSource()), throwsArgumentError);
  });
}
