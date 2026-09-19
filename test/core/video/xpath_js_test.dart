import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/video/source_rule.dart';
import 'package:libiko/core/video/webview_scraper.dart';

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
  test('buildSearchScript wraps row sub-selectors with __rel', () {
    final js = buildSearchScript(_rule);
    expect(js, contains('document.evaluate'));
    expect(js, contains('function __rel('));
    expect(
      js,
      contains("return xpath.indexOf('//') === 0 ? '.' + xpath : xpath;"),
    );
    expect(js, contains('__ev("//div[2]/div[2]/div[2]/div[2]/div", document)'));
    expect(js, contains('__txt(__rel("//div[2]/text()"), list[i])'));
    expect(js, contains('__attr(__rel("//a"), list[i], \'href\')'));
    expect(js, contains('return rows;'));
    expect(js, isNot(contains('JSON.stringify')));
  });

  test('buildEpisodesScript wraps the chapter result with __rel', () {
    final js = buildEpisodesScript(_rule);
    expect(js, contains(
        '__ev("//div[2]/div[2]/div[2]/div/div[2]/div[1]//div", document)'));
    expect(js, contains('__ev(__rel("//a"), roads[r])'));
    expect(js, contains('roads.length > 1'));
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
