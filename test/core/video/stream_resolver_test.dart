import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/video/browser_pool.dart';
import 'package:libiko/core/video/cancellation.dart';
import 'package:libiko/core/video/headless_browser.dart';
import 'package:libiko/core/video/maccms.dart';
import 'package:libiko/core/video/resolved_stream_cache.dart';
import 'package:libiko/core/video/stream_resolver.dart';

class _FakeMacCmsResolver extends MacCmsResolver {
  _FakeMacCmsResolver(this.candidate);
  final MediaCandidate? candidate;

  @override
  Future<MediaCandidate?> resolve(
    String playPageUrl, {
    String? userAgent,
    String? referer,
    CancelToken? cancelToken,
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
    CancelToken? cancelToken,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    await Future<void>.delayed(delay);
    return candidate;
  }
}

class _FakeBrowser implements HeadlessBrowser {
  _FakeBrowser(
      {this.candidates = const [],
      this.loadError,
      this.hang = false,
      this.startGate,
      this.startError});
  final List<MediaCandidate> candidates;
  final Object? loadError;
  final bool hang;
  final Completer<void>? startGate;
  final Object? startError;
  String? script;
  bool disposed = false;
  final _media = StreamController<MediaCandidate>.broadcast();
  final _gate = Completer<void>();
  int loadCount = 0;
  int _loadId = 0;

  @override
  int get loadId => _loadId;

  @override
  Stream<MediaCandidate> get mediaUrls => _media.stream;

  @override
  Future<void> start({String? userAgent, String? extraScript}) async {
    script = extraScript;
    if (startError != null) throw startError!;
    await startGate?.future;
  }

  @override
  Future<void> load(String url,
      {Duration timeout = const Duration(seconds: 15)}) async {
    loadCount++;
    _loadId++;
    if (loadError != null) throw loadError!;
    if (hang) {
      await _gate.future;
      return;
    }
    for (final candidate in candidates) {
      if (!_media.isClosed) {
        _media.add(MediaCandidate(candidate.url,
            headers: candidate.headers, loadId: _loadId));
      }
    }
  }

  @override
  Future<dynamic> eval(String script) async => null;

  @override
  Future<void> dispose() async {
    disposed = true;
    if (!_media.isClosed) await _media.close();
  }
}

StreamResolver _headlessResolver(_FakeBrowser browser) => StreamResolver(
      maccms: _FakeMacCmsResolver(null),
      dio: Dio()..httpClientAdapter = _HeaderAdapter(okWithoutReferer: true),
      browserFactory: () => browser,
      cache: ResolvedStreamCache(),
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
      ok ? '#EXTM3U' : 'no',
      ok ? 200 : 400,
      headers: {
        Headers.contentTypeHeader: [Headers.textPlainContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Delays (and rejects) probes for [slowUrl] while accepting every other probe
/// immediately, so a slow unreachable sibling can be used to prove fast-start.
class _SlowAdapter implements HttpClientAdapter {
  _SlowAdapter({required this.slowUrl, required this.slowDelay});
  final String slowUrl;
  final Duration slowDelay;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.toString() == slowUrl) {
      await Future<void>.delayed(slowDelay);
      return ResponseBody.fromString('no', 400, headers: {
        Headers.contentTypeHeader: [Headers.textPlainContentType],
      });
    }
    return ResponseBody.fromString('#EXTM3U', 200, headers: {
      Headers.contentTypeHeader: [Headers.textPlainContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

class _CallbackAdapter implements HttpClientAdapter {
  _CallbackAdapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions, Future<void>?) respond;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) =>
      respond(options, cancelFuture);

  @override
  void close({bool force = false}) {}
}

void main() {
  test('returns a direct candidate without touching the browser', () async {
    final browser = _FakeBrowser(
        candidates: const [MediaCandidate('https://cdn/x/index.m3u8')]);
    final resolver = StreamResolver(
      maccms: _FakeMacCmsResolver(null),
      dio: Dio()..httpClientAdapter = _HeaderAdapter(okWithoutReferer: true),
      browserFactory: () => browser,
      cache: ResolvedStreamCache(),
    );
    final result = await resolver.resolve('https://cdn/x/index.m3u8');
    expect(result.ok, isTrue);
    expect(result.candidate?.url, 'https://cdn/x/index.m3u8');
    expect(browser.loadCount, 0);
  });

  test('extracts a media URL embedded in a player query', () async {
    final browser = _FakeBrowser();
    final resolver = StreamResolver(
      maccms: _FakeMacCmsResolver(null),
      dio: Dio()..httpClientAdapter = _HeaderAdapter(okWithoutReferer: true),
      browserFactory: () => browser,
      cache: ResolvedStreamCache(),
    );
    final result = await resolver
        .resolve('https://proxy/a/?url=https://cdn.test/x/index.m3u8');
    expect(result.candidate?.url, 'https://cdn.test/x/index.m3u8');
    expect(browser.loadCount, 0);
  });

  test('serves a second resolve from the cache', () async {
    final browser = _FakeBrowser(
        candidates: const [MediaCandidate('https://cdn/x/index.m3u8')]);
    final resolver = StreamResolver(
      maccms: _FakeMacCmsResolver(null),
      dio: Dio()..httpClientAdapter = _HeaderAdapter(okWithoutReferer: true),
      browserFactory: () => browser,
      cache: ResolvedStreamCache(),
      grace: const Duration(milliseconds: 50),
      overallTimeout: const Duration(milliseconds: 200),
    );
    await resolver.resolve('https://page/play');
    await resolver.resolve('https://page/play');
    expect(browser.loadCount, 1);
  });

  test('keeps reachable candidates before unreachable ones', () async {
    final resolver = StreamResolver(
      maccms: _FakeMacCmsResolver(null),
      dio: Dio()
        ..httpClientAdapter = _SlowAdapter(
            slowUrl: 'https://cdn/bad.m3u8', slowDelay: Duration.zero),
      browserFactory: () => _FakeBrowser(candidates: const [
        MediaCandidate('https://cdn/bad.m3u8',
            headers: {'Referer': 'https://site/'}),
        MediaCandidate('https://cdn/good.m3u8'),
      ]),
      cache: ResolvedStreamCache(),
      grace: const Duration(milliseconds: 50),
      overallTimeout: const Duration(milliseconds: 300),
    );
    final result = await resolver.resolve('https://page/play');
    expect(result.ok, isTrue);
    expect(result.candidates.first.url, 'https://cdn/good.m3u8');
    expect(result.candidates.length, 2);
  });

  test('returns the MacCMS candidate while the headless browser runs',
      () async {
    final dio = Dio()
      ..httpClientAdapter = _HeaderAdapter(okWithoutReferer: true);
    final resolver = StreamResolver(
      maccms: _FakeMacCmsResolver(
          const MediaCandidate('https://cdn.test/x/index.m3u8')),
      dio: dio,
      browserFactory: () => _FakeBrowser(),
      cache: ResolvedStreamCache(),
    );
    final result = await resolver.resolve('https://page/play');
    expect(result.ok, isTrue);
    expect(result.candidate?.url, 'https://cdn.test/x/index.m3u8');
  });

  test('overlaps the MacCMS probe with the headless browser', () async {
    final browser = _FakeBrowser(candidates: const [
      MediaCandidate('https://cdn.test/browser/index.m3u8')
    ]);
    final resolver = StreamResolver(
      maccms: _DelayedMacCmsResolver(
          const MediaCandidate('https://cdn.test/maccms/index.m3u8'),
          const Duration(milliseconds: 300)),
      dio: Dio()..httpClientAdapter = _HeaderAdapter(okWithoutReferer: true),
      browserFactory: () => browser,
      cache: ResolvedStreamCache(),
      grace: const Duration(milliseconds: 50),
      overallTimeout: const Duration(seconds: 2),
      collectWindow: const Duration(milliseconds: 30),
    );
    final sw = Stopwatch()..start();
    final result = await resolver.resolve('https://page/play');
    expect(result.ok, isTrue);
    expect(result.candidate?.url, 'https://cdn.test/browser/index.m3u8');
    expect(sw.elapsedMilliseconds, lessThan(250));
  });

  test('keeps a MacCMS candidate that arrives within the collect window',
      () async {
    final resolver = StreamResolver(
      maccms: _DelayedMacCmsResolver(
          const MediaCandidate('https://cdn/maccms/index.m3u8'),
          const Duration(milliseconds: 50)),
      dio: Dio()..httpClientAdapter = _HeaderAdapter(okWithoutReferer: true),
      browserFactory: () => _FakeBrowser(
          candidates: const [MediaCandidate('https://cdn/browser/index.m3u8')]),
      cache: ResolvedStreamCache(),
      grace: const Duration(milliseconds: 30),
      overallTimeout: const Duration(seconds: 2),
      collectWindow: const Duration(milliseconds: 300),
    );
    final result = await resolver.resolve('https://page/play');
    expect(result.ok, isTrue);
    final urls = result.candidates.map((c) => c.url).toSet();
    expect(urls, contains('https://cdn/browser/index.m3u8'));
    expect(urls, contains('https://cdn/maccms/index.m3u8'));
  });

  test('drops the Referer when the candidate only works without it', () async {
    final adapter = _HeaderAdapter(okWithoutReferer: true);
    final dio = Dio()..httpClientAdapter = adapter;
    final resolver = StreamResolver(
      maccms: _FakeMacCmsResolver(const MediaCandidate(
        'https://cdn.test/x.m3u8',
        headers: {'User-Agent': 'UA', 'Referer': 'https://site/'},
      )),
      dio: dio,
      browserFactory: () => _FakeBrowser(),
      cache: ResolvedStreamCache(),
    );

    final result = await resolver.resolve('https://page/play');

    expect(result.ok, isTrue);
    expect(result.candidate?.url, 'https://cdn.test/x.m3u8');
    expect(result.candidate?.headers['Referer'], isNull);
    expect(result.candidate?.headers['User-Agent'], 'UA');
  });

  test('resolves through the headless browser', () async {
    final resolver = _headlessResolver(_FakeBrowser(
        candidates: const [MediaCandidate('https://cdn.test/x/index.m3u8')]));
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
      cache: ResolvedStreamCache(),
      grace: const Duration(milliseconds: 50),
      overallTimeout: const Duration(milliseconds: 100),
      overallBudget: const Duration(milliseconds: 200),
    );
    final result = await resolver.resolve('https://page/play');
    expect(result.failure, ResolveFailure.timeout);
    expect(browser.loadCount, 1);
  });

  test('retries a transient load failure', () async {
    final browser =
        _FakeBrowser(loadError: const HeadlessLoadException('boom'));
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

  test('does not cache a transient failure', () async {
    final browser =
        _FakeBrowser(loadError: const HeadlessLoadException('boom'));
    final resolver = _headlessResolver(browser);
    await resolver.resolve('https://page/play');
    await resolver.resolve('https://page/play');
    expect(browser.loadCount, 6); // 3 attempts per resolve, not short-circuited
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

  test('does not negative-cache a cancelled resolve', () async {
    final cache = ResolvedStreamCache();
    final hanging = _FakeBrowser(hang: true);
    final resolver1 = StreamResolver(
      maccms: _FakeMacCmsResolver(null),
      dio: Dio()..httpClientAdapter = _HeaderAdapter(okWithoutReferer: true),
      browserFactory: () => hanging,
      cache: cache,
      grace: const Duration(milliseconds: 50),
      overallTimeout: const Duration(milliseconds: 200),
    );
    final cancel = CancellationToken();
    final pending = resolver1.resolve('https://page/play', cancel: cancel);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    cancel.cancel();
    final cancelled = await pending;
    expect(cancelled.failure, ResolveFailure.unknown);

    final working = _FakeBrowser(
        candidates: const [MediaCandidate('https://cdn/x/index.m3u8')]);
    final resolver2 = StreamResolver(
      maccms: _FakeMacCmsResolver(null),
      dio: Dio()..httpClientAdapter = _HeaderAdapter(okWithoutReferer: true),
      browserFactory: () => working,
      cache: cache,
      grace: const Duration(milliseconds: 50),
      overallTimeout: const Duration(milliseconds: 200),
    );
    final result = await resolver2.resolve('https://page/play');
    expect(result.ok, isTrue);
    expect(working.loadCount, 1);
  });

  test('returns a reachable candidate without waiting for a slow sibling',
      () async {
    final resolver = StreamResolver(
      maccms: _FakeMacCmsResolver(null),
      dio: Dio()
        ..httpClientAdapter = _SlowAdapter(
          slowUrl: 'https://cdn/bad.m3u8',
          slowDelay: const Duration(milliseconds: 800),
        ),
      browserFactory: () => _FakeBrowser(candidates: const [
        MediaCandidate('https://cdn/bad.m3u8',
            headers: {'Referer': 'https://site/'}),
        MediaCandidate('https://cdn/good.m3u8'),
      ]),
      cache: ResolvedStreamCache(),
      grace: const Duration(milliseconds: 50),
      overallTimeout: const Duration(seconds: 2),
      collectWindow: const Duration(milliseconds: 30),
    );
    final sw = Stopwatch()..start();
    final result = await resolver.resolve('https://page/play');
    final elapsed = sw.elapsedMilliseconds;
    expect(result.ok, isTrue);
    expect(result.candidates.first.url, 'https://cdn/good.m3u8');
    expect(elapsed, lessThan(500));
  });

  test('does not cache a result whose candidates are all unreachable',
      () async {
    final browser = _FakeBrowser(candidates: const [
      MediaCandidate('https://cdn/bad.m3u8',
          headers: {'Referer': 'https://site/'}),
    ]);
    final resolver = StreamResolver(
      maccms: _FakeMacCmsResolver(null),
      dio: Dio()
        ..httpClientAdapter = _SlowAdapter(
            slowUrl: 'https://cdn/bad.m3u8', slowDelay: Duration.zero),
      browserFactory: () => browser,
      cache: ResolvedStreamCache(),
      grace: const Duration(milliseconds: 50),
      overallTimeout: const Duration(milliseconds: 300),
      collectWindow: const Duration(milliseconds: 30),
    );
    final first = await resolver.resolve('https://page/play');
    expect(first.ok, isTrue);
    await resolver.resolve('https://page/play');
    expect(browser.loadCount, 2);
  });
  test('direct candidates preserve authoritative episode headers', () async {
    final resolver = StreamResolver(cache: ResolvedStreamCache());
    final result = await resolver.resolve('https://cdn/video.m3u8',
        userAgent: 'episode-agent', referer: 'https://source/play');
    expect(result.candidate!.headersResolved, isTrue);
    expect(result.candidate!.headers, {
      'User-Agent': 'episode-agent',
      'Referer': 'https://source/play',
    });
  });

  test('MacCMS succeeds even if browser startup fails', () async {
    final resolver = StreamResolver(
      cache: ResolvedStreamCache(),
      browserFactory: () => _FakeBrowser(startError: StateError('no WebView')),
      maccms:
          _FakeMacCmsResolver(const MediaCandidate('https://cdn/video.m3u8')),
      dio: Dio()..httpClientAdapter = _HeaderAdapter(okWithoutReferer: true),
      collectWindow: const Duration(milliseconds: 5),
    );
    final result = await resolver.resolve('https://source/play');
    expect(result.verified, isTrue);
    expect(result.candidate!.url, 'https://cdn/video.m3u8');
  });

  test('MacCMS does not wait for hung startup and late browser is disposed',
      () async {
    final start = Completer<void>();
    final browser = _FakeBrowser(startGate: start);
    final resolver = StreamResolver(
      cache: ResolvedStreamCache(),
      browserFactory: () => browser,
      maccms:
          _FakeMacCmsResolver(const MediaCandidate('https://cdn/video.m3u8')),
      dio: Dio()..httpClientAdapter = _HeaderAdapter(okWithoutReferer: true),
      collectWindow: const Duration(milliseconds: 5),
    );
    final result = await resolver
        .resolve('https://source/play')
        .timeout(const Duration(milliseconds: 400));
    expect(result.verified, isTrue);
    start.complete();
    await Future<void>.delayed(Duration.zero);
    expect(browser.disposed, isTrue);
    expect(browser.loadCount, 0);
  });

  test('the deadline includes browser pool queueing', () async {
    final pool =
        HeadlessBrowserPool(factory: () => _FakeBrowser(), maxBrowsers: 1);
    final held = await pool.acquire();
    final resolver = StreamResolver(
      cache: ResolvedStreamCache(),
      browserPool: pool,
      maccms: _FakeMacCmsResolver(null),
      overallBudget: const Duration(milliseconds: 60),
      overallTimeout: const Duration(milliseconds: 60),
    );
    final result = await resolver
        .resolve('https://source/play')
        .timeout(const Duration(milliseconds: 400));
    expect(result.failure, ResolveFailure.timeout);
    await held.release();
    expect(pool.activeCount, 0);
    await pool.shutdown();
  });

  test('cancellation wakes a queued resolve and leaves no borrower', () async {
    final pool =
        HeadlessBrowserPool(factory: () => _FakeBrowser(), maxBrowsers: 1);
    final held = await pool.acquire();
    final cancel = CancellationToken();
    final resolver = StreamResolver(
      cache: ResolvedStreamCache(),
      browserPool: pool,
      maccms: _FakeMacCmsResolver(null),
    );
    final pending = resolver.resolve('https://source/play', cancel: cancel);
    await Future<void>.delayed(Duration.zero);
    cancel.cancel();
    final result = await pending.timeout(const Duration(milliseconds: 400));
    expect(result.failure, ResolveFailure.unknown);
    await held.release();
    expect(pool.activeCount, 0);
    await pool.shutdown();
  });

  test('legacy script reaches the production browser pool path', () async {
    final browser = _FakeBrowser();
    final pool = HeadlessBrowserPool(factory: () => browser);
    final resolver = StreamResolver(
      cache: ResolvedStreamCache(),
      browserPool: pool,
      maccms: _FakeMacCmsResolver(null),
      grace: Duration.zero,
    );
    await resolver.resolve('https://source/play', legacy: true);
    expect(browser.script, kLegacyIframeScript);
    await pool.shutdown();
  });

  test('later network headers enrich an earlier JS URL observation', () async {
    final adapter = _CallbackAdapter((options, _) async {
      final okay = options.headers['Referer'] == 'https://source/actual-frame';
      return ResponseBody.fromString(
          okay ? '#EXTM3U' : 'denied', okay ? 200 : 403);
    });
    final resolver = StreamResolver(
      cache: ResolvedStreamCache(),
      maccms: _FakeMacCmsResolver(null),
      browserFactory: () => _FakeBrowser(candidates: const [
        MediaCandidate('https://cdn/video.m3u8'),
        MediaCandidate('https://cdn/video.m3u8', headers: {
          'Referer': 'https://source/actual-frame',
        }),
      ]),
      dio: Dio()..httpClientAdapter = adapter,
      collectWindow: const Duration(milliseconds: 5),
    );
    final result = await resolver.resolve('https://source/play',
        referer: 'https://source/configured');
    expect(result.verified, isTrue);
    expect(result.candidates, hasLength(1));
    expect(result.candidate!.headers['Referer'], 'https://source/actual-frame');
    expect(result.candidate!.headersResolved, isTrue);
  });

  test('successful header variant wins while original probe hangs', () async {
    var cancelledRequests = 0;
    final adapter = _CallbackAdapter((options, cancelled) async {
      if (options.headers.containsKey('Referer')) {
        await cancelled;
        cancelledRequests++;
        throw StateError('request cancelled');
      }
      return ResponseBody.fromString('#EXTM3U', 200);
    });
    final resolver = StreamResolver(
      cache: ResolvedStreamCache(),
      maccms: _FakeMacCmsResolver(null),
      browserFactory: () => _FakeBrowser(candidates: const [
        MediaCandidate('https://cdn/video.m3u8'),
      ]),
      dio: Dio()..httpClientAdapter = adapter,
      collectWindow: const Duration(milliseconds: 5),
    );
    final result = await resolver
        .resolve('https://source/play', referer: 'https://source/bad-referer')
        .timeout(const Duration(milliseconds: 400));
    expect(result.verified, isTrue);
    expect(result.candidate!.headers.containsKey('Referer'), isFalse);
    expect(result.candidate!.headersResolved, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(cancelledRequests, greaterThan(0));
  });

  test('rejects HTTP 200 HTML instead of caching a verified stream', () async {
    final cache = ResolvedStreamCache();
    final resolver = StreamResolver(
      cache: cache,
      maccms: _FakeMacCmsResolver(null),
      browserFactory: () => _FakeBrowser(candidates: const [
        MediaCandidate('https://cdn/video.m3u8'),
      ]),
      dio: Dio()
        ..httpClientAdapter = _CallbackAdapter((_, __) async =>
            ResponseBody.fromString('<html>access denied</html>', 200,
                headers: {
                  Headers.contentTypeHeader: ['text/html']
                })),
      collectWindow: const Duration(milliseconds: 5),
    );
    final result = await resolver.resolve('https://source/play');
    expect(result.ok, isFalse);
    expect(result.verified, isFalse);
    expect(cache.get('https://source/play')!.verified, isFalse);
  });

  test('a server ignoring Range is cut off after a bounded prefix', () async {
    var streamCancelled = false;
    var requestCancelled = false;
    final adapter = _CallbackAdapter((options, cancelled) async {
      expect(options.headers['Range'], 'bytes=0-4095');
      unawaited(cancelled!.then((_) => requestCancelled = true));
      final body = StreamController<Uint8List>(onCancel: () {
        streamCancelled = true;
      });
      body.add(Uint8List.fromList(List<int>.filled(8192, 0x41)));
      return ResponseBody(body.stream, 200, headers: {
        Headers.contentTypeHeader: ['video/mp4']
      });
    });
    final resolver = StreamResolver(
      cache: ResolvedStreamCache(),
      maccms: _FakeMacCmsResolver(null),
      browserFactory: () => _FakeBrowser(candidates: const [
        MediaCandidate('https://cdn/video.mp4'),
      ]),
      dio: Dio()..httpClientAdapter = adapter,
      collectWindow: const Duration(milliseconds: 5),
    );
    final result = await resolver
        .resolve('https://source/play')
        .timeout(const Duration(milliseconds: 400));
    expect(result.verified, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(streamCancelled, isTrue);
    expect(requestCancelled, isTrue);
  });

  test('cancellation stops active verification requests', () async {
    final probeStarted = Completer<void>();
    var requestCancelled = false;
    final adapter = _CallbackAdapter((options, cancelled) async {
      if (!probeStarted.isCompleted) probeStarted.complete();
      await cancelled;
      requestCancelled = true;
      throw StateError('cancelled');
    });
    final resolver = StreamResolver(
      cache: ResolvedStreamCache(),
      maccms: _FakeMacCmsResolver(null),
      browserFactory: () => _FakeBrowser(candidates: const [
        MediaCandidate('https://cdn/video.m3u8'),
      ]),
      dio: Dio()..httpClientAdapter = adapter,
      collectWindow: Duration.zero,
    );
    final cancel = CancellationToken();
    final pending = resolver.resolve('https://source/play', cancel: cancel);
    await probeStarted.future;
    cancel.cancel();
    final result = await pending.timeout(const Duration(milliseconds: 400));
    expect(result.failure, ResolveFailure.unknown);
    await Future<void>.delayed(Duration.zero);
    expect(requestCancelled, isTrue);
  });
  test('MacCMS guessed headers cannot replace actual browser headers',
      () async {
    final resolver = StreamResolver(
      cache: ResolvedStreamCache(),
      maccms: _DelayedMacCmsResolver(
          const MediaCandidate('https://cdn/video.m3u8',
              headers: {'Referer': 'https://source/'}),
          const Duration(milliseconds: 10)),
      browserFactory: () => _FakeBrowser(candidates: const [
        MediaCandidate('https://cdn/video.m3u8',
            headers: {'Referer': 'https://source/player/frame'}),
      ]),
      dio: Dio()
        ..httpClientAdapter = _CallbackAdapter((options, _) async {
          final okay =
              options.headers['Referer'] == 'https://source/player/frame';
          return ResponseBody.fromString(
              okay ? '#EXTM3U' : 'no', okay ? 200 : 403);
        }),
      collectWindow: const Duration(milliseconds: 30),
    );
    final result = await resolver.resolve('https://source/play');
    expect(result.verified, isTrue);
    expect(result.candidate!.headers['Referer'], 'https://source/player/frame');
  });

  test('deadline covers hung browser creation without a MacCMS hit', () async {
    final start = Completer<void>();
    final browser = _FakeBrowser(startGate: start);
    final resolver = StreamResolver(
      cache: ResolvedStreamCache(),
      browserFactory: () => browser,
      maccms: _FakeMacCmsResolver(null),
      overallBudget: const Duration(milliseconds: 50),
    );
    final result = await resolver
        .resolve('https://source/play')
        .timeout(const Duration(milliseconds: 400));
    expect(result.failure, ResolveFailure.timeout);
    start.complete();
    await Future<void>.delayed(Duration.zero);
    expect(browser.disposed, isTrue);
  });

  test('cancellation stops the MacCMS HTTP request', () async {
    final pageRequested = Completer<void>();
    var pageCancelled = false;
    final pageHttp = Dio()
      ..httpClientAdapter = _CallbackAdapter((_, cancelled) async {
        pageRequested.complete();
        await cancelled;
        pageCancelled = true;
        throw StateError('cancelled');
      });
    final resolver = StreamResolver(
      cache: ResolvedStreamCache(),
      maccms: MacCmsResolver(dio: pageHttp),
      browserFactory: () => _FakeBrowser(hang: true),
    );
    final cancel = CancellationToken();
    final pending = resolver.resolve('https://source/play', cancel: cancel);
    await pageRequested.future;
    cancel.cancel();
    final result = await pending.timeout(const Duration(milliseconds: 400));
    expect(result.failure, ResolveFailure.unknown);
    await Future<void>.delayed(Duration.zero);
    expect(pageCancelled, isTrue);
  });
}
