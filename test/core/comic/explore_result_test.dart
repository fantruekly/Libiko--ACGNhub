import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/comic/explore_result.dart';

void main() {
  test('parses a {comics, maxPage} result', () {
    final page = parseExploreResult({
      'comics': [
        {'id': '1', 'title': 'A'},
        {'id': '2', 'title': 'B'},
      ],
      'maxPage': 4,
    });
    expect(page.comics.map((c) => c.id), ['1', '2']);
    expect(page.maxPage, 4);
    expect(page.next, isNull);
  });

  test('parses a list of parts', () {
    final page = parseExploreResult([
      {
        'title': 'p1',
        'comics': [
          {'id': '1', 'title': 'A'},
        ],
      },
      {
        'title': 'p2',
        'comics': [
          {'id': '2', 'title': 'B'},
          {'id': '3', 'title': 'C'},
        ],
      },
    ]);
    expect(page.comics.map((c) => c.id), ['1', '2', '3']);
    expect(page.maxPage, isNull);
  });

  test('parses a {title: comics} map', () {
    final page = parseExploreResult({
      '推荐': [
        {'id': '1', 'title': 'A'},
      ],
      '热门': [
        {'id': '2', 'title': 'B'},
      ],
    });
    expect(page.comics.map((c) => c.id), ['1', '2']);
  });

  test('reads a cursor', () {
    final page = parseExploreResult({
      'comics': [
        {'id': '1', 'title': 'A'},
      ],
      'next': 'cursor-1',
    });
    expect(page.next, 'cursor-1');
  });

  test('tolerates empty and unknown input', () {
    expect(parseExploreResult(null).comics, isEmpty);
    expect(parseExploreResult('nope').comics, isEmpty);
    expect(parseExploreResult(<dynamic, dynamic>{}).comics, isEmpty);
  });
}
