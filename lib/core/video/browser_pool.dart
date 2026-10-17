import 'dart:async';

import 'package:flutter/foundation.dart';

import '../platform.dart';
import 'headless_browser.dart';
import 'cancellation.dart';

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
  Future<void>? _pendingLoad;

  Stream<MediaCandidate> get mediaUrls =>
      _browser.mediaUrls.where((c) => !_released && c.loadId == _loadId);

  Future<void> load(String url,
      {Duration timeout = const Duration(seconds: 8)}) {
    if (_released) {
      return Future.error(StateError('browser handle has been released'));
    }
    if (_pendingLoad != null) {
      return Future.error(StateError('browser is already loading'));
    }
    final pending = _load(url, timeout: timeout);
    _pendingLoad = pending;
    return pending.whenComplete(() => _pendingLoad = null);
  }

  Future<void> _load(String url, {required Duration timeout}) async {
    _loadId = -1;
    if (_entry.dirty) {
      // Tear down the previous page so its still-in-flight media requests
      // cannot leak into this session, and the next navigation starts clean.
      try {
        await _browser.load('about:blank', timeout: const Duration(seconds: 2));
      } catch (_) {}
      _entry.dirty = false;
    }
    if (_released) return;
    final future = _browser.load(url, timeout: timeout);
    _entry.dirty = true;
    _loadId = _browser.loadId;
    return future;
  }

  Future<dynamic> eval(String script) {
    if (_released) throw StateError('browser handle has been released');
    return _browser.eval(script);
  }

  Future<void> release() async {
    if (_released) return;
    _released = true;
    // Do not lend this WebView while its previous navigation is still active.
    // In particular, a cancellation during the blank-page barrier must not
    // start a late navigation after the next caller has borrowed it.
    try {
      await _pendingLoad;
    } catch (_) {}
    await _pool.release(this);
  }
}

class _PoolEntry {
  _PoolEntry(this.browser, this.userAgent, this.extraScript, this.createdAt,
      this.lastUsed);
  final HeadlessBrowser browser;
  final String userAgent;
  final String? extraScript;
  final DateTime createdAt;
  DateTime lastUsed;
  int uses = 0;
  bool dirty = false;
}

class _Waiter {
  _Waiter(this.userAgent, this.extraScript, this.priority);
  final String userAgent;
  final String? extraScript;
  final BrowserPriority priority;
  final completer = Completer<_PoolEntry>();
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
  final Set<_Waiter> _starting = {};
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
    String? extraScript,
    CancellationToken? cancel,
    BrowserPriority priority = BrowserPriority.foreground,
  }) async {
    if (_shutdown) throw StateError('browser pool has been shut down');
    if (cancel?.isCancelled == true) {
      throw StateError('browser acquisition cancelled');
    }
    final waiter =
        _Waiter(userAgent ?? kBrowserUserAgent, extraScript, priority);
    void cancelled() {
      _foreground.remove(waiter);
      _background.remove(waiter);
      if (!waiter.completer.isCompleted) {
        waiter.completer
            .completeError(StateError('browser acquisition cancelled'));
      }
      _pump();
    }

    (priority == BrowserPriority.foreground ? _foreground : _background)
        .add(waiter);
    cancel?.addListener(cancelled);
    _evictExpired();
    _pump();
    try {
      final entry = await waiter.completer.future;
      // Cancellation can happen after handoff but before this continuation.
      if (cancel?.isCancelled == true || _shutdown) {
        await PooledBrowser._(this, entry).release();
        throw StateError('browser acquisition cancelled');
      }
      return PooledBrowser._(this, entry);
    } finally {
      cancel?.removeListener(cancelled);
    }
  }

  void _deliver(_Waiter waiter, _PoolEntry entry) {
    entry.lastUsed = _now();
    entry.uses++;
    _active.add(entry);
    waiter.completer.complete(entry);
  }

  _PoolEntry? _takeIdle(String ua, String? extraScript) {
    for (var i = 0; i < _idle.length; i++) {
      final entry = _idle[i];
      if (entry.userAgent != ua || entry.extraScript != extraScript) continue;
      _idle.removeAt(i);
      if (_expired(entry)) {
        unawaited(_retire(entry));
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
      _creating++;
      try {
        await _dispose(entry);
      } finally {
        _releaseCreateSlot();
      }
      return;
    }
    entry.lastUsed = _now();
    if (!_handOff(entry)) _idle.add(entry);
    _pump();
  }

  bool _handOff(_PoolEntry entry) {
    for (final queue in [_foreground, _background]) {
      for (var i = 0; i < queue.length; i++) {
        final waiter = queue[i];
        if (waiter.userAgent == entry.userAgent &&
            waiter.extraScript == entry.extraScript) {
          queue.removeAt(i);
          _deliver(waiter, entry);
          return true;
        }
      }
    }
    return false;
  }

  Future<void> _startWaiter(_Waiter waiter, _PoolEntry? stale) async {
    try {
      if (stale != null) await _dispose(stale);
      if (_shutdown || waiter.completer.isCompleted) return;
      final entry = await _create(waiter.userAgent, waiter.extraScript);
      // start() cannot be interrupted on every platform. Keep its slot until
      // the late browser has been disposed, rather than exceeding the cap.
      if (_shutdown || waiter.completer.isCompleted) {
        await _dispose(entry);
      } else {
        _deliver(waiter, entry);
      }
    } catch (e, st) {
      if (!waiter.completer.isCompleted) waiter.completer.completeError(e, st);
    } finally {
      _starting.remove(waiter);
      _releaseCreateSlot();
    }
  }

  void _pump() {
    if (_shutdown) return;
    while (true) {
      final queue = _foreground.isNotEmpty
          ? _foreground
          : (_background.isNotEmpty ? _background : null);
      if (queue == null) return;
      final waiter = queue.first;
      final idle = _takeIdle(waiter.userAgent, waiter.extraScript);
      if (idle != null) {
        queue.removeAt(0);
        _deliver(waiter, idle);
        continue;
      }
      _PoolEntry? stale;
      if (_total >= _capFor(waiter.priority)) {
        if (waiter.priority != BrowserPriority.foreground || _idle.isEmpty) {
          return;
        }
        stale = _idle.removeAt(0);
      }
      queue.removeAt(0);
      _creating++;
      _starting.add(waiter);
      unawaited(_startWaiter(waiter, stale));
    }
  }

  void _evictExpired() {
    _idle.removeWhere((e) {
      if (!_expired(e)) return false;
      unawaited(_retire(e));
      return true;
    });
  }

  bool _expired(_PoolEntry e) =>
      _now().difference(e.lastUsed) >= idleTimeout ||
      _now().difference(e.createdAt) >= maxAgePerBrowser;

  Future<_PoolEntry> _create(String ua, String? extraScript) async {
    final browser = _factory();
    try {
      await browser.start(userAgent: ua, extraScript: extraScript);
    } catch (_) {
      try {
        await browser.dispose();
      } catch (_) {}
      rethrow;
    }
    final now = _now();
    return _PoolEntry(browser, ua, extraScript, now, now);
  }

  Future<void> _retire(_PoolEntry entry) async {
    _creating++;
    try {
      await _dispose(entry);
    } finally {
      _releaseCreateSlot();
    }
  }

  Future<void> _dispose(_PoolEntry entry) async {
    try {
      await entry.browser.dispose();
    } catch (_) {}
  }

  Future<void> shutdown() async {
    _shutdown = true;
    final error = StateError('pool shut down');
    for (final waiter in [..._foreground, ..._background, ..._starting]) {
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
