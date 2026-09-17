import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/video/api_rule.dart';
import 'package:libiko/core/video/source_rule.dart';

void main() {
  test('restricted jsonpath reads arrays and fields', () {
    final data = {
      'data': {
        'records': [
          {'title': 'A', 'id': '1'},
          {'title': 'B', 'id': '2'},
        ],
      },
    };
    expect(jsonPathAll(data, r'$.data.records[*].title'), ['A', 'B']);
    expect(jsonPathAll(data, r'$.data.records[0].id'), ['1']);
  });

  test('episode page template substitutes tokens', () {
    final url = resolveEpisodeUrl(
      'https://x/episode/@episodeUrl?i=@episodeIndex',
      {'episodeUrl': 'abc', 'episodeIndex': '3'},
    );
    expect(url, 'https://x/episode/abc?i=3');
  });

  test('restricted jsonpath returns empty for missing paths', () {
    final data = {
      'data': {'records': []},
    };
    expect(jsonPathAll(data, r'$.data.missing[*].title'), isEmpty);
    expect(jsonPathAll(data, r'$.data.records[5].id'), isEmpty);
    expect(jsonPathAll(data, 'not-a-path'), isEmpty);
  });

  test('episode page template keeps unknown tokens and prefers long keys',
      () {
    expect(
      resolveEpisodeUrl('@episodeIndex-@unknown', {'episodeIndex': '7'}),
      '7-@unknown',
    );
    expect(
      resolveEpisodeUrl('@road-@roadIndex', {'road': 'a', 'roadIndex': '2'}),
      'a-2',
    );
  });

  test('api-mode rules parse without xpath fields', () {
    final rule = SourceRule.fromJson({
      'name': 'sorani',
      'baseURL': 'https://api.test/',
      'searchMode': 'api',
      'chapterMode': 'api',
      'searchApiConfig': {
        'request': {'url': 'https://api.test/search?wd=@keyword'},
        'listPath': r'$.data[*]',
        'namePath': r'$.name',
        'sourcePath': r'$.url',
      },
      'chapterApiConfig': {
        'request': {'url': 'https://api.test/eps?url=@source'},
      },
    });
    expect(rule.searchMode, 'api');
    expect(rule.chapterMode, 'api');
    expect(rule.searchUrl, '');
    expect(rule.searchList, '');
    expect(rule.searchApiConfig, isNotNull);
    expect(rule.chapterApiConfig, isNotNull);
  });

  test('xpath-mode rules still require xpath fields', () {
    expect(
      () => SourceRule.fromJson({'name': 'x', 'baseURL': 'https://a/'}),
      throwsFormatException,
    );
  });
}
