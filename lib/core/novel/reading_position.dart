import 'models.dart';
import 'novel_history.dart';

typedef NovelAnchor = ({int blockIndex, int characterOffset});

/// Text around the visible character lets a bookmark survive inserted blocks.
String? novelAnchorText(NovelBlock block, int offset) {
  if (block is! NovelText || block.text.isEmpty) return null;
  final start = offset.clamp(0, block.text.length - 1);
  return block.text
      .substring(start, (start + 24).clamp(start, block.text.length));
}

NovelAnchor? resolveNovelAnchor(NovelChapter chapter, NovelHistoryEntry entry) {
  if (chapter.blocks.isEmpty) return null;
  final index = entry.blockIndex;
  final text = entry.anchorText;
  if ((text == null || text.isEmpty) &&
      index == 0 &&
      entry.characterOffset == 0 &&
      entry.scrollFraction > 0) {
    return null;
  }
  if (text != null && text.isNotEmpty) {
    final matches = <NovelAnchor>[];
    for (var i = 0; i < chapter.blocks.length; i++) {
      final block = chapter.blocks[i];
      if (block is! NovelText) continue;
      final first = block.text.indexOf(text);
      if (first >= 0 && block.text.indexOf(text, first + 1) < 0) {
        matches.add((blockIndex: i, characterOffset: first));
      }
    }
    // Prefer the exact saved position when the same phrase appears elsewhere.
    if (index >= 0 && index < chapter.blocks.length) {
      final block = chapter.blocks[index];
      if (block is NovelText &&
          entry.characterOffset <= block.text.length &&
          block.text.substring(entry.characterOffset).startsWith(text)) {
        return (blockIndex: index, characterOffset: entry.characterOffset);
      }
    }
    return matches.length == 1 ? matches.single : null;
  }
  if (index < 0 || index >= chapter.blocks.length) return null;
  final block = chapter.blocks[index];
  return (
    blockIndex: index,
    characterOffset: block is NovelText
        ? entry.characterOffset.clamp(0, block.text.length)
        : 0
  );
}
