import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/game/galgamezywz_source.dart';

String _listHtmlWith(int count, {String? next, String idPrefix = 'g'}) {
  final items = StringBuffer();
  for (var i = 0; i < count; i++) {
    items.write(
        '<article class="post-item item-grid">'
        '<a class="media-img" href="/game/$idPrefix$i" data-bg="https://game.galgamezywz.org/wp-content/uploads/$idPrefix$i.jpg"></a>'
        '<h2 class="entry-title"><a href="/game/$idPrefix$i">游戏$idPrefix$i</a></h2>'
        '</article>');
  }
  final nav = next == null
      ? '<nav class="page-nav"><ul class="pagination">'
          '<li class="page-item disabled"><span class="page-link">N/N</span></li>'
          '</ul></nav>'
      : '<nav class="page-nav"><ul class="pagination">'
          '<li class="page-item"><a class="page-link page-next" href="$next">下一页</a></li>'
          '</ul></nav>';
  return '<div class="posts-warp">$items</div>$nav';
}

const _detailHtml = '''
<div class="archive-shop">
  <div class="img-box"><img src="https://game.galgamezywz.org/wp-content/uploads/cover.jpg"></div>
  <div class="info-box"><ul class="article-meta">
    <li>资源分类: <a href="/lm/galgame">galgame资源推荐</a></li>
    <li>游戏大小: 14.3GB</li>
  </ul></div>
</div>
<h1 class="post-title">金辉恋曲四重奏</h1>
<article class="post-content"><p>简介。</p></article>
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

void main() {
  test('browse page 1 requests four source pages and returns 48', () async {
    final dio = Dio(BaseOptions(baseUrl: galgameZywzBaseUrl));
    final adapter = _FakeAdapter({
      '/lm/galgame':
          _listHtmlWith(12, next: '/lm/galgame/page/2', idPrefix: 'a'),
      '/lm/galgame/page/2':
          _listHtmlWith(12, next: '/lm/galgame/page/3', idPrefix: 'b'),
      '/lm/galgame/page/3':
          _listHtmlWith(12, next: '/lm/galgame/page/4', idPrefix: 'c'),
      '/lm/galgame/page/4':
          _listHtmlWith(12, next: '/lm/galgame/page/5', idPrefix: 'd'),
    });
    dio.httpClientAdapter = adapter;
    final source = GalgameZywzSource(dio: dio);

    final list = await source.browse('galgame', page: 1);
    expect(adapter.requested, [
      '/lm/galgame',
      '/lm/galgame/page/2',
      '/lm/galgame/page/3',
      '/lm/galgame/page/4',
    ]);
    expect(list.items, hasLength(48));
    expect(list.items.first.id, 'a0');
    expect(list.items.last.id, 'd11');
    expect(list.page, 1);
    expect(list.hasMore, isTrue);
  });

  test('browse page 2 requests the next four source pages', () async {
    final dio = Dio(BaseOptions(baseUrl: galgameZywzBaseUrl));
    final adapter = _FakeAdapter({
      '/lm/galgame/page/5':
          _listHtmlWith(12, next: '/lm/galgame/page/6', idPrefix: 'e'),
      '/lm/galgame/page/6':
          _listHtmlWith(12, next: '/lm/galgame/page/7', idPrefix: 'f'),
      '/lm/galgame/page/7':
          _listHtmlWith(12, next: '/lm/galgame/page/8', idPrefix: 'g'),
      '/lm/galgame/page/8':
          _listHtmlWith(12, next: '/lm/galgame/page/9', idPrefix: 'h'),
    });
    dio.httpClientAdapter = adapter;
    final source = GalgameZywzSource(dio: dio);

    final list = await source.browse('galgame', page: 2);
    expect(adapter.requested, [
      '/lm/galgame/page/5',
      '/lm/galgame/page/6',
      '/lm/galgame/page/7',
      '/lm/galgame/page/8',
    ]);
    expect(list.items, hasLength(48));
    expect(list.items.first.id, 'e0');
    expect(list.page, 2);
    expect(list.hasMore, isTrue);
  });

  test('browse stops early when a source page has no next link', () async {
    final dio = Dio(BaseOptions(baseUrl: galgameZywzBaseUrl));
    final adapter = _FakeAdapter({
      '/lm/galgame':
          _listHtmlWith(12, next: '/lm/galgame/page/2', idPrefix: 'a'),
      '/lm/galgame/page/2': _listHtmlWith(12, idPrefix: 'b'),
    });
    dio.httpClientAdapter = adapter;
    final source = GalgameZywzSource(dio: dio);

    final list = await source.browse('galgame', page: 1);
    expect(adapter.requested, ['/lm/galgame', '/lm/galgame/page/2']);
    expect(list.items, hasLength(24));
    expect(list.hasMore, isFalse);
  });

  test('browse trims a 52-item page to 48', () async {
    final dio = Dio(BaseOptions(baseUrl: galgameZywzBaseUrl));
    final adapter = _FakeAdapter({
      '/': _listHtmlWith(16, next: '/page/2', idPrefix: 's'),
      '/page/2': _listHtmlWith(12, next: '/page/3', idPrefix: 't'),
      '/page/3': _listHtmlWith(12, next: '/page/4', idPrefix: 'u'),
      '/page/4': _listHtmlWith(12, next: '/page/5', idPrefix: 'v'),
    });
    dio.httpClientAdapter = adapter;
    final source = GalgameZywzSource(dio: dio);

    final list = await source.browse('latest', page: 1);
    expect(adapter.requested, ['/', '/page/2', '/page/3', '/page/4']);
    expect(list.items, hasLength(48));
    expect(list.items.first.id, 's0');
    expect(list.items.last.id, 'v7');
    expect(list.hasMore, isTrue);
  });

  test('detail requests /game/<id> and parses fields', () async {
    final dio = Dio(BaseOptions(baseUrl: galgameZywzBaseUrl));
    final adapter = _FakeAdapter({'/game/1207': _detailHtml});
    dio.httpClientAdapter = adapter;
    final source = GalgameZywzSource(dio: dio);

    final detail = await source.detail('1207');
    expect(adapter.requested, ['/game/1207']);
    expect(detail.game.title, '金辉恋曲四重奏');
    expect(detail.size, '14.3GB');
    expect(detail.sourceUrl, '$galgameZywzBaseUrl/game/1207');
  });

  test('exposes identity and browse options', () {
    final source = GalgameZywzSource(dio: Dio());
    expect(source.id, 'galgamezywz');
    expect(source.name, 'galgame大玩家');
    expect(source.browseOptions.map((o) => o.key),
        ['latest', 'wanjiareping', 'galgame', 'haoyoutuijian', 'wanjiazuiai']);
    expect(source.browseOptions.first.label, '最近更新');
  });
}
