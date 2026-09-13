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

  test('parses a {parts: [...]} result', () {
    final page = parseExploreResult({
      'parts': [
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
          ],
        },
      ],
    });
    expect(page.comics.map((c) => c.id), ['1', '2']);
  });

  test('parses a mixed {data: [...]} result', () {
    final page = parseExploreResult({
      'data': [
        [
          {'id': '1', 'title': 'A'},
        ],
        {
          'title': 'p2',
          'comics': [
            {'id': '2', 'title': 'B'},
          ],
        },
      ],
    });
    expect(page.comics.map((c) => c.id), ['1', '2']);
  });

  test('does not double-count when comics is present with other list values',
      () {
    final page = parseExploreResult({
      'comics': [
        {'id': '1', 'title': 'A'},
      ],
      'extra': [
        {'id': '2', 'title': 'B'},
      ],
    });
    expect(page.comics.map((c) => c.id), ['1']);
  });

  test('reads an integer-valued double maxPage', () {
    final page = parseExploreResult({
      'comics': [
        {'id': '1', 'title': 'A'},
      ],
      'maxPage': 3.0,
    });
    expect(page.maxPage, 3);
  });

  test('captures the first viewMore from parts', () {
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
        ],
        'viewMore': 'category:全部@',
      },
      {
        'title': 'p3',
        'comics': [
          {'id': '3', 'title': 'C'},
        ],
        'viewMore': 'category:later@x',
      },
    ]);
    expect(page.comics.map((c) => c.id), ['1', '2', '3']);
    expect(page.viewMore, 'category:全部@');
  });
}
