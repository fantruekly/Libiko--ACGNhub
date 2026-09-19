import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/video/headless_browser.dart';
import 'package:libiko/core/video/maccms.dart';
import 'package:libiko/core/video/stream_resolver.dart';

class _FakeMacCmsResolver extends MacCmsResolver {
  _FakeMacCmsResolver(this.candidate);
  final MediaCandidate? candidate;

  @override
  Future<MediaCandidate?> resolve(
    String playPageUrl, {
    String? userAgent,
    String? referer,
    Duration timeout = const Duration(seconds: 15),
  }) async =>
      candidate;
}

class _HeaderAdapter implements HttpClientAdapter {
  _HeaderAdapter({required this.okWithoutReferer});
  final bool okWithoutReferer;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    final hasReferer = options.headers.containsKey('Referer');
    final ok = hasReferer ? false : okWithoutReferer;
    return ResponseBody.fromString(
      ok ? 'x' : 'no',
      ok ? 200 : 400,
      headers: {
        Headers.contentTypeHeader: [Headers.textPlainContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('returns the MacCMS candidate without starting a headless browser',
      () async {
    final resolver = StreamResolver(
      maccms: _FakeMacCmsResolver(
          const MediaCandidate('https://cdn.test/x/index.m3u8')),
    );
    final result = await resolver.resolve('https://page/play');
    expect(result?.url, 'https://cdn.test/x/index.m3u8');
  });

  test('drops the Referer when the candidate only works without it',
      () async {
    final adapter = _HeaderAdapter(okWithoutReferer: true);
    final dio = Dio()..httpClientAdapter = adapter;
    final resolver = StreamResolver(
      maccms: _FakeMacCmsResolver(const MediaCandidate(
        'https://cdn.test/x.m3u8',
        headers: {'User-Agent': 'UA', 'Referer': 'https://site/'},
      )),
      dio: dio,
    );

    final result = await resolver.resolve('https://page/play');

    expect(result?.url, 'https://cdn.test/x.m3u8');
    expect(result?.headers['Referer'], isNull);
    expect(result?.headers['User-Agent'], 'UA');
  });
}
