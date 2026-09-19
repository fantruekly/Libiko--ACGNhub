import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/video/rule_source.dart';
import 'package:libiko/core/video/source_rule.dart';

const _rule = SourceRule(
  name: '七色番',
  baseUrl: 'https://www.7sefun.top',
  searchUrl: 'https://www.7sefun.top/vodsearch/-------------.html?wd=@keyword',
  searchList: '//div',
  searchName: '//div[2]/text()',
  searchResult: '//a',
  chapterRoads: '//div',
  chapterResult: '//a',
);

void main() {
  test('mapSearch resolves relative hrefs and drops empty rows', () {
    final items = RuleVideoSource.mapSearch(_rule, [
      {'name': '进击的巨人', 'href': '/vod/1.html'},
      {'name': '第二季', 'href': 'https://other.test/vod/2.html'},
      {'name': '', 'href': '/vod/3.html'},
      {'name': '空链接', 'href': ''},
    ]);
    expect(items, hasLength(2));
    expect(items[0].title, '进击的巨人');
    expect(items[0].detailUrl, 'https://www.7sefun.top/vod/1.html');
    expect(items[1].detailUrl, 'https://other.test/vod/2.html');
  });

  test('mapEpisodes assigns 0-based indexes and fallback titles', () {
    final eps = RuleVideoSource.mapEpisodes(_rule, [
      {'title': '第1集', 'href': '/play/1'},
      {'title': '', 'href': '//cdn.test/play/2'},
    ]);
    expect(eps, hasLength(2));
    expect(eps[0].index, 0);
    expect(eps[0].playUrl, 'https://www.7sefun.top/play/1');
    expect(eps[1].title, '第2集');
    expect(eps[1].playUrl, 'https://cdn.test/play/2');
  });

  test('mapEpisodes keeps road-prefixed titles from multiple roads', () {
    final eps = RuleVideoSource.mapEpisodes(_rule, [
      {'title': '线路1 第1集', 'href': '/play/1'},
      {'title': '线路1 第2集', 'href': '/play/2'},
      {'title': '线路2 第1集', 'href': '/play/3'},
    ]);
    expect(eps, hasLength(3));
    expect(eps[0].title, '线路1 第1集');
    expect(eps[2].title, '线路2 第1集');
    expect(eps[2].playUrl, 'https://www.7sefun.top/play/3');
  });

  test('mapSearch returns empty for non-list input', () {
    expect(RuleVideoSource.mapSearch(_rule, null), isEmpty);
    expect(RuleVideoSource.mapSearch(_rule, 'oops'), isEmpty);
  });

  test('resolveUrl keeps the original scheme and normalizes slashes', () {
    expect(RuleVideoSource.resolveUrl('http://a.test/x', 'https://b.test'),
        'http://a.test/x');
    expect(RuleVideoSource.resolveUrl('https://a.test/x', 'https://b.test'),
        'https://a.test/x');
    expect(RuleVideoSource.resolveUrl('//a.test/x', 'https://b.test'),
        'https://a.test/x');
    expect(RuleVideoSource.resolveUrl('vod/1', 'https://b.test/'),
        'https://b.test/vod/1');
  });
}
