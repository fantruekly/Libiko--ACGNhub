import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/comic/reader_nav.dart';

void main() {
  test('chapterNav returns the neighbours in list order', () {
    final nav = chapterNav(['a', 'b', 'c'], 'b');
    expect(nav.previous, 'a');
    expect(nav.next, 'c');
  });

  test('chapterNav clamps at the ends', () {
    expect(chapterNav(['a', 'b'], 'a').previous, isNull);
    expect(chapterNav(['a', 'b'], 'a').next, 'b');
    expect(chapterNav(['a', 'b'], 'b').next, isNull);
  });

  test('chapterNav returns empty for an unknown chapter', () {
    final nav = chapterNav(['a', 'b'], 'z');
    expect(nav.previous, isNull);
    expect(nav.next, isNull);
  });

  test('preloadIndices returns up to three following pages', () {
    expect(preloadIndices(2, 10), [3, 4, 5]);
    expect(preloadIndices(8, 10), [9]);
    expect(preloadIndices(9, 10), isEmpty);
  });

  test('currentPageFromScroll maps the scroll fraction to a page', () {
    expect(currentPageFromScroll(0, 100, 11), 0);
    expect(currentPageFromScroll(100, 100, 11), 10);
    expect(currentPageFromScroll(50, 100, 11), 5);
    expect(currentPageFromScroll(0, 0, 1), 0);
    expect(currentPageFromScroll(10, 0, 5), 0);
  });

  test('wheelFlipDelta maps the wheel direction to a page step', () {
    expect(wheelFlipDelta(120), 1);
    expect(wheelFlipDelta(-120), -1);
    expect(wheelFlipDelta(0), 0);
  });
}
