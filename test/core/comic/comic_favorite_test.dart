import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:libiko/core/comic/comic_favorite.dart';
import 'package:libiko/core/storage/database.dart';

ComicFavorite _fav(String comicId, int ms) => ComicFavorite(
      sourceKey: 's1',
      comicId: comicId,
      title: 'Title $comicId',
      cover: 'c.jpg',
      addedAt: DateTime.fromMillisecondsSinceEpoch(ms),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('upsert dedupes by (sourceKey, comicId) and keeps the newest first', () {
    final result = ComicFavoriteManager.upsert(
        [_fav('a', 100), _fav('b', 200)], _fav('a', 300));
    expect(result, hasLength(2));
    expect(result.first.comicId, 'a');
    expect(result.first.addedAt.millisecondsSinceEpoch, 300);
    expect(result.last.comicId, 'b');
  });

  test('toggle adds then removes, and isFavorite reflects it', () async {
    await AppDatabase.init();
    final manager = ComicFavoriteManager();

    await manager.toggle(_fav('a', 100));
    expect(manager.isFavorite('s1', 'a'), isTrue);
    expect(manager.all(), hasLength(1));

    await manager.toggle(_fav('a', 100));
    expect(manager.isFavorite('s1', 'a'), isFalse);
    expect(manager.all(), isEmpty);
  });

  test('all() is newest-first and clear() empties', () async {
    await AppDatabase.init();
    final manager = ComicFavoriteManager();
    await manager.toggle(_fav('a', 100));
    await manager.toggle(_fav('b', 200));
    expect(manager.all().map((f) => f.comicId), ['b', 'a']);
    await manager.clear();
    expect(manager.all(), isEmpty);
  });

  test('a malformed stored entry is skipped', () async {
    await AppDatabase.init();
    final manager = ComicFavoriteManager();
    await manager.toggle(_fav('a', 100));

    final prefs = await SharedPreferences.getInstance();
    final key =
        prefs.getKeys().firstWhere((k) => k.endsWith('comic_favorites'));
    await prefs.setStringList(key, ['not json', ...prefs.getStringList(key)!]);

    expect(manager.all().map((f) => f.comicId), ['a']);
  });
}
