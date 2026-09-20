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

class _UrlAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final ok = options.uri.path.endsWith('ok.m3u8');
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

class _FlakyMacCmsResolver extends MacCmsResolver {
  _FlakyMacCmsResolver(this.candidates);
  final List<MediaCandidate?> candidates;
  int calls = 0;

  @override
  Future<MediaCandidate?> resolve(
    String playPageUrl, {
    String? userAgent,
    String? referer,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final index = calls < candidates.length ? calls : candidates.length - 1;
    calls++;
    return candidates[index];
  }
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
    final dio = Dio()
      ..httpClientAdapter = _HeaderAdapter(okWithoutReferer: true);
    final resolver = StreamResolver(
      maccms: _FakeMacCmsResolver(
          const MediaCandidate('https://cdn.test/x/index.m3u8')),
      dio: dio,
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

  test('returns null when the candidate is unreachable with every variant',
      () async {
    final dio = Dio()..httpClientAdapter = _UrlAdapter();
    final resolver = StreamResolver(
      maccms: _FakeMacCmsResolver(
          const MediaCandidate('https://cdn.test/dead.m3u8')),
      dio: dio,
    );
    expect(await resolver.resolve('https://page/play'), isNull);
  });

  test('retries and returns a later reachable candidate', () async {
    final dio = Dio()..httpClientAdapter = _UrlAdapter();
    final resolver = StreamResolver(
      maccms: _FlakyMacCmsResolver(const [
        MediaCandidate('https://cdn.test/dead.m3u8'),
        MediaCandidate('https://cdn.test/ok.m3u8'),
      ]),
      dio: dio,
    );
    final result = await resolver.resolve('https://page/play');
    expect(result?.url, 'https://cdn.test/ok.m3u8');
  });
}
