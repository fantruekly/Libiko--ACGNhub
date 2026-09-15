import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/game/models.dart';

void main() {
  test('Game fromJson/toJson round-trips', () {
    final g = Game(
      id: '1207',
      title: '金辉恋曲四重奏',
      coverUrl: 'https://x/cover.jpg',
      summary: 'sum',
      category: '玩家热评游戏',
      tags: const ['汉化', 'PC'],
      publishedAt: DateTime.utc(2026, 9, 11),
      views: 4300,
      extra: const {'url': 'https://game.galgamezywz.org/game/1207'},
    );
    final back = Game.fromJson(g.toJson());
    expect(back.id, '1207');
    expect(back.title, '金辉恋曲四重奏');
    expect(back.coverUrl, 'https://x/cover.jpg');
    expect(back.summary, 'sum');
    expect(back.category, '玩家热评游戏');
    expect(back.tags, ['汉化', 'PC']);
    expect(back.publishedAt, DateTime.utc(2026, 9, 11));
    expect(back.views, 4300);
    expect(back.extra['url'], 'https://game.galgamezywz.org/game/1207');
  });

  test('Game.fromJson tolerates missing optional fields', () {
    final g = Game.fromJson(const {'id': '1', 'title': 'T'});
    expect(g.coverUrl, isNull);
    expect(g.summary, isNull);
    expect(g.category, isNull);
    expect(g.tags, isEmpty);
    expect(g.publishedAt, isNull);
    expect(g.views, isNull);
  });
}
