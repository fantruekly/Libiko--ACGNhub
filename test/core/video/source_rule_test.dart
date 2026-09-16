import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/video/source_rule.dart';

void main() {
  const validJson = '''
  {
    "api": "4",
    "type": "anime",
    "name": "七色番",
    "version": "1.3",
    "muliSources": true,
    "useWebview": true,
    "useNativePlayer": true,
    "userAgent": "",
    "baseURL": "https://www.7sefun.top/",
    "searchURL": "https://www.7sefun.top/vodsearch/-------------.html?wd=@keyword",
    "searchList": "//div[2]/div[2]/div[2]/div[2]/div",
    "searchName": "//div[2]/text()",
    "searchResult": "//a",
    "chapterRoads": "//div[2]/div[2]/div[2]/div/div[2]/div[1]//div",
    "chapterResult": "//a"
  }''';

  test('fromJsonString parses a Kazumi plugin and ignores unknown keys', () {
    final rule = SourceRule.fromJsonString(validJson);
    expect(rule.name, '七色番');
    expect(rule.baseUrl, 'https://www.7sefun.top/');
    expect(rule.searchList, '//div[2]/div[2]/div[2]/div[2]/div');
    expect(rule.chapterResult, '//a');
    expect(rule.userAgent, isNull); // empty string -> null
    expect(rule.id, 'rule:七色番');
  });

  test('buildSearchUrl substitutes and URL-encodes @keyword', () {
    final rule = SourceRule.fromJsonString(validJson);
    expect(
      rule.buildSearchUrl('进击的巨人'),
      'https://www.7sefun.top/vodsearch/-------------.html?wd=%E8%BF%9B%E5%87%BB%E7%9A%84%E5%B7%A8%E4%BA%BA',
    );
  });

  test('fromJson throws FormatException on a missing required field', () {
    expect(
      () => SourceRule.fromJson({'name': 'x', 'baseURL': 'https://a/'}),
      throwsFormatException,
    );
  });

  test('fromJsonString throws FormatException on a non-object', () {
    expect(() => SourceRule.fromJsonString('[1,2,3]'), throwsFormatException);
  });
}
