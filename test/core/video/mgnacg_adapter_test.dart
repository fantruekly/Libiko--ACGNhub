import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/video/mgnacg_adapter.dart';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:libiko/core/video/maccms.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancel) async {
    requests.add(options);
    return ResponseBody.fromString(
        requests.length == 1
            ? '<script>var player_aaaa={"from":"2_","encrypt":2,"url":"abc%2Fdef"};</script>'
            : page(
                'j12jMyzX2QB5dklqtP9GJid+FcoMVaYTsYZbyusp3a5ltn9ztCE5YO8LWEQ8sbBG'),
        200);
  }

  @override
  void close({bool force = false}) {}
}

String page(String cipher) => '''
<meta charset="UTF-8" id="now_3651294708">
<meta name="viewport" content="width=device-width" id="now_62wZqgZnew">
<script>var config = {"url":"$cipher"};</script>
''';

void main() {
  test('resolver follows the normal parser instead of generic base64 handling',
      () async {
    final adapter = _Adapter();
    final resolver = MacCmsResolver(dio: Dio()..httpClientAdapter = adapter);
    final result =
        await resolver.resolve('https://www.mgnacg.com/bangumi/982-2-1/');
    expect(result?.url, 'https://cdn.test/ep01/index.m3u8');
    expect(result?.headers.containsKey('Referer'), isFalse);
    expect(result?.headersResolved, isTrue);
    expect(adapter.requests[1].uri.host, 'play.mknacg.top');
    expect(adapter.requests[1].uri.queryParameters['url'], 'abc/def');
  });
  test('public parser known vector derives dynamic key and decodes media', () {
    // Independently generated with Node crypto AES-128-CBC, not the adapter.
    expect(
        MgnacgAdapter.mediaFromParser(page(
            'j12jMyzX2QB5dklqtP9GJid+FcoMVaYTsYZbyusp3a5ltn9ztCE5YO8LWEQ8sbBG')),
        'https://cdn.test/ep01/index.m3u8');
  });
  test(
      'empty parser resource, non-media, scripts and corrupt response fail closed',
      () {
    for (final cipher in [
      'A8QrWt8Yp0ktR2r1Th0kiQ==',
      'FE4dAUAQmsU/ccsaKsLGqFrSLulcf5QLDXLeprbfsQ0=',
      'j12jMyzX2QB5dklqtP9GJvISmA3gB73i6GdZ9oQDRT8=',
      'bad=',
    ]) {
      expect(MgnacgAdapter.mediaFromParser(page(cipher)), isNull);
    }
    expect(
        MgnacgAdapter.mediaFromParser(
            page('bad').replaceAll('3651294708', '0000000000')),
        isNull);
  });
  test('adapter only routes its exact site and public known parser lines', () {
    expect(MgnacgAdapter.supports('https://www.mgnacg.com/bangumi/982-2-1/'),
        isTrue);
    expect(MgnacgAdapter.supports('https://www.mgnacg.com.evil/bangumi/1'),
        isFalse);
    expect(MgnacgAdapter.supports('https://other.test/bangumi/1'), isFalse);
    expect(MgnacgAdapter.parserUrl('2_', 'ab%2Fcd%3D'),
        'https://play.mknacg.top:8585/cloudplay/?url=ab%2Fcd%3D');
    expect(MgnacgAdapter.parserUrl('unknown', 'abc'), isNull);
    expect(MgnacgAdapter.parserUrl('2_', 'abc&url=other'), isNull);
  });
}
