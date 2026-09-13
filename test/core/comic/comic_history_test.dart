import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acgnhub/core/comic/comic_history.dart';
import 'package:acgnhub/core/storage/database.dart';

ComicHistoryEntry _entry(String comicId, String chapter, int page, int ms) =>
    ComicHistoryEntry(
      sourceKey: 's1',
      comicId: comicId,
      title: 'Title $comicId',
      cover: 'c.jpg',
      chapterId: chapter,
      chapterTitle: '第$chapter话',
      page: page,
      readAt: DateTime.fromMillisecondsSinceEpoch(ms),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('upsert dedupes by comic and keeps the newest first', () {
    final result = ComicHistoryManager.upsert(
        [_entry('a', '1', 0, 100), _entry('b', '1', 0, 200)],
        _entry('a', '5', 3, 300));
    expect(result, hasLength(2));
    expect(result.first.comicId, 'a');
    expect(result.first.chapterId, '5');
    expect(result.first.page, 3);
    expect(result.last.comicId, 'b');
  });

  test('record stores and forComic finds the entry', () async {
    await AppDatabase.init();
    final manager = ComicHistoryManager();
    await manager.record(_entry('a', '2', 1, 100));
    expect(manager.all(), hasLength(1));
    expect(manager.forComic('s1', 'a')!.chapterId, '2');
    expect(manager.forComic('s1', 'nope'), isNull);
  });

  test('clear empties the history', () async {
    await AppDatabase.init();
    final manager = ComicHistoryManager();
    await manager.record(_entry('a', '1', 0, 100));
    await manager.clear();
    expect(manager.all(), isEmpty);
  });
}
