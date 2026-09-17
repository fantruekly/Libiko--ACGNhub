import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/video/api_rule.dart';
import 'package:libiko/core/video/source_rule.dart';

class _JsonAdapter implements HttpClientAdapter {
  RequestOptions? last;
  final String body;
  _JsonAdapter(this.body);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(body, 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

SourceRule _apiRule({
  required Map<String, dynamic> searchApiConfig,
  required Map<String, dynamic> chapterApiConfig,
}) {
  return SourceRule.fromJson({
    'name': 'api-test',
    'baseURL': 'https://api.test/',
    'searchMode': 'api',
    'chapterMode': 'api',
    'searchApiConfig': searchApiConfig,
    'chapterApiConfig': chapterApiConfig,
  });
}

ApiRuleClient _client(SourceRule rule, _JsonAdapter adapter) {
  final dio = Dio(BaseOptions(responseType: ResponseType.plain))
    ..httpClientAdapter = adapter;
  return ApiRuleClient(rule, dio: dio);
}

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

  test('search maps list/name/source paths to VideoItems', () async {
    final adapter = _JsonAdapter('''
      {"data": [
        {"name": "葬送的芙莉莲", "url": "/detail/1"},
        {"name": "地狱乐", "url": "https://other.test/detail/2"}
      ]}''');
    final rule = _apiRule(
      searchApiConfig: {
        'request': {'url': 'https://api.test/search?wd=@keyword'},
        'listPath': r'$.data[*]',
        'namePath': r'$.name',
        'sourcePath': r'$.url',
      },
      chapterApiConfig: {
        'request': {'url': 'https://api.test/eps?url=@source'},
      },
    );
    final client = _client(rule, adapter);

    final items = await client.search('芙莉莲');

    expect(items, hasLength(2));
    expect(items[0].title, '葬送的芙莉莲');
    expect(items[0].id, 'https://api.test/detail/1');
    expect(items[0].detailUrl, 'https://api.test/detail/1');
    expect(items[1].id, 'https://other.test/detail/2');
    expect(adapter.last!.uri.path, '/search');
    expect(adapter.last!.uri.queryParameters['wd'], '芙莉莲');
  });

  test('nested episodes parse without a road prefix for a single road',
      () async {
    final adapter = _JsonAdapter('''
      {"episodes": [
        {"name": "第1集", "url": "/e/1"},
        {"name": "第2集", "url": "/e/2"}
      ]}''');
    final rule = _apiRule(
      searchApiConfig: {
        'request': {'url': 'https://api.test/search?wd=@keyword'},
      },
      chapterApiConfig: {
        'request': {'url': 'https://api.test/eps?url=@source'},
        'roadsPath': '',
        'episodesPath': r'$.episodes[*]',
        'episodeNamePath': r'$.name',
        'episodeUrlPath': r'$.url',
      },
    );
    final client = _client(rule, adapter);

    final episodes = await client.episodes('https://api.test/detail/1');

    expect(episodes.map((e) => e.title), ['第1集', '第2集']);
    expect(episodes.map((e) => e.playUrl),
        ['https://api.test/e/1', 'https://api.test/e/2']);
    expect(episodes.map((e) => e.index), [0, 1]);
  });

  test('nested multi-road episodes prefix titles with the road name',
      () async {
    final adapter = _JsonAdapter('''
      {"data": {"roads": [
        {"name": "线路1", "episodes": [
          {"name": "第1集", "url": "/1/1"},
          {"name": "第2集", "url": "/1/2"}
        ]},
        {"name": "线路2", "episodes": [
          {"name": "第1集", "url": "/2/1"}
        ]}
      ]}}''');
    final rule = _apiRule(
      searchApiConfig: {
        'request': {'url': 'https://api.test/search?wd=@keyword'},
      },
      chapterApiConfig: {
        'request': {'url': 'https://api.test/eps?url=@source'},
        'roadsPath': r'$.data.roads[*]',
        'roadNamePath': r'$.name',
        'episodesPath': r'$.episodes[*]',
        'episodeNamePath': r'$.name',
        'episodeUrlPath': r'$.url',
      },
    );
    final client = _client(rule, adapter);

    final episodes = await client.episodes('https://api.test/detail/1');

    expect(episodes.map((e) => e.title),
        ['线路1 第1集', '线路1 第2集', '线路2 第1集']);
    expect(episodes.map((e) => e.index), [0, 1, 2]);
  });

  test('episodePage url and query templates are substituted', () async {
    final adapter = _JsonAdapter('''
      {"episodes": [
        {"name": "第1集", "url": "abc"},
        {"name": "第2集", "url": "def"}
      ]}''');
    final rule = _apiRule(
      searchApiConfig: {
        'request': {'url': 'https://api.test/search?wd=@keyword'},
      },
      chapterApiConfig: {
        'request': {'url': 'https://api.test/eps?url=@source'},
        'roadsPath': '',
        'episodesPath': r'$.episodes[*]',
        'episodeNamePath': r'$.name',
        'episodeUrlPath': r'$.url',
        'episodePage': {
          'url': 'https://play.test/@episodeUrl',
          'query': {'i': '@episodeIndex', 'n': '@episodeNumber'},
        },
      },
    );
    final client = _client(rule, adapter);

    final episodes = await client.episodes('https://api.test/detail/1');

    expect(episodes.map((e) => e.playUrl), [
      'https://play.test/abc?i=0&n=1',
      'https://play.test/def?i=1&n=2',
    ]);
  });
}
