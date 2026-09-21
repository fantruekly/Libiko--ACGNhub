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

class _DelayedMacCmsResolver extends MacCmsResolver {
  _DelayedMacCmsResolver(this.candidate, this.delay);
  final MediaCandidate? candidate;
  final Duration delay;

  @override
  Future<MediaCandidate?> resolve(
    String playPageUrl, {
    String? userAgent,
    String? referer,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    await Future<void>.delayed(delay);
    return candidate;
  }
}

class _FakeBrowser implements HeadlessBrowser {
  _FakeBrowser({this.candidate, this.loadError, this.hang = false});
  final MediaCandidate? candidate;
  final Object? loadError;
  final bool hang;
  final _media = StreamController<MediaCandidate>.broadcast();
  final _gate = Completer<void>();
  int loadCount = 0;

  @override
  Stream<MediaCandidate> get mediaUrls => _media.stream;

  @override
  Future<void> start({String? userAgent, String? extraScript}) async {}

  @override
  Future<void> load(String url,
      {Duration timeout = const Duration(seconds: 15)}) async {
    loadCount++;
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
  test('returns the MacCMS candidate while the headless browser runs',
      () async {
    final dio = Dio()
      ..httpClientAdapter = _HeaderAdapter(okWithoutReferer: true);
    final resolver = StreamResolver(
      maccms: _FakeMacCmsResolver(
          const MediaCandidate('https://cdn.test/x/index.m3u8')),
      dio: dio,
      browserFactory: () => _FakeBrowser(),
    );
    final result = await resolver.resolve('https://page/play');
    expect(result.ok, isTrue);
    expect(result.candidate?.url, 'https://cdn.test/x/index.m3u8');
  });

  test('overlaps the MacCMS probe with the headless browser', () async {
    final browser = _FakeBrowser(
        candidate: const MediaCandidate('https://cdn.test/browser/index.m3u8'));
    final resolver = StreamResolver(
      maccms: _DelayedMacCmsResolver(
          const MediaCandidate('https://cdn.test/maccms/index.m3u8'),
          const Duration(milliseconds: 300)),
      dio: Dio()..httpClientAdapter = _HeaderAdapter(okWithoutReferer: true),
      browserFactory: () => browser,
      grace: const Duration(milliseconds: 50),
      overallTimeout: const Duration(seconds: 2),
    );
    final sw = Stopwatch()..start();
    final result = await resolver.resolve('https://page/play');
    expect(result.ok, isTrue);
    expect(result.candidate?.url, 'https://cdn.test/browser/index.m3u8');
    expect(sw.elapsedMilliseconds, lessThan(250));
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
      browserFactory: () => _FakeBrowser(),
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

  test('does not retry a deterministic notFound', () async {
    final browser = _FakeBrowser();
    final resolver = _headlessResolver(browser);
    final result = await resolver.resolve('https://page/play');
    expect(result.failure, ResolveFailure.notFound);
    expect(browser.loadCount, 1);
  });

  test('stops retrying once the overall budget is exhausted', () async {
    final browser = _FakeBrowser(hang: true);
    final resolver = StreamResolver(
      maccms: _FakeMacCmsResolver(null),
      dio: Dio()..httpClientAdapter = _HeaderAdapter(okWithoutReferer: true),
      browserFactory: () => browser,
      grace: const Duration(milliseconds: 50),
      overallTimeout: const Duration(milliseconds: 100),
      overallBudget: const Duration(milliseconds: 200),
    );
    final result = await resolver.resolve('https://page/play');
    expect(result.failure, ResolveFailure.timeout);
    expect(browser.loadCount, 1);
  });

  test('retries a transient load failure', () async {
    final browser = _FakeBrowser(loadError: const HeadlessLoadException('boom'));
    final resolver = _headlessResolver(browser);
    final result = await resolver.resolve('https://page/play');
    expect(result.failure, ResolveFailure.loadFailed);
    expect(browser.loadCount, 3);
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
