import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/comic/comic_source.dart';

const _validSource = '''
class TestSource extends ComicSource {
  name = "测试源";
  key = "test_source";
  version = "1.0.0";
  search = { load: (keyword, options, page) => ({ comics: [], maxPage: 1 }) };
  comic = { loadInfo: (id) => new ComicDetails({ id: id, title: "T" }) };
}
''';

void main() {
  test('parses name/key/version and capability flags', () {
    final source = ComicSource.parseForTest(_validSource);
    expect(source.name, '测试源');
    expect(source.key, 'test_source');
    expect(source.version, '1.0.0');
    expect(source.canSearch, isTrue);
    expect(source.canLoadInfo, isTrue);
    expect(source.canExplore, isFalse);
    expect(source.canLoadEp, isFalse);
  });

  test('a malformed source throws a FormatException', () {
    expect(() => ComicSource.parseForTest('var x = 1;'),
        throwsA(isA<FormatException>()));
  });

  test('a missing required field throws a FormatException', () {
    expect(
        () => ComicSource.parseForTest(
            'class S extends ComicSource { name = "x"; }'),
        throwsA(isA<FormatException>()));
  });

  test('fromMetadata reads the account metadata', () {
    final source = ComicSource.fromMetadata({
      'name': 'X',
      'key': 'x',
      'version': '1.0.0',
      'account': {
        'hasLogin': true,
        'hasCookieLogin': true,
        'cookieFields': ['a', 'b'],
      },
    });
    expect(source.hasLogin, isTrue);
    expect(source.hasCookieLogin, isTrue);
    expect(source.cookieFields, ['a', 'b']);
  });

  test('fromMetadata defaults the account metadata', () {
    final source = ComicSource.fromMetadata(
        {'name': 'X', 'key': 'x', 'version': '1.0.0'});
    expect(source.hasLogin, isFalse);
    expect(source.hasCookieLogin, isFalse);
    expect(source.cookieFields, isEmpty);
  });

  test('fromMetadata keeps only the option groups that apply to the category',
      () {
    final source = ComicSource.fromMetadata({
      'name': '拷贝漫画',
      'key': 'copy_manga',
      'version': '1.4.1',
      'category': {
        'hasComics': true,
        'category': '排行',
        'param': 'ranking',
        'optionGroups': [
          {
            'options': ['-全部', 'japan-日漫', 'korea-韩漫'],
            'showWhen': ['全部', '愛情', '冒險'],
          },
          {
            'options': ['*datetime_updated-时间倒序', 'popular-热度倒序'],
            'showWhen': ['全部', '愛情', '冒險'],
          },
          {
            'options': ['male-男频', 'female-女频'],
            'showWhen': ['排行'],
          },
          {
            'options': ['day-上升最快', 'week-最近7天', 'total-總榜單'],
            'showWhen': ['排行'],
          },
        ],
      },
    });
    expect(source.hasCategoryComics, isTrue);
    expect(source.categoryDefault, '排行');
    expect(source.categoryParam, 'ranking');
    expect(source.categoryOptions, ['male', 'day']);
    expect(source.categoryOptionsFor('排行'), ['male', 'day']);
    expect(source.categoryOptionsFor('全部'), ['', '*datetime_updated']);
  });

  test('fromMetadata falls back to the flat options list', () {
    final source = ComicSource.fromMetadata({
      'name': 'X',
      'key': 'x',
      'version': '1.0.0',
      'category': {
        'hasComics': true,
        'options': ['a', 'b'],
      },
    });
    expect(source.categoryOptions, ['a', 'b']);
    expect(source.categoryOptionsFor('anything'), ['a', 'b']);
  });
}
