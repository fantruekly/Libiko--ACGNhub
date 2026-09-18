import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/video/maccms.dart';

const _encrypted =
    'JTY4JTc0JTc0JTcwJTczJTNBJTJGJTJGJTZEJTYxJTZGJTM2JTJFJTZBJTc4JTY0JTc1JTZFJTcyJTc1JTY5JTJFJTc0JTZGJTcwJTJGJTY0JTJGJTY2JTY5JTZDJTY1JTJGJTM1JTYyJTY0JTY2JTY2JTMzJTMxJTYyJTMzJTMwJTY0JTYzJTMwJTMyJTM0JTM3JTMzJTYxJTY2JTMwJTY0JTMxJTMyJTY0JTY2JTYxJTM5JTM4JTM5JTMzJTMwJTM0JTJGJTI1JTQ1JTM3JTI1JTQxJTQzJTI1JTQxJTQzJTMwJTMxJTI1JTQ1JTM5JTI1JTM5JTQyJTI1JTM4JTM2JTJFJTZEJTcwJTM0';
const _decoded =
    'https://mao6.jxdunrui.top/d/file/5bdff31b30dc02473af0d12dfa989304/%E7%AC%AC01%E9%9B%86.mp4';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.body);
  final String body;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(body, 200, headers: {
      Headers.contentTypeHeader: [Headers.textPlainContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('resolves an encrypted MacCMS play page', () async {
    final adapter = _FakeAdapter(
        '<script>var player_aaaa={"encrypt":2,"url":"$_encrypted"};</script>');
    final dio = Dio()..httpClientAdapter = adapter;
    final candidate = await MacCmsResolver(dio: dio)
        .resolve('https://www.7sefun.top/vodplay/26976-2-1.html');

    expect(candidate?.url, _decoded);
    expect(candidate?.headers['Referer'], 'https://www.7sefun.top/');
    expect(adapter.last?.headers['Referer'], 'https://www.7sefun.top/');
  });

  test('returns null when there is no player config', () async {
    final adapter = _FakeAdapter('<html>none</html>');
    final dio = Dio()..httpClientAdapter = adapter;
    expect(await MacCmsResolver(dio: dio).resolve('https://x/play'), isNull);
  });

  test('returns null when the decrypted URL is not a media file', () async {
    final adapter = _FakeAdapter('<script>var player_aaaa={"encrypt":0,'
        '"url":"https://www.lmm85.com/play/7817_1_1.html"};</script>');
    final dio = Dio()..httpClientAdapter = adapter;
    expect(await MacCmsResolver(dio: dio).resolve('https://x/play'), isNull);
  });
}
