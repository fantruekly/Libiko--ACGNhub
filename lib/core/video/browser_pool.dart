import 'dart:async';

import 'package:flutter/foundation.dart';

import '../platform.dart';
import 'headless_browser.dart';

/// Scheduling priority for a pooled browser: foreground work (the user tapped
/// play) is served before background work (prefetch, source search).
enum BrowserPriority { foreground, background }

/// A borrowed headless browser. Call [release] when done. [mediaUrls] only
/// exposes candidates observed by the [load] made through this handle.
class PooledBrowser {
  PooledBrowser._(this._pool, this._entry)
      : _browser = _entry.browser,
        userAgent = _entry.userAgent,
        _loadId = -1;

  final HeadlessBrowserPool _pool;
  final _PoolEntry _entry;
  final HeadlessBrowser _browser;
  final String userAgent;
  int _loadId;
  bool _released = false;

  Stream<MediaCandidate> get mediaUrls =>
      _browser.mediaUrls.where((c) => c.loadId == _loadId);

  Future<void> load(String url,
      {Duration timeout = const Duration(seconds: 8)}) async {
    if (_entry.dirty) {
      // Tear down the previous page so its still-in-flight media requests
      // cannot leak into this session, and the next navigation starts clean.
      try {
        await _browser.load('about:blank',
            timeout: const Duration(seconds: 2));
      } catch (_) {}
      _entry.dirty = false;
    }
    final future = _browser.load(url, timeout: timeout);
    _entry.dirty = true;
    _loadId = _browser.loadId;
    return future;
  }

  Future<dynamic> eval(String script) => _browser.eval(script);

  Future<void> release() async {
    if (_released) return;
    _released = true;
    await _pool.release(this);
  }
}

class _PoolEntry {
  _PoolEntry(this.browser, this.userAgent, this.createdAt, this.lastUsed);
  final HeadlessBrowser browser;
  final String userAgent;
  final DateTime createdAt;
  DateTime lastUsed;
  int uses = 0;
  bool dirty = false;
}

class _Waiter {
  _Waiter(this.userAgent, this.priority, this.completer);
  final String userAgent;
  final BrowserPriority priority;
  final Completer<_PoolEntry> completer;
}

/// Reuses warm headless browsers instead of creating and disposing one per
/// resolve/search. Browsers are grouped by user agent, capped globally, served
/// foreground-first, and recycled on idle/age/use limits.
class HeadlessBrowserPool {
  HeadlessBrowserPool({
    HeadlessBrowser Function()? factory,
    int? maxBrowsers,
    this.idleTimeout = const Duration(seconds: 120),
    this.maxUsesPerBrowser = 20,
    this.maxAgePerBrowser = const Duration(minutes: 10),
    DateTime Function()? clock,
  })  : _factory = factory ?? createHeadlessBrowser,
        maxBrowsers = maxBrowsers ?? (isDesktop ? 4 : 3),
        _now = clock ?? DateTime.now;

  final HeadlessBrowser Function() _factory;
  final int maxBrowsers;
  final Duration idleTimeout;
  final int maxUsesPerBrowser;
  final Duration maxAgePerBrowser;
  final DateTime Function() _now;

  final List<_PoolEntry> _idle = [];
  final List<_PoolEntry> _active = [];
  final List<_Waiter> _foreground = [];
  final List<_Waiter> _background = [];
  int _creating = 0;
  bool _shutdown = false;

  @visibleForTesting
  int get idleCount => _idle.length;
  @visibleForTesting
  int get activeCount => _active.length;

  int get _total => _idle.length + _active.length + _creating;

  /// Background work may use at most [maxBrowsers] - 1 browsers so one is kept
  /// free for a foreground (user-initiated) resolve.
  int _capFor(BrowserPriority priority) =>
      priority == BrowserPriority.background && maxBrowsers > 1
          ? maxBrowsers - 1
          : maxBrowsers;

  /// Releases the in-flight creation slot and re-pumps the queues. A failed
  /// create must still serve queued waiters (creating or erroring), otherwise
  /// they would hang forever.
  void _releaseCreateSlot() {
    _creating--;
    _pump();
  }

  Future<PooledBrowser> acquire({
    String? userAgent,
    BrowserPriority priority = BrowserPriority.foreground,
  }) async {
    if (_shutdown) throw StateError('browser pool has been shut down');
    final ua = userAgent ?? kBrowserUserAgent;
    _evictExpired();
    final reused = _takeIdle(ua);
    if (reused != null) return _borrow(reused);
    if (_total < _capFor(priority)) {
      _creating++;
      try {
        return _borrow(await _create(ua));
      } finally {
        _releaseCreateSlot();
      }
    }
    if (priority == BrowserPriority.foreground && _idle.isNotEmpty) {
      final stale = _idle.removeAt(0);
      _creating++;
      try {
        await _dispose(stale);
        return _borrow(await _create(ua));
      } finally {
        _releaseCreateSlot();
      }
    }
    final waiter = _Waiter(ua, priority, Completer<_PoolEntry>());
    (priority == BrowserPriority.foreground ? _foreground : _background)
        .add(waiter);
    final entry = await waiter.completer.future;
    return PooledBrowser._(this, entry);
  }

  PooledBrowser _borrow(_PoolEntry entry) {
    entry.lastUsed = _now();
    entry.uses++;
    _active.add(entry);
    return PooledBrowser._(this, entry);
  }

  _PoolEntry? _takeIdle(String ua) {
    for (var i = 0; i < _idle.length; i++) {
      final entry = _idle[i];
      if (entry.userAgent != ua) continue;
      _idle.removeAt(i);
      if (_expired(entry)) {
        unawaited(_dispose(entry));
        i--;
        continue;
      }
      return entry;
    }
    return null;
  }

  Future<void> release(PooledBrowser pooled) async {
    if (_shutdown) return;
    final entry = pooled._entry;
    _active.remove(entry);
    if (_expired(entry) || entry.uses >= maxUsesPerBrowser) {
      await _dispose(entry);
      _pump();
      return;
    }
    entry.lastUsed = _now();
    if (!_handOff(entry)) _idle.add(entry);
    _pump();
  }

  bool _handOff(_PoolEntry entry) {
    for (final queue in [_foreground, _background]) {
      for (var i = 0; i < queue.length; i++) {
        if (queue[i].userAgent == entry.userAgent) {
          final waiter = queue.removeAt(i);
          entry.lastUsed = _now();
          entry.uses++;
          _active.add(entry);
          waiter.completer.complete(entry);
          return true;
        }
      }
    }
    return false;
  }

  void _pump() {
    if (_shutdown) return;
    while (true) {
      final queue = _foreground.isNotEmpty
          ? _foreground
          : (_background.isNotEmpty ? _background : null);
      if (queue == null) return;
      final waiter = queue.first;
      final idle = _takeIdle(waiter.userAgent);
      if (idle != null) {
        queue.removeAt(0);
        idle.lastUsed = _now();
        idle.uses++;
        _active.add(idle);
        waiter.completer.complete(idle);
        continue;
      }
      if (_total < _capFor(waiter.priority)) {
        queue.removeAt(0);
        _creating++;
        unawaited(_create(waiter.userAgent).then((entry) {
          entry.lastUsed = _now();
          entry.uses++;
          _active.add(entry);
          waiter.completer.complete(entry);
        }, onError: (Object e, StackTrace st) {
          waiter.completer.completeError(e, st);
        }).whenComplete(() {
          _releaseCreateSlot();
        }));
        continue;
      }
      if (waiter.priority == BrowserPriority.foreground && _idle.isNotEmpty) {
        queue.removeAt(0);
        final stale = _idle.removeAt(0);
        _creating++;
        unawaited(_dispose(stale)
            .then((_) => _create(waiter.userAgent))
            .then((entry) {
          entry.lastUsed = _now();
          entry.uses++;
          _active.add(entry);
          waiter.completer.complete(entry);
        }, onError: (Object e, StackTrace st) {
          waiter.completer.completeError(e, st);
        }).whenComplete(() {
          _releaseCreateSlot();
        }));
        continue;
      }
      return;
    }
  }

  void _evictExpired() {
    _idle.removeWhere((e) {
      if (!_expired(e)) return false;
      unawaited(_dispose(e));
      return true;
    });
  }

  bool _expired(_PoolEntry e) =>
      _now().difference(e.lastUsed) >= idleTimeout ||
      _now().difference(e.createdAt) >= maxAgePerBrowser;

  Future<_PoolEntry> _create(String ua) async {
    final browser = _factory();
    try {
      await browser.start(userAgent: ua);
    } catch (_) {
      try {
        await browser.dispose();
      } catch (_) {}
      rethrow;
    }
    final now = _now();
    return _PoolEntry(browser, ua, now, now);
  }

  Future<void> _dispose(_PoolEntry entry) async {
    try {
      await entry.browser.dispose();
    } catch (_) {}
  }

  Future<void> shutdown() async {
    _shutdown = true;
    final error = StateError('pool shut down');
    for (final waiter in [..._foreground, ..._background]) {
      if (!waiter.completer.isCompleted) {
        waiter.completer.completeError(error);
      }
    }
    _foreground.clear();
    _background.clear();
    for (final entry in [..._idle, ..._active]) {
      await _dispose(entry);
    }
    _idle.clear();
    _active.clear();
  }
}

/// The app-wide pool shared by the resolver and the scraper.
final HeadlessBrowserPool sharedBrowserPool = HeadlessBrowserPool();
