import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/video/browser_pool.dart';
import 'package:libiko/core/video/headless_browser.dart';
import 'package:libiko/core/video/webview_scraper.dart';

class _FakeBrowser implements HeadlessBrowser {
  _FakeBrowser({this.evalResult, this.loadError});
  final dynamic evalResult;
  final Object? loadError;
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
    if (loadError != null) throw loadError!;
  }

  @override
  Future<dynamic> eval(String script) async => evalResult;

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

  test('gives up shortly after loading when the page yields nothing',
      () async {
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
    final scraper = _scraper(
        _FakeBrowser(evalResult: null, loadError: const HeadlessLoadException('nope')));
    final sw = Stopwatch()..start();
    final result = await scraper.fetchJson(
      url: 'https://x',
      script: 's',
      timeout: const Duration(seconds: 10),
    );
    expect(result, isEmpty);
    expect(sw.elapsedMilliseconds, lessThan(3000));
  });
}
