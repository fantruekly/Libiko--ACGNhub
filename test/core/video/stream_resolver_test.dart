import 'dart:async';
import 'dart:io';
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

class _FakeBrowser implements HeadlessBrowser {
  _FakeBrowser({this.candidate, this.loadError, this.hang = false});
  final MediaCandidate? candidate;
  final Object? loadError;
  final bool hang;
  final _media = StreamController<MediaCandidate>.broadcast();
  final _gate = Completer<void>();

  @override
  Stream<MediaCandidate> get mediaUrls => _media.stream;

  @override
  Future<void> start({String? userAgent, String? extraScript}) async {}

  @override
  Future<void> load(String url,
      {Duration timeout = const Duration(seconds: 15)}) async {
    if (loadError != null) throw loadError!;
    if (hang) {
      await _gate.future;
      return;
    }
    if (candidate != null && !_media.isClosed) _media.add(candidate!);
  }

  @override
  Future<dynamic> eval(String script) async => null;

  @override
  Future<void> dispose() async {
    if (!_media.isClosed) await _media.close();
  }
}

StreamResolver _headlessResolver(_FakeBrowser browser) => StreamResolver(
      maccms: _FakeMacCmsResolver(null),
      dio: Dio()..httpClientAdapter = _HeaderAdapter(okWithoutReferer: true),
      browserFactory: () => browser,
      grace: const Duration(milliseconds: 50),
      overallTimeout: const Duration(milliseconds: 200),
    );

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
    expect(result.ok, isTrue);
    expect(result.candidate?.url, 'https://cdn.test/x/index.m3u8');
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

    expect(result.ok, isTrue);
    expect(result.candidate?.url, 'https://cdn.test/x.m3u8');
    expect(result.candidate?.headers['Referer'], isNull);
    expect(result.candidate?.headers['User-Agent'], 'UA');
  });

  test('resolves through the headless browser', () async {
    final resolver = _headlessResolver(_FakeBrowser(
        candidate: const MediaCandidate('https://cdn.test/x/index.m3u8')));
    final result = await resolver.resolve('https://page/play');
    expect(result.ok, isTrue);
    expect(result.candidate?.url, 'https://cdn.test/x/index.m3u8');
  });

  test('reports notFound when nothing is captured', () async {
    final resolver = _headlessResolver(_FakeBrowser());
    final result = await resolver.resolve('https://page/play');
    expect(result.failure, ResolveFailure.notFound);
  });

  test('reports loadFailed when the page fails to load', () async {
    final resolver = _headlessResolver(
        _FakeBrowser(loadError: const HeadlessLoadException('boom')));
    final result = await resolver.resolve('https://page/play');
    expect(result.failure, ResolveFailure.loadFailed);
  });

  test('reports network for a network error', () async {
    final resolver =
        _headlessResolver(_FakeBrowser(loadError: const SocketException('x')));
    final result = await resolver.resolve('https://page/play');
    expect(result.failure, ResolveFailure.network);
  });

  test('reports timeout when the overall resolve times out', () async {
    final resolver = _headlessResolver(_FakeBrowser(hang: true));
    final result = await resolver.resolve('https://page/play');
    expect(result.failure, ResolveFailure.timeout);
  });
}
