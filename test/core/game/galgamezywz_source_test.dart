import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/game/galgamezywz_source.dart';

const _listHtml = '''
<div class="posts-warp">
  <article class="post-item item-grid">
    <a class="media-img" href="/game/1207" data-bg="https://game.galgamezywz.org/wp-content/uploads/cover.jpg"></a>
    <h2 class="entry-title"><a href="/game/1207">金辉恋曲四重奏</a></h2>
    <div class="entry-meta"><span class="meta-views">4.3K</span></div>
  </article>
</div>
<nav class="page-nav"><ul class="pagination">
  <li class="page-item"><a class="page-link page-next" href="/page/2">下一页</a></li>
</ul></nav>
''';

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
  test('browse requests the option path and parses the list', () async {
    final dio = Dio(BaseOptions(baseUrl: galgameZywzBaseUrl));
    final adapter = _FakeAdapter({'/lm/galgame': _listHtml});
    dio.httpClientAdapter = adapter;
    final source = GalgameZywzSource(dio: dio);

    final list = await source.browse('galgame', page: 1);
    expect(adapter.requested, ['/lm/galgame']);
    expect(list.items.single.id, '1207');
    expect(list.items.single.title, '金辉恋曲四重奏');
    expect(list.page, 1);
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
