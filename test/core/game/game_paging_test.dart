import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/game/game_paging.dart';
import 'package:acgnhub/core/game/models.dart';

Game _g(String id) => Game(id: id, title: id);

void main() {
  test('accumulates source pages to the app page size', () async {
    final requested = <int>[];
    final list =
        await buildGamePage(page: 1, sourcePageSize: 12, fetch: (p) async {
      requested.add(p);
      return GameSourcePage(
        items: [for (var i = 0; i < 12; i++) _g('$p-$i')],
        hasMore: p < 9,
      );
    });
    expect(requested, [1, 2]);
    expect(list.items, hasLength(24));
    expect(list.items.first.id, '1-0');
    expect(list.items.last.id, '2-11');
    expect(list.page, 1);
    expect(list.hasMore, isTrue);
  });

  test('trims a larger accumulation to 24', () async {
    final list =
        await buildGamePage(page: 1, sourcePageSize: 13, fetch: (p) async {
      return GameSourcePage(
        items: [for (var i = 0; i < 13; i++) _g('$p-$i')],
        hasMore: true,
      );
    });
    expect(list.items, hasLength(24));
    expect(list.items.last.id, '2-10');
  });

  test('stops early when a source page has no next', () async {
    final requested = <int>[];
    final list =
        await buildGamePage(page: 1, sourcePageSize: 12, fetch: (p) async {
      requested.add(p);
      return GameSourcePage(
        items: [for (var i = 0; i < 12; i++) _g('$p-$i')],
        hasMore: p < 1,
      );
    });
    expect(requested, [1]);
    expect(list.items, hasLength(12));
    expect(list.hasMore, isFalse);
  });

  test('stops when a later source page fails', () async {
    final requested = <int>[];
    final list =
        await buildGamePage(page: 1, sourcePageSize: 12, fetch: (p) async {
      requested.add(p);
      if (p == 2) throw Exception('boom');
      return GameSourcePage(
        items: [for (var i = 0; i < 12; i++) _g('$p-$i')],
        hasMore: true,
      );
    });
    expect(requested, [1, 2]);
    expect(list.items, hasLength(12));
    expect(list.hasMore, isFalse);
  });

  test('rethrows when the first source page fails', () {
    expect(
      () => buildGamePage(
          page: 1,
          sourcePageSize: 12,
          fetch: (p) async => throw Exception('boom')),
      throwsException,
    );
  });

  test('page 2 starts at the right source page', () async {
    final requested = <int>[];
    await buildGamePage(page: 2, sourcePageSize: 12, fetch: (p) async {
      requested.add(p);
      return GameSourcePage(items: [_g('$p')], hasMore: true);
    });
    expect(requested, [3, 4]);
  });
}
