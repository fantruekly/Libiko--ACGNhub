import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/game/nekogal_source.dart';

String _listPageHtml(int count, {String? next, int base = 0}) {
  final items = StringBuffer();
  for (var i = 0; i < count; i++) {
    final id = base + i;
    items.write(
        '<posts class="posts-item list ajax-item">'
        '<div class="item-thumbnail"><a href="/archives/$id"><img data-src="https://pan.nekogal.top/f/x/$id.jpg"></a></div>'
        '<h2 class="item-heading"><a href="/archives/$id">游戏$id</a></h2>'
        '</posts>');
  }
  final nav = next == null
      ? '<nav class="navigation pagination"><span class="page-numbers current">1</span></nav>'
      : '<nav class="navigation pagination"><a class="next page-numbers" href="$next">下一页</a></nav>';
  return '<div class="posts-row ajaxpager">$items</div>$nav';
}

const _detailHtml = '''
<div class="single-head-cover"><div class="graphic single-cover">
  <img class="lazyload" data-src="https://pan.nekogal.top/f/x/cover.jpg">
  <h1 class="article-title">【PC游戏/机翻】制服女友3</h1>
  <div class="post-metas"><item class="meta-view">451</item></div>
</div></div>
<div class="article-header"><span title="2026年09月14日 20:56发布">x</span></div>
<div class="article-content"><div class="wp-posts-content"><p>简介。</p></div></div>
''';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.htmlByPath);
  final Map<String, String> htmlByPath;
  final List<String> requested = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requested.add(options.path);
    final html = htmlByPath[options.path] ?? '';
    return ResponseBody.fromString(html, 200, headers: {
      Headers.contentTypeHeader: ['text/plain; charset=utf-8'],
    });
  }
}

class _FlakyAdapter implements HttpClientAdapter {
  _FlakyAdapter(this.htmlByPath, {this.failFirst = 0});
  final Map<String, String> htmlByPath;
  final int failFirst;
  int calls = 0;
  final List<String> requested = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls++;
    if (calls <= failFirst) {
      throw DioException(requestOptions: options, message: 'handshake failed');
    }
    requested.add(options.path);
    final html = htmlByPath[options.path] ?? '';
    return ResponseBody.fromString(html, 200, headers: {
      Headers.contentTypeHeader: ['text/plain; charset=utf-8'],
    });
  }
}

void main() {
  test('browse requests two source pages and returns 24', () async {
    final dio = Dio(BaseOptions(baseUrl: nekogalBaseUrl));
    final adapter = _FakeAdapter({
      '/archives/category/pcgame':
          _listPageHtml(12, next: '/archives/category/pcgame/page/2', base: 100),
      '/archives/category/pcgame/page/2':
          _listPageHtml(12, next: '/archives/category/pcgame/page/3', base: 200),
    });
    dio.httpClientAdapter = adapter;
    final source = NekogalSource(dio: dio);

    final list = await source.browse('pcgame', page: 1);
    expect(adapter.requested,
        ['/archives/category/pcgame', '/archives/category/pcgame/page/2']);
    expect(list.items, hasLength(24));
    expect(list.items.first.id, '100');
    expect(list.items.last.id, '211');
    expect(list.hasMore, isTrue);
  });

  test('retries transient connection failures', () async {
    final dio = Dio(BaseOptions(baseUrl: nekogalBaseUrl));
    final adapter = _FlakyAdapter(
      {
        '/archives/category/pcgame': _listPageHtml(12,
            next: '/archives/category/pcgame/page/2', base: 100),
        '/archives/category/pcgame/page/2': _listPageHtml(12,
            next: '/archives/category/pcgame/page/3', base: 200),
      },
      failFirst: 2,
    );
    dio.httpClientAdapter = adapter;
    final source = NekogalSource(dio: dio);

    final list = await source.browse('pcgame', page: 1);
    expect(list.items, hasLength(24));
    expect(list.items.first.id, '100');
  });

  test('detail requests /archives/<id> and parses fields', () async {
    final dio = Dio(BaseOptions(baseUrl: nekogalBaseUrl));
    final adapter = _FakeAdapter({'/archives/6661': _detailHtml});
    dio.httpClientAdapter = adapter;
    final source = NekogalSource(dio: dio);

    final detail = await source.detail('6661');
    expect(adapter.requested, ['/archives/6661']);
    expect(detail.game.title, '【PC游戏/机翻】制服女友3');
    expect(detail.sourceUrl, '$nekogalBaseUrl/archives/6661');
  });

  test('exposes identity and browse options', () {
    final source = NekogalSource(dio: Dio());
    expect(source.id, 'nekogal');
    expect(source.name, 'NekoGAL');
    expect(source.browseOptions.map((o) => o.key),
        ['pcgame', 'hhzy', 'srzy', 'pegame']);
    expect(source.browseOptions.first.label, 'PC资源');
  });

  test('search requests the keyword and parses results', () async {
    final dio = Dio(BaseOptions(baseUrl: nekogalBaseUrl));
    final adapter = _FakeAdapter({
      '/?s=%E9%AD%94%E5%A5%B3': _listPageHtml(2, base: 100),
    });
    dio.httpClientAdapter = adapter;
    final source = NekogalSource(dio: dio);

    final results = await source.search('魔女');
    expect(adapter.requested, ['/?s=%E9%AD%94%E5%A5%B3']);
    expect(results.map((g) => g.id), ['100', '101']);
  });
}
