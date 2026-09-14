import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acgnhub/core/novel/novel_history.dart';
import 'package:acgnhub/core/storage/database.dart';

NovelHistoryEntry _entry(String novelId, String chapter, int ms) =>
    NovelHistoryEntry(
      sourceKey: 's1',
      novelId: novelId,
      title: 'Title $novelId',
      cover: 'c.jpg',
      chapterId: chapter,
      chapterTitle: '第$chapter章',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(ms),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('upsert dedupes by novel and keeps the newest first', () {
    final result = NovelHistoryManager.upsert(
        [_entry('a', '1', 100), _entry('b', '1', 200)], _entry('a', '5', 300));
    expect(result, hasLength(2));
    expect(result.first.novelId, 'a');
    expect(result.first.chapterId, '5');
    expect(result.last.novelId, 'b');
  });

  test('record stores and forNovel finds the entry', () async {
    await AppDatabase.init();
    final manager = NovelHistoryManager();
    await manager.record(_entry('a', '2', 100));
    expect(manager.all(), hasLength(1));
    expect(manager.forNovel('s1', 'a')!.chapterId, '2');
    expect(manager.forNovel('s1', 'nope'), isNull);
  });

  test('clear empties the history', () async {
    await AppDatabase.init();
    final manager = NovelHistoryManager();
    await manager.record(_entry('a', '1', 100));
    await manager.clear();
    expect(manager.all(), isEmpty);
  });
}
