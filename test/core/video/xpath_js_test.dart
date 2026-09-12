import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/video/source_rule.dart';
import 'package:acgnhub/core/video/webview_scraper.dart';

const _rule = SourceRule(
  name: '七色番',
  baseUrl: 'https://www.7sefun.top/',
  searchUrl: 'https://www.7sefun.top/vodsearch/-------------.html?wd=@keyword',
  searchList: '//div[2]/div[2]/div[2]/div[2]/div',
  searchName: '//div[2]/text()',
  searchResult: '//a',
  chapterRoads: '//div[2]/div[2]/div[2]/div/div[2]/div[1]//div',
  chapterResult: '//a',
);

void main() {
  test('buildSearchScript embeds the search XPaths and returns JSON', () {
    final js = buildSearchScript(_rule);
    expect(js, contains('document.evaluate'));
    expect(js, contains('"//div[2]/div[2]/div[2]/div[2]/div"'));
    expect(js, contains('"//div[2]/text()"'));
    expect(js, contains('"//a"'));
    expect(js, contains('return rows;'));
    expect(js, isNot(contains('JSON.stringify')));
  });

  test('buildEpisodesScript embeds the chapter XPaths and returns JSON', () {
    final js = buildEpisodesScript(_rule);
    expect(js, contains('"//div[2]/div[2]/div[2]/div/div[2]/div[1]//div"'));
    expect(js, contains('"//a"'));
    expect(js, contains('return out;'));
    expect(js, isNot(contains('JSON.stringify')));
  });

  test('decodeResult returns a List as-is', () {
    final result = WebviewScraper.decodeResult([
      {'name': 'a'},
    ]);
    expect(result, hasLength(1));
  });

  test('decodeResult decodes a JSON string to a list', () {
    final result = WebviewScraper.decodeResult('[{"name":"a"}]');
    expect(result, hasLength(1));
  });

  test('decodeResult returns empty for a non-list JSON string', () {
    expect(WebviewScraper.decodeResult('"oops"'), isEmpty);
  });

  test('decodeResult returns empty for null and non-JSON strings', () {
    expect(WebviewScraper.decodeResult(null), isEmpty);
    expect(WebviewScraper.decodeResult('not json'), isEmpty);
  });
}
