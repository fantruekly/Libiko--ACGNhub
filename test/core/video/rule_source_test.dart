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
  test('preferred line keeps identities, contiguous indexes and fallback', () {
    final rule = SourceRule.fromJson({
      'name': 'test',
      'baseURL': 'https://test/',
      'searchURL': 'https://test/search',
      'searchList': '//div',
      'searchName': '//a',
      'searchResult': '//a',
      'chapterRoads': '//ul',
      'chapterResult': '//a',
      'preferredLineIds': ['missing', 'road:1', 'road:1'],
    });
    final rows = [
      {'title': '第1集', 'href': '/a1', 'lineId': 'road:0'},
      {'title': '第2集', 'href': '/a2', 'lineId': 'road:0'},
      {'title': '第1集', 'href': '/b1', 'lineId': 'road:1'},
      {'title': '第2集', 'href': '/b2', 'lineId': 'road:1'},
    ];
    final episodes = RuleVideoSource.mapEpisodes(rule, rows);
    expect(episodes.map((e) => e.lineId),
        ['road:1', 'road:1', 'road:0', 'road:0']);
    expect(episodes.map((e) => e.index), [0, 1, 2, 3]);
    expect(episodes.map((e) => e.playUrl), [
      'https://test/b1',
      'https://test/b2',
      'https://test/a1',
      'https://test/a2'
    ]);
    expect(episodes[0].episodeKey, episodes[2].episodeKey);
    expect(
        RuleVideoSource.mapEpisodes(rule, rows.take(2).toList()).first.lineId,
        'road:0');
  });
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
    expect(eps.map((e) => e.lineId), ['road:0', 'road:0', 'road:1']);
    expect(eps[0].sourceId, _rule.id);
    expect(eps[0].episodeKey, eps[2].episodeKey);
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
