import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/follow_record.dart';
import '../models/watch_record.dart';
import '../models/work.dart';
import '../services/follow_manager.dart';
import '../services/watch_history.dart';
import '../storage/database.dart';
import 'account_api.dart';
import 'account_service.dart';

const _kCursor = 'sync_cursor';

class SyncService {
  SyncService({
    AccountApi Function(String baseUrl)? apiFactory,
    FollowManager? follows,
    WatchHistoryManager? history,
  })  : _apiFactory = apiFactory ?? ((baseUrl) => AccountApi(baseUrl)),
        _follows = follows ?? FollowManager(),
        _history = history ?? WatchHistoryManager();

  final AccountApi Function(String baseUrl) _apiFactory;
  final FollowManager _follows;
  final WatchHistoryManager _history;

  bool _running = false;
  Timer? _debounce;

  /// Coalesces bursts of local changes into one background sync.
  void schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () => sync());
  }

  Future<void> sync() async {
    if (_running) return;
    final db = AppDatabase();
    final token = db.getString('account_token');
    if (token == null) return;

    _running = true;
    try {
      await _run(db, token);
    } finally {
      _running = false;
    }
  }

  Future<void> _run(AppDatabase db, String token) async {
    try {
      await _roundTrip(db, token);
    } on AccountException catch (e) {
      if (e.statusCode != 401) return; // network/other: retry next time
      if (!await _refresh()) return;
      final refreshed = db.getString('account_token');
      if (refreshed == null) return;
      try {
        await _roundTrip(db, refreshed);
      } on AccountException {
        return;
      }
    }
  }

  Future<void> _roundTrip(AppDatabase db, String token) async {
    final api = _apiFactory(_baseUrl(db));
    final pushed = await _push(api, token);
    await _pull(db, api, token);
    if (pushed.follows.isNotEmpty) await _follows.markSynced(pushed.follows);
    if (pushed.clearedHistory) await _history.clearPendingClear();
    if (pushed.history.isNotEmpty) await _history.markSynced(pushed.history);
  }

  Future<_Pushed> _push(AccountApi api, String token) async {
    final follows = <String>{};
    for (final record in _follows.dirty()) {
      if (record.deleted) {
        await api.deleteFollow(
            token, record.work.id, record.updatedAt.millisecondsSinceEpoch);
      } else {
        await api.putFollow(token, record.work.toJson(),
            record.updatedAt.millisecondsSinceEpoch);
      }
      follows.add(record.work.id);
    }

    final history = <String>{};
    final clearedHistory = _history.pendingClear;
    if (clearedHistory) {
      await api.clearHistory(token, DateTime.now().millisecondsSinceEpoch);
      for (final record in _history.dirty()) {
        history.add(record.work.id);
      }
    } else {
      for (final record in _history.dirty()) {
        await api.putHistory(
          token,
          record.work.toJson(),
          record.episodeTitle,
          record.episodeIndex,
          record.watchedAt.millisecondsSinceEpoch,
          record.updatedAt.millisecondsSinceEpoch,
        );
        history.add(record.work.id);
      }
    }
    return _Pushed(follows, history, clearedHistory);
  }

  Future<void> _pull(AppDatabase db, AccountApi api, String token) async {
    final sinceSeq = int.tryParse(db.getString(_kCursor) ?? '0') ?? 0;
    final page = await api.sync(token, sinceSeq);

    await _follows.mergeFromServer(page.follows
        .map((item) => FollowRecord(
              work: Work.fromJson(item.work),
              updatedAt:
                  DateTime.fromMillisecondsSinceEpoch(item.updatedAt),
              deleted: item.deleted,
            ))
        .toList());

    await _history.mergeFromServer(page.history
        .map((item) => WatchRecord(
              work: Work.fromJson(item.work),
              episodeTitle: item.episodeTitle,
              episodeIndex: item.episodeIndex,
              watchedAt: DateTime.fromMillisecondsSinceEpoch(item.watchedAt),
              updatedAt: DateTime.fromMillisecondsSinceEpoch(item.updatedAt),
              deleted: item.deleted,
            ))
        .toList());

    await db.setString(_kCursor, page.nextSeq.toString());
  }

  String _baseUrl(AppDatabase db) =>
      db.getString('account_base_url') ?? kDefaultBaseUrl;

  Future<bool> _refresh() async {
    // AccountNotifier.refreshSession needs a ProviderContainer; the service is
    // constructed with a callback instead so it stays testable.
    return _refreshSession?.call() ?? false;
  }

  Future<bool> Function()? _refreshSession;

  set refreshSession(Future<bool> Function() value) => _refreshSession = value;
}

class _Pushed {
  final Set<String> follows;
  final Set<String> history;
  final bool clearedHistory;

  const _Pushed(this.follows, this.history, this.clearedHistory);
}

final syncProvider = Provider<SyncService>((ref) {
  final service = SyncService();
  service.refreshSession = () =>
      ref.read(accountProvider.notifier).refreshSession();
  return service;
});
