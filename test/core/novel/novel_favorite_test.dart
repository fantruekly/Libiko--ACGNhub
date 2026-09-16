import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:libiko/core/novel/novel_favorite.dart';
import 'package:libiko/core/storage/database.dart';

NovelFavorite _fav(String novelId, int ms) => NovelFavorite(
      sourceKey: 's1',
      novelId: novelId,
      title: 'Title $novelId',
      cover: 'c.jpg',
      addedAt: DateTime.fromMillisecondsSinceEpoch(ms),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('upsert dedupes by (sourceKey, novelId) and keeps the newest first', () {
    final result = NovelFavoriteManager.upsert(
        [_fav('a', 100), _fav('b', 200)], _fav('a', 300));
    expect(result, hasLength(2));
    expect(result.first.novelId, 'a');
    expect(result.first.addedAt.millisecondsSinceEpoch, 300);
    expect(result.last.novelId, 'b');
  });

  test('toggle adds then removes, and isFavorite reflects it', () async {
    await AppDatabase.init();
    final manager = NovelFavoriteManager();

    await manager.toggle(_fav('a', 100));
    expect(manager.isFavorite('s1', 'a'), isTrue);
    expect(manager.all(), hasLength(1));

    await manager.toggle(_fav('a', 100));
    expect(manager.isFavorite('s1', 'a'), isFalse);
    expect(manager.all(), isEmpty);
  });

  test('all() is newest-first and clear() empties', () async {
    await AppDatabase.init();
    final manager = NovelFavoriteManager();
    await manager.toggle(_fav('a', 100));
    await manager.toggle(_fav('b', 200));
    expect(manager.all().map((f) => f.novelId), ['b', 'a']);
    await manager.clear();
    expect(manager.all(), isEmpty);
  });

  test('NovelFavorite round-trips through JSON', () {
    final f = NovelFavorite(
      sourceKey: 's1',
      novelId: 'a',
      title: 'T',
      cover: 'c.jpg',
      addedAt: DateTime.fromMillisecondsSinceEpoch(123),
    );
    final r = NovelFavorite.fromJson(
        json.decode(json.encode(f.toJson())) as Map<String, dynamic>);
    expect(r.novelId, 'a');
    expect(r.cover, 'c.jpg');
    expect(r.addedAt.millisecondsSinceEpoch, 123);
  });

  test('a malformed stored favorite entry is skipped', () async {
    await AppDatabase.init();
    final manager = NovelFavoriteManager();
    await manager.toggle(_fav('a', 100));
    final prefs = await SharedPreferences.getInstance();
    final key =
        prefs.getKeys().firstWhere((k) => k.endsWith('novel_favorites'));
    await prefs.setStringList(key, ['not json', ...prefs.getStringList(key)!]);
    expect(manager.all().map((f) => f.novelId), ['a']);
  });
}
