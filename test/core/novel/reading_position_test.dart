import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/novel/models.dart';
import 'package:libiko/core/novel/novel_history.dart';
import 'package:libiko/core/novel/reading_position.dart';

NovelHistoryEntry entry({int block = 0, int offset = 0, String? anchor}) =>
    NovelHistoryEntry(
      sourceKey: 's',
      novelId: 'n',
      title: '书',
      chapterId: 'c',
      chapterTitle: '章',
      updatedAt: DateTime(2026),
      blockIndex: block,
      characterOffset: offset,
      scrollFraction: 0.4,
      anchorText: anchor,
    );

void main() {
  test('anchor follows the same passage after a block is inserted', () {
    const chapter = NovelChapter(title: '章', blocks: [
      NovelText('新加的序言'),
      NovelText('正文中的独有段落'),
      NovelText('结束'),
    ]);
    expect(resolveNovelAnchor(chapter, entry(anchor: '独有段落', offset: 5)),
        (blockIndex: 1, characterOffset: 4));
  });
  test('ambiguous changed passage falls back rather than jumping to a guess',
      () {
    const chapter = NovelChapter(title: '章', blocks: [
      NovelText('没有这个短句'),
      NovelText('重复的句子'),
      NovelText('重复的句子'),
    ]);
    expect(resolveNovelAnchor(chapter, entry(anchor: '重复的句子')), isNull);
  });
  test('the saved offset disambiguates repeated passages when still valid', () {
    const chapter = NovelChapter(title: '章', blocks: [
      NovelText('重复的句子'),
      NovelText('重复的句子'),
    ]);
    expect(resolveNovelAnchor(chapter, entry(block: 1, anchor: '重复的句子')),
        (blockIndex: 1, characterOffset: 0));
  });
  test('old history defaults to chapter start and new position round-trips',
      () {
    final raw = entry().toJson()
      ..remove('blockIndex')
      ..remove('characterOffset')
      ..remove('scrollFraction')
      ..remove('anchorText');
    final old = NovelHistoryEntry.fromJson(raw);
    expect(old.blockIndex, 0);
    expect(old.scrollFraction, 0);
    final saved = entry(block: 3, offset: 17, anchor: '锚点');
    final restored = NovelHistoryEntry.fromJson(saved.toJson());
    expect(restored.blockIndex, 3);
    expect(restored.characterOffset, 17);
    expect(restored.anchorText, '锚点');
    expect(restored.scrollFraction, 0.4);
  });
}
