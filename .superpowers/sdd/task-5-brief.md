## Task 5: GalgameZywzSource 类（HTTP 接线）

**Files:**
- Modify: `lib/core/game/galgamezywz_source.dart`（追加 `GalgameZywzSource` 类与 dio import）
- Test: `test/core/game/galgamezywz_source_test.dart`

**Interfaces:**
- Consumes: Task 2 的 `GameSource`、Task 3/4 的解析函数。
- Produces: `class GalgameZywzSource implements GameSource { GalgameZywzSource({Dio? dio}); ... }`，`id='galgamezywz'`、`name='galgame大玩家'`、`browseOptions`（latest/wanjiareping/galgame/haoyoutuijian/wanjiazuiai）、`browse`、`detail`。

- [ ] **Step 1: Write the failing test**

Create `test/core/game/galgamezywz_source_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/game/galgamezywz_source_test.dart`
Expected: FAIL（`GalgameZywzSource` 未定义）。

- [ ] **Step 3: Write minimal implementation**

在 `lib/core/game/galgamezywz_source.dart` 顶部加入：

```dart
import 'package:dio/dio.dart';
```

在文件末尾追加：

```dart
class GalgameZywzSource implements GameSource {
  GalgameZywzSource({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: galgameZywzBaseUrl,
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 20),
              headers: {
                'User-Agent': galgameZywzUserAgent,
                'Accept':
                    'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
                'Referer': '$galgameZywzBaseUrl/',
              },
            ));

  final Dio _dio;

  @override
  String get id => 'galgamezywz';

  @override
  String get name => 'galgame大玩家';

  @override
  String get baseUrl => galgameZywzBaseUrl;

  @override
  List<GameBrowseOption> get browseOptions => const [
        GameBrowseOption(key: 'latest', label: '最近更新'),
        GameBrowseOption(key: 'wanjiareping', label: '玩家热评'),
        GameBrowseOption(key: 'galgame', label: '资源推荐'),
        GameBrowseOption(key: 'haoyoutuijian', label: '好游推荐'),
        GameBrowseOption(key: 'wanjiazuiai', label: '玩家最爱'),
      ];

  @override
  Future<GameList> browse(String optionKey, {int page = 1}) async {
    final html = await _get(galgameZywzBrowsePath(optionKey, page));
    final items = parseGameList(html);
    final hasMore = parseHasNextPage(html, itemCount: items.length);
    return GameList(items: items, page: page, hasMore: hasMore);
  }

  @override
  Future<GameDetail> detail(String id) async {
    final html = await _get('/game/$id');
    return parseGameDetail(html, '$galgameZywzBaseUrl/game/$id');
  }

  Future<String> _get(String path) async {
    final res = await _dio.get<String>(
      path,
      options: Options(responseType: ResponseType.plain),
    );
    final data = res.data;
    if (res.statusCode != 200 || data == null) {
      throw Exception('galgamezywz 请求失败：$path (${res.statusCode})');
    }
    return data;
  }
}
```

并把顶部 import 区块补上 `game_source.dart`：

```dart
import 'game_source.dart';
```

（最终 `galgamezywz_source.dart` 顶部 import 顺序：`package:dio/dio.dart`、`package:html/dom.dart as dom`、`package:html/parser.dart as html_parser`、`game_source.dart`、`models.dart`。）

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/game/galgamezywz_source_test.dart`
Expected: PASS（3 tests）。

- [ ] **Step 5: Commit**

```bash
git add lib/core/game/galgamezywz_source.dart test/core/game/galgamezywz_source_test.dart
git commit -m "feat(game): add GalgameZywzSource with dio wiring"
```

---

