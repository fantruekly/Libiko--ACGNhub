import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/video/browser_pool.dart';
import 'package:libiko/core/video/headless_browser.dart';

class _FakeBrowser implements HeadlessBrowser {
  _FakeBrowser(this.onDispose);
  final void Function(_FakeBrowser) onDispose;
  int _loadId = 0;
  int startCount = 0;
  final _media = StreamController<MediaCandidate>.broadcast();

  @override
  int get loadId => _loadId;

  @override
  Stream<MediaCandidate> get mediaUrls => _media.stream;

  @override
  Future<void> start({String? userAgent, String? extraScript}) async {
    startCount++;
  }

  @override
  Future<void> load(String url,
      {Duration timeout = const Duration(seconds: 15)}) async {
    _loadId++;
  }

  @override
  Future<dynamic> eval(String script) async => null;

  @override
  Future<void> dispose() async {
    onDispose(this);
    if (!_media.isClosed) await _media.close();
  }

  void emit(MediaCandidate candidate) => _media.add(candidate);
}

void main() {
  test('reuses an idle browser for the same user agent', () async {
    final created = <_FakeBrowser>[];
    final pool = HeadlessBrowserPool(
      factory: () {
        final browser = _FakeBrowser((_) {});
        created.add(browser);
        return browser;
      },
      maxBrowsers: 1,
    );
    final first = await pool.acquire();
    await first.release();
    final second = await pool.acquire();
    expect(created.length, 1);
    expect(created.first.startCount, 1);
    await second.release();
  });

  test('creates separate browsers for different user agents', () async {
    final created = <_FakeBrowser>[];
    final pool = HeadlessBrowserPool(
      factory: () {
        final browser = _FakeBrowser((_) {});
        created.add(browser);
        return browser;
      },
      maxBrowsers: 2,
    );
    final a = await pool.acquire(userAgent: 'UA1');
    final b = await pool.acquire(userAgent: 'UA2');
    expect(created.length, 2);
    await a.release();
    await b.release();
  });

  test('waits for a release when the pool is full', () async {
    final pool = HeadlessBrowserPool(
      factory: () => _FakeBrowser((_) {}),
      maxBrowsers: 1,
    );
    final first = await pool.acquire();
    var secondDone = false;
    final second = pool.acquire().then((b) {
      secondDone = true;
      return b;
    });
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(secondDone, isFalse);
    await first.release();
    final secondBrowser = await second;
    expect(secondDone, isTrue);
    await secondBrowser.release();
  });

  test('serves foreground waiters before background waiters', () async {
    final pool = HeadlessBrowserPool(
      factory: () => _FakeBrowser((_) {}),
      maxBrowsers: 1,
    );
    final holder = await pool.acquire();
    final order = <String>[];
    final background = pool
        .acquire(priority: BrowserPriority.background)
        .then((b) { order.add('bg'); return b; });
    final foreground = pool
        .acquire(priority: BrowserPriority.foreground)
        .then((b) { order.add('fg'); return b; });
    await holder.release();
    final fgBrowser = await foreground;
    await fgBrowser.release();
    final bgBrowser = await background;
    await bgBrowser.release();
    expect(order, ['fg', 'bg']);
  });

  test('only exposes candidates from the current load', () async {
    late _FakeBrowser browser;
    final pool = HeadlessBrowserPool(
      factory: () => browser = _FakeBrowser((_) {}),
      maxBrowsers: 1,
    );
    final first = await pool.acquire();
    await first.load('https://a'); // loadId = 1
    await first.release();

    final second = await pool.acquire();
    await second.load('https://b'); // loadId = 2
    final received = <String>[];
    final sub = second.mediaUrls.listen((c) => received.add(c.url));
    browser.emit(const MediaCandidate('https://old.m3u8', loadId: 1));
    browser.emit(const MediaCandidate('https://new.m3u8', loadId: 2));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await sub.cancel();
    expect(received, ['https://new.m3u8']);
    await second.release();
  });

  test('disposes an idle browser after the idle timeout', () async {
    var now = DateTime(2026);
    final disposed = <_FakeBrowser>[];
    final pool = HeadlessBrowserPool(
      factory: () => _FakeBrowser(disposed.add),
      maxBrowsers: 1,
      idleTimeout: const Duration(seconds: 30),
      clock: () => now,
    );
    final first = await pool.acquire();
    await first.release();
    now = now.add(const Duration(seconds: 31));
    final second = await pool.acquire();
    expect(disposed.length, 1);
    await second.release();
  });

  test('recreates a browser after maxUsesPerBrowser', () async {
    final created = <_FakeBrowser>[];
    final pool = HeadlessBrowserPool(
      factory: () {
        final browser = _FakeBrowser((_) {});
        created.add(browser);
        return browser;
      },
      maxBrowsers: 1,
      maxUsesPerBrowser: 2,
    );
    final a = await pool.acquire();
    await a.release();
    final b = await pool.acquire();
    await b.release();
    final c = await pool.acquire();
    expect(created.length, 2);
    await c.release();
  });
}
