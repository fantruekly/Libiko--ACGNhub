import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/video/browser_pool.dart';
import 'package:libiko/core/video/cancellation.dart';
import 'package:libiko/core/video/headless_browser.dart';

class _FakeBrowser implements HeadlessBrowser {
  _FakeBrowser(this.onDispose, {this.startError, this.startGate});
  final void Function(_FakeBrowser) onDispose;
  final Object? startError;
  final Completer<void>? startGate;
  String? script;
  Completer<void>? loadGate;
  int _loadId = 0;
  int startCount = 0;
  final List<String> loads = [];
  final _media = StreamController<MediaCandidate>.broadcast();

  @override
  int get loadId => _loadId;

  @override
  Stream<MediaCandidate> get mediaUrls => _media.stream;

  @override
  Future<void> start({String? userAgent, String? extraScript}) async {
    startCount++;
    script = extraScript;
    await startGate?.future;
    if (startError != null) throw startError!;
  }

  @override
  Future<void> load(String url,
      {Duration timeout = const Duration(seconds: 15)}) async {
    _loadId++;
    loads.add(url);
    await loadGate?.future;
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
  test('does not reuse a browser with a different document script', () async {
    final created = <_FakeBrowser>[];
    final pool = HeadlessBrowserPool(
        factory: () {
          final browser = _FakeBrowser((_) {});
          created.add(browser);
          return browser;
        },
        maxBrowsers: 1);
    final plain = await pool.acquire(userAgent: 'UA');
    await plain.release();
    final legacy =
        await pool.acquire(userAgent: 'UA', extraScript: kLegacyIframeScript);
    expect(legacy.userAgent, 'UA');
    expect(created, hasLength(2));
    expect(created.last.script, kLegacyIframeScript);
    await legacy.release();
    final again =
        await pool.acquire(userAgent: 'UA', extraScript: kLegacyIframeScript);
    expect(created, hasLength(2));
    await again.release();
    await pool.shutdown();
  });

  test('cancelled queued waiter cannot consume the next released browser',
      () async {
    final pool = HeadlessBrowserPool(
        factory: () => _FakeBrowser((_) {}), maxBrowsers: 1);
    final holder = await pool.acquire();
    final cancel = CancellationToken();
    final cancelled = pool.acquire(cancel: cancel);
    final rejected = expectLater(cancelled, throwsA(isA<StateError>()));
    final next = pool.acquire();
    cancel.cancel();
    await rejected;
    await holder.release();
    final browser = await next.timeout(const Duration(seconds: 1));
    expect(pool.activeCount, 1);
    await browser.release();
    await pool.shutdown();
  });

  test('cancelled creation disposes late browser before serving another waiter',
      () async {
    final gate = Completer<void>();
    final disposed = <_FakeBrowser>[];
    final created = <_FakeBrowser>[];
    final pool = HeadlessBrowserPool(
        factory: () {
          final browser = _FakeBrowser(disposed.add,
              startGate: created.isEmpty ? gate : null);
          created.add(browser);
          return browser;
        },
        maxBrowsers: 1);
    final cancel = CancellationToken();
    final first = pool.acquire(cancel: cancel);
    final rejected = expectLater(first, throwsA(isA<StateError>()));
    cancel.cancel();
    await rejected;
    final next = pool.acquire();
    expect(created, hasLength(1));
    gate.complete();
    final browser = await next.timeout(const Duration(seconds: 1));
    expect(disposed, contains(created.first));
    expect(created, hasLength(2));
    await browser.release();
    await pool.shutdown();
  });

  test('shutdown rejects in-flight acquisition and disposes late creation',
      () async {
    final gate = Completer<void>();
    final disposed = <_FakeBrowser>[];
    final pool = HeadlessBrowserPool(
        factory: () => _FakeBrowser(disposed.add, startGate: gate));
    final pending = pool.acquire();
    final rejected = expectLater(pending, throwsA(isA<StateError>()));
    await pool.shutdown();
    await rejected;
    gate.complete();
    await Future<void>.delayed(Duration.zero);
    expect(disposed, hasLength(1));
    expect(pool.activeCount, 0);
    expect(pool.idleCount, 0);
  });

  test('released handle stops observing events after browser reuse', () async {
    late _FakeBrowser fake;
    final pool =
        HeadlessBrowserPool(factory: () => fake = _FakeBrowser((_) {}));
    final first = await pool.acquire();
    await first.load('https://first');
    final seen = <MediaCandidate>[];
    final subscription = first.mediaUrls.listen(seen.add);
    await first.release();
    fake.emit(MediaCandidate('https://stale.m3u8', loadId: fake.loadId));
    await Future<void>.delayed(Duration.zero);
    expect(seen, isEmpty);
    await expectLater(
        first.load('https://illegal'), throwsA(isA<StateError>()));
    await subscription.cancel();
    await pool.shutdown();
  });

  test('does not reuse a browser before a released handle finishes loading',
      () async {
    late _FakeBrowser fake;
    final pool = HeadlessBrowserPool(
        factory: () => fake = _FakeBrowser((_) {}), maxBrowsers: 1);
    final first = await pool.acquire();
    final gate = Completer<void>();
    fake.loadGate = gate;
    final loading = first.load('https://first');
    final releasing = first.release();
    var borrowed = false;
    final next = pool.acquire().then((browser) {
      borrowed = true;
      return browser;
    });
    await Future<void>.delayed(Duration.zero);
    expect(borrowed, isFalse);
    fake.loadGate = null;
    gate.complete();
    await loading;
    await releasing;
    final second = await next;
    await second.load('https://second');
    expect(fake.loads, ['https://first', 'about:blank', 'https://second']);
    await second.release();
    await pool.shutdown();
  });

  test('defaults to a larger pool for concurrent source searches', () {
    expect(HeadlessBrowserPool().maxBrowsers, 4);
  });

  test('flushes the previous page with about:blank before reuse', () async {
    late _FakeBrowser browser;
    final pool = HeadlessBrowserPool(
      factory: () => browser = _FakeBrowser((_) {}),
      maxBrowsers: 1,
    );
    final first = await pool.acquire();
    await first.load('https://a');
    await first.release();

    final second = await pool.acquire();
    await second.load('https://b');

    expect(browser.loads, ['https://a', 'about:blank', 'https://b']);
    await second.release();
  });

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
    final background =
        pool.acquire(priority: BrowserPriority.background).then((b) {
      order.add('bg');
      return b;
    });
    final foreground =
        pool.acquire(priority: BrowserPriority.foreground).then((b) {
      order.add('fg');
      return b;
    });
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
    await second.load('https://b');
    final received = <String>[];
    final sub = second.mediaUrls.listen((c) => received.add(c.url));
    browser.emit(const MediaCandidate('https://old.m3u8', loadId: 1));
    browser.emit(MediaCandidate('https://new.m3u8', loadId: browser.loadId));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await sub.cancel();
    expect(received, ['https://new.m3u8']);
    await second.release();
  });

  test('filters a candidate that straddles acquire and the first load',
      () async {
    late _FakeBrowser browser;
    final pool = HeadlessBrowserPool(
      factory: () => browser = _FakeBrowser((_) {}),
      maxBrowsers: 1,
    );
    final borrowed = await pool.acquire();
    final received = <String>[];
    final sub = borrowed.mediaUrls.listen((c) => received.add(c.url));
    // Before load(), the handle's loadId sentinel (-1) matches nothing.
    browser.emit(const MediaCandidate('https://stale.m3u8', loadId: 0));
    await borrowed.load('https://page');
    browser.emit(MediaCandidate('https://fresh.m3u8', loadId: browser.loadId));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await sub.cancel();
    expect(received, ['https://fresh.m3u8']);
    await borrowed.release();
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

  test('never exceeds maxBrowsers when waiters queue across a disposal',
      () async {
    var alive = 0;
    var peak = 0;
    final pool = HeadlessBrowserPool(
      factory: () {
        alive++;
        if (alive > peak) peak = alive;
        return _FakeBrowser((_) => alive--);
      },
      maxBrowsers: 2,
      maxUsesPerBrowser: 1,
    );

    final a = await pool.acquire(userAgent: 'UA1');
    final b = await pool.acquire(userAgent: 'UA2');
    expect(alive, 2);

    final waiting1 = pool.acquire(userAgent: 'UA1');
    final waiting2 = pool.acquire(userAgent: 'UA2');

    await a.release();
    await b.release();

    final r1 = await waiting1;
    final r2 = await waiting2;
    expect(peak, lessThanOrEqualTo(2));
    await r1.release();
    await r2.release();
  });

  test('fails queued waiters on shutdown instead of hanging', () async {
    final pool = HeadlessBrowserPool(
      factory: () => _FakeBrowser((_) {}),
      maxBrowsers: 1,
    );
    final holder = await pool.acquire();
    final waiting = pool.acquire();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final expectation = expectLater(
      waiting.timeout(const Duration(seconds: 1)),
      throwsA(isA<StateError>()),
    );
    await pool.shutdown();
    await expectation;
    expect(holder.userAgent, isNotEmpty);
  });

  test('disposes a browser whose start fails', () async {
    final disposed = <_FakeBrowser>[];
    final pool = HeadlessBrowserPool(
      factory: () =>
          _FakeBrowser(disposed.add, startError: StateError('start failed')),
      maxBrowsers: 1,
    );

    await expectLater(pool.acquire(), throwsA(isA<StateError>()));
    expect(disposed, hasLength(1));
  });

  test('re-pumps the queue when a create fails instead of hanging waiters',
      () async {
    final pool = HeadlessBrowserPool(
      factory: () =>
          _FakeBrowser((_) {}, startError: StateError('start failed')),
      maxBrowsers: 1,
    );

    final first = pool.acquire();
    final second = pool.acquire();

    final firstExpectation = expectLater(first, throwsA(isA<StateError>()));
    final secondExpectation = expectLater(second, throwsA(isA<StateError>()));
    await firstExpectation;
    await secondExpectation;
  }, timeout: const Timeout(Duration(seconds: 5)));

  test('reserves one browser for foreground work', () async {
    final created = <_FakeBrowser>[];
    final pool = HeadlessBrowserPool(
      factory: () {
        final browser = _FakeBrowser((_) {});
        created.add(browser);
        return browser;
      },
      maxBrowsers: 2,
    );

    final bg1 = await pool.acquire(priority: BrowserPriority.background);
    expect(created.length, 1);

    var bg2Done = false;
    final bg2 = pool.acquire(priority: BrowserPriority.background).then((b) {
      bg2Done = true;
      return b;
    });
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(bg2Done, isFalse);
    expect(created.length, 1);

    final fg = await pool.acquire();
    expect(created.length, 2);

    await fg.release();
    await bg1.release();
    final bg2Browser = await bg2;
    await bg2Browser.release();
  });

  test('does not resurrect a browser released after shutdown', () async {
    final pool = HeadlessBrowserPool(
      factory: () => _FakeBrowser((_) {}),
      maxBrowsers: 1,
    );
    final holder = await pool.acquire();
    await pool.shutdown();
    await holder.release();
    expect(pool.idleCount, 0);
    expect(pool.activeCount, 0);
  });
}
