/// The previous/next chapter ids for a chapter within the chapter list.
class ChapterNav {
  final String? previous;
  final String? next;

  const ChapterNav({this.previous, this.next});
}

/// The neighbours of [currentId] in [chapterIds] (insertion order is the
/// reading order). An unknown id yields an empty nav.
ChapterNav chapterNav(List<String> chapterIds, String currentId) {
  final index = chapterIds.indexOf(currentId);
  if (index < 0) return const ChapterNav();
  return ChapterNav(
    previous: index > 0 ? chapterIds[index - 1] : null,
    next: index < chapterIds.length - 1 ? chapterIds[index + 1] : null,
  );
}

/// The indices to precache after [current], up to [ahead] pages and never past
/// the end of the chapter.
List<int> preloadIndices(int current, int total, {int ahead = 3}) {
  final indices = <int>[];
  for (var i = current + 1; i <= current + ahead && i < total; i++) {
    indices.add(i);
  }
  return indices;
}

/// Maps a continuous-scroll offset to the page it is showing, using the scroll
/// fraction as an approximation (comic pages have varying heights).
int currentPageFromScroll(double pixels, double maxScrollExtent, int total) {
  if (total <= 1 || maxScrollExtent <= 0) return 0;
  final fraction = (pixels / maxScrollExtent).clamp(0.0, 1.0);
  return (fraction * (total - 1)).round();
}

/// Maps a mouse-wheel vertical delta to a page step: down (positive) advances
/// one page, up goes back, and a zero delta does not turn the page.
int wheelFlipDelta(double dy) => dy > 0 ? 1 : (dy < 0 ? -1 : 0);
