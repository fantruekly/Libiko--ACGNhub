import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/video/agedm_source.dart';

class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? last;
  final String body;
  _RecordingAdapter(this.body);

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

void main() {
  test('parseSearch extracts title, id, and normalized detail URL', () {
    const html = '''
    <div class="card">
      <a href="https://www.agedm.io/detail/20260029"><img src="https://img/x.jpg"></a>
      <h5 class="card-title"><a href="http://www.agedm.io/detail/20260029">葬送的芙莉莲 第二季</a></h5>
    </div>''';

    final items = AgedmSource.parseSearch(html);
    expect(items, hasLength(1));
    final it = items.first;
    expect(it.id, '20260029');
    expect(it.title, '葬送的芙莉莲 第二季');
    expect(it.detailUrl, 'https://www.agedm.io/detail/20260029');
    expect(it.cover, 'https://img/x.jpg');
  });

  test('parseEpisodes extracts ordered play links', () {
    const html = '''
    <div class="playlist">
      <a href="/play/20230207/1/1">第1集</a>
      <a href="/play/20230207/1/2">第2集</a>
    </div>''';

    final eps = AgedmSource.parseEpisodes(html, 'https://www.agedm.io');
    expect(eps, hasLength(2));
    expect(eps[0].title, '第1集');
    expect(eps[0].index, 0);
    expect(eps[0].playUrl, 'https://www.agedm.io/play/20230207/1/1');
    expect(eps[1].index, 1);
  });

  test('search sends the query parameter to /search', () async {
    final adapter = _RecordingAdapter('<h5 class="card-title"><a href="/detail/1">T</a></h5>');
    final dio = Dio(BaseOptions(baseUrl: 'https://www.agedm.io', responseType: ResponseType.plain))
      ..httpClientAdapter = adapter;
    final source = AgedmSource(dio: dio);

    await source.search('葬送的芙莉莲');

    expect(adapter.last!.path, '/search');
    expect(adapter.last!.queryParameters['query'], '葬送的芙莉莲');
  });
}
