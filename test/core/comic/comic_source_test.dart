import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/comic/comic_source.dart';

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
}
