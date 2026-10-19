import 'dart:async';
import 'dart:io';
import 'package:libiko/core/video/cancellation.dart';
import 'package:libiko/core/video/rule_source.dart';
import 'package:libiko/core/video/source_rule.dart';
import 'package:libiko/core/video/source_cache.dart';
import 'package:libiko/core/sources/managed_sources.dart';
import 'package:libiko/core/sources/source_preferences.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/video/browser_pool.dart';
import 'package:libiko/core/video/headless_browser.dart';
import 'package:libiko/core/video/webview_scraper.dart';

class _FakeBrowser implements HeadlessBrowser {
  _FakeBrowser(
      {this.evalResult, this.loadError, this.loadGate, this.evalError});
  final dynamic evalResult;
  final Object? loadError;
  final Object? evalError;
  final Completer<void>? loadGate;
  int loadCalls = 0;
  int evalCalls = 0;
  int _loadId = 0;
  final _media = StreamController<MediaCandidate>.broadcast();

  @override
  int get loadId => _loadId;

  @override
  Stream<MediaCandidate> get mediaUrls => _media.stream;

  @override
  Future<void> start({String? userAgent, String? extraScript}) async {}

  @override
  Future<void> load(String url,
      {Duration timeout = const Duration(seconds: 15)}) async {
    _loadId++;
    loadCalls++;
    await loadGate?.future;
    if (loadError != null) throw loadError!;
  }

  @override
  Future<dynamic> eval(String script) async {
    evalCalls++;
    if (evalError != null) throw evalError!;
    return evalResult;
  }

  @override
  Future<void> dispose() async {
    if (!_media.isClosed) await _media.close();
  }
}

WebviewScraper _scraper(_FakeBrowser browser) => WebviewScraper(
      pool: HeadlessBrowserPool(factory: () => browser, maxBrowsers: 1),
    );

void main() {
  test('returns rows as soon as the page yields them', () async {
    final scraper = _scraper(_FakeBrowser(evalResult: [
      {'name': 'x', 'href': '/1'}
    ]));
    final sw = Stopwatch()..start();
    final result = await scraper.fetchJson(url: 'https://x', script: 's');
    expect(result, [
      {'name': 'x', 'href': '/1'}
    ]);
    expect(sw.elapsedMilliseconds, lessThan(2000));
  });

  test('gives up shortly after loading when the page yields nothing', () async {
    final scraper = _scraper(_FakeBrowser(evalResult: null));
    final sw = Stopwatch()..start();
    final result = await scraper.fetchJson(
      url: 'https://x',
      script: 's',
      timeout: const Duration(seconds: 10),
    );
    expect(result, isEmpty);
    // The old behaviour waited the whole 10s timeout.
    expect(sw.elapsedMilliseconds, lessThan(6000));
  });

  test('gives up quickly when the page fails to load', () async {
    final scraper = _scraper(_FakeBrowser(
        evalResult: null, loadError: const HeadlessLoadException('nope')));
    final sw = Stopwatch()..start();
    await expectLater(
        scraper.fetchJson(
            url: 'https://x',
            script: 's',
            timeout: const Duration(seconds: 10)),
        throwsA(isA<HeadlessLoadException>()));
    expect(sw.elapsedMilliseconds, lessThan(3000));
  });

  test('overall timeout includes pool queueing and removes abandoned waiters',
      () async {
    final browser = _FakeBrowser(evalResult: []);
    final pool = HeadlessBrowserPool(factory: () => browser, maxBrowsers: 1);
    final holder = await pool.acquire();
    final scraper = WebviewScraper(pool: pool);
    await expectLater(
        scraper.fetchJson(
            url: 'https://test/',
            script: 's',
            timeout: const Duration(milliseconds: 30)),
        throwsA(isA<TimeoutException>()));
    await holder.release();
    await Future<void>.delayed(Duration.zero);
    expect(pool.activeCount, 0);
    expect(pool.idleCount, 1);
    expect(browser.loadCalls, 0);
    await pool.shutdown();
  });

  test(
      'caller cancellation completes promptly and does not report a request failure',
      () async {
    final browser = _FakeBrowser(evalResult: []);
    final pool = HeadlessBrowserPool(factory: () => browser, maxBrowsers: 1);
    final holder = await pool.acquire();
    final cancel = CancellationToken();
    final pending = WebviewScraper(pool: pool)
        .fetchJson(url: 'https://test/', script: 's', cancel: cancel);
    cancel.cancel();
    expect(await pending.timeout(const Duration(milliseconds: 100)), isEmpty);
    await holder.release();
    await Future<void>.delayed(Duration.zero);
    expect(pool.activeCount, 0);
    await pool.shutdown();
  });

  test('does not extract previous document rows while navigation is pending',
      () async {
    final gate = Completer<void>();
    final browser = _FakeBrowser(loadGate: gate, evalResult: [
      {'name': 'current', 'href': '/1'}
    ]);
    final pool = HeadlessBrowserPool(factory: () => browser, maxBrowsers: 1);
    final pending =
        WebviewScraper(pool: pool).fetchJson(url: 'https://test/', script: 's');
    await Future<void>.delayed(Duration.zero);
    expect(browser.evalCalls, 0);
    gate.complete();
    expect(await pending, isNotEmpty);
    await Future<void>.delayed(Duration.zero);
    await pool.shutdown();
  });

  test(
      'overall deadline returns while a native load is still pending and later recycles it',
      () async {
    final gate = Completer<void>();
    final browser = _FakeBrowser(loadGate: gate, evalResult: []);
    final pool = HeadlessBrowserPool(factory: () => browser, maxBrowsers: 1);
    final watch = Stopwatch()..start();
    await expectLater(
        WebviewScraper(pool: pool).fetchJson(
            url: 'https://test/',
            script: 's',
            timeout: const Duration(milliseconds: 30)),
        throwsA(isA<TimeoutException>()));
    expect(watch.elapsedMilliseconds, lessThan(1000));
    expect(browser.evalCalls, 0);
    gate.complete();
    await Future<void>.delayed(Duration.zero);
    expect(pool.activeCount, 0);
    await pool.shutdown();
  });

  test(
      'failed source navigation is neither cached nor reported as health success',
      () async {
    final browser =
        _FakeBrowser(loadError: const SocketException('network unavailable'));
    final pool = HeadlessBrowserPool(factory: () => browser, maxBrowsers: 1);
    final health =
        SourceHealthRepository(read: (_) => null, write: (_, __) async {});
    const rule = SourceRule(
        name: 'test',
        baseUrl: 'https://test/',
        searchUrl: 'https://test/?q=@keyword',
        searchList: '//a',
        searchName: '//a',
        searchResult: '//a',
        chapterRoads: '//ul',
        chapterResult: '//a');
    final cache = SourceCache();
    final source = ManagedVideoSource(
        RuleVideoSource(rule,
            scraper: WebviewScraper(pool: pool), cache: cache),
        health);
    await expectLater(
        source.search('keyword'), throwsA(isA<SocketException>()));
    expect(cache.search(rule.id, 'keyword'), isNull);
    expect(health.health(SourceKind.anime, rule.id).lastSuccess, isNull);
    expect(health.health(SourceKind.anime, rule.id).failure,
        SourceFailureKind.network);
    await expectLater(
        source.search('keyword'), throwsA(isA<SocketException>()));
    expect(browser.loadCalls, greaterThanOrEqualTo(2));
    await Future<void>.delayed(Duration.zero);
    await pool.shutdown();
    health.dispose();
  });

  test('real source success is recorded once and cache reads do not refresh it',
      () async {
    final browser = _FakeBrowser(evalResult: [
      {'name': 'result', 'href': '/1'}
    ]);
    final pool = HeadlessBrowserPool(factory: () => browser, maxBrowsers: 1);
    var now = DateTime.utc(2026, 10, 18);
    final health = SourceHealthRepository(
        read: (_) => null, write: (_, __) async {}, clock: () => now);
    const rule = SourceRule(
        name: 'test',
        baseUrl: 'https://test/',
        searchUrl: 'https://test/?q=@keyword',
        searchList: '//a',
        searchName: '//a',
        searchResult: '//a',
        chapterRoads: '//ul',
        chapterResult: '//a');
    final source = ManagedVideoSource(
        RuleVideoSource(rule,
            scraper: WebviewScraper(pool: pool), cache: SourceCache()),
        health);
    expect(await source.search('keyword'), hasLength(1));
    final requestedAt = health.health(SourceKind.anime, rule.id).lastSuccess;
    now = now.add(const Duration(minutes: 1));
    expect(await source.search('keyword'), hasLength(1));
    expect(browser.loadCalls, 1);
    expect(health.health(SourceKind.anime, rule.id).lastSuccess, requestedAt);
    await Future<void>.delayed(Duration.zero);
    await pool.shutdown();
    health.dispose();
  });

  test('script execution failure propagates instead of becoming empty search',
      () async {
    final scraper = _scraper(
        _FakeBrowser(evalError: const FormatException('invalid script')));
    await expectLater(scraper.fetchJson(url: 'https://test/', script: 'broken'),
        throwsFormatException);
  });
}
