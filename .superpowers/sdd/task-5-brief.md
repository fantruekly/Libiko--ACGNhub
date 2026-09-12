### Task 5: `SyncService` + triggers

**Files:**
- Create: `lib/core/account/sync_service.dart`
- Modify: `lib/core/account/account_service.dart` (trigger after login/register)
- Modify: `lib/modules/anime/video_player_page.dart` (trigger after recording)
- Modify: `lib/modules/anime/anime_history.dart` (trigger after clearing)
- Test: `test/core/account/sync_service_test.dart`

**Interfaces:**
- Consumes: `AccountApi`/`AccountException`/`SyncPage`, `accountProvider`, `FollowManager`, `WatchHistoryManager`, `AppDatabase`.
- Produces: `class SyncService { SyncService({AccountApi Function(String)? apiFactory, FollowManager? follows, WatchHistoryManager? history}); Future<void> sync(); void schedule(); }`; `final syncProvider = Provider<SyncService>(...)`.

- [ ] **Step 1: Write the failing test**

Create `test/core/account/sync_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acgnhub/core/account/account_api.dart';
import 'package:acgnhub/core/account/account_models.dart';
import 'package:acgnhub/core/account/sync_service.dart';
import 'package:acgnhub/core/models/work.dart';
import 'package:acgnhub/core/services/follow_manager.dart';
import 'package:acgnhub/core/services/watch_history.dart';
import 'package:acgnhub/core/storage/database.dart';
import 'package:acgnhub/core/video/video_source.dart';

Work _work(String id) => Work(
    id: id,
    sourceId: 'bangumi',
    sourceName: 'Bangumi',
    type: WorkType.anime,
    title: 'Title $id');

class _FakeApi implements AccountApi {
  _FakeApi({this.syncPage, this.unauthorizedOnce = false});
  SyncPage? syncPage;
  bool unauthorizedOnce;
  final putFollows = <String>[];
  final deleteFollows = <String>[];
  final putHistory = <String>[];
  int clearHistoryCalls = 0;
  int syncCalls = 0;

  @override
  String get baseUrl => 'http://127.0.0.1:8080';

  @override
  Future<SyncPage> sync(String token, int sinceSeq) async {
    syncCalls++;
    if (unauthorizedOnce && syncCalls == 1) {
      throw const AccountException(statusCode: 401, code: 'unauthorized', message: 'expired');
    }
    return syncPage ?? const SyncPage(follows: [], history: [], nextSeq: sinceSeq);
  }

  @override
  Future<void> putFollow(String token, Map<String, dynamic> work, int updatedAt) async =>
      putFollows.add(work['id'] as String);

  @override
  Future<void> deleteFollow(String token, String workId, int updatedAt) async =>
      deleteFollows.add(workId);

  @override
  Future<void> putHistory(String token, Map<String, dynamic> work,
          String episodeTitle, int episodeIndex, int watchedAt, int updatedAt) async =>
      putHistory.add(work['id'] as String);

  @override
  Future<void> clearHistory(String token, int updatedAt) async =>
      clearHistoryCalls++;

  @override
  Future<AuthSession> register(String username, String password) async =>
      throw UnimplementedError();

  @override
  Future<AuthSession> login(String username, String password) async =>
      throw UnimplementedError();

  @override
  Future<String> refresh(String refreshToken) async => 'new-token';

  @override
  Future<AccountUser> me(String token) async =>
      const AccountUser(id: 1, username: 'alice');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('pushes dirty follows and history then pulls and advances the cursor', () async {
    await AppDatabase.init();
    final api = _FakeApi(
      syncPage: SyncPage(
        follows: [
          FollowItem(
              work: _work('server').toJson(), updatedAt: 500, deleted: false)
        ],
        history: const [],
        nextSeq: 9,
      ),
    );
    final follows = FollowManager();
    final history = WatchHistoryManager();
    await follows.follow(_work('local'));
    await history.record(
        _work('h'), const VideoEpisode(id: 'e', title: '第1集', index: 0, playUrl: 'u'));
    await AppDatabase().setString('account_token', 'tok');

    await SyncService(apiFactory: (_) => api, follows: follows, history: history)
        .sync();

    expect(api.putFollows, ['local']);
    expect(api.putHistory, ['h']);
    expect(follows.dirty(), isEmpty);
    expect(history.dirty(), isEmpty);
    expect(follows.isFollowing('server'), isTrue);
    expect(AppDatabase().getString('sync_cursor'), '9');
  });

  test('a history pendingClear pushes a clear instead of per-record puts', () async {
    await AppDatabase.init();
    final api = _FakeApi();
    final history = WatchHistoryManager();
    await history.record(
        _work('h'), const VideoEpisode(id: 'e', title: '第1集', index: 0, playUrl: 'u'));
    await history.clear();
    await AppDatabase().setString('account_token', 'tok');

    await SyncService(apiFactory: (_) => api, follows: FollowManager(), history: history)
        .sync();

    expect(api.clearHistoryCalls, 1);
    expect(api.putHistory, isEmpty);
    expect(history.pendingClear, isFalse);
    expect(history.dirty(), isEmpty);
  });

  test('a network failure leaves dirty flags set', () async {
    await AppDatabase.init();
    final api = _NetworkFailApi();
    final follows = FollowManager();
    await follows.follow(_work('local'));
    await AppDatabase().setString('account_token', 'tok');

    await SyncService(apiFactory: (_) => api, follows: follows, history: WatchHistoryManager())
        .sync();

    expect(follows.dirty(), isNotEmpty);
  });

  test('a 401 refreshes and retries the sync once', () async {
    await AppDatabase.init();
    final api = _FakeApi(unauthorizedOnce: true);
    final follows = FollowManager();
    await follows.follow(_work('local'));
    await AppDatabase().setString('account_token', 'tok');

    final service = SyncService(
        apiFactory: (_) => api,
        follows: follows,
        history: WatchHistoryManager());
    var refreshes = 0;
    service.refreshSession = () async {
      refreshes++;
      return true;
    };

    await service.sync();

    expect(refreshes, 1);
    expect(api.syncCalls, 2);
    expect(follows.dirty(), isEmpty);
  });

  test('no token is a no-op', () async {
    await AppDatabase.init();
    final api = _FakeApi();
    await SyncService(apiFactory: (_) => api, follows: FollowManager(), history: WatchHistoryManager())
        .sync();
    expect(api.syncCalls, 0);
  });
}

class _NetworkFailApi extends _FakeApi {
  @override
  Future<SyncPage> sync(String token, int sinceSeq) async {
    throw const AccountException(code: 'network', message: '网络错误');
  }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/account/sync_service_test.dart`
Expected: FAIL — `sync_service.dart` not found.

- [ ] **Step 3: Create `lib/core/account/sync_service.dart`**

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/follow_record.dart';
import '../models/watch_record.dart';
import '../services/follow_manager.dart';
import '../services/watch_history.dart';
import '../storage/database.dart';
import 'account_api.dart';
import 'account_models.dart';
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
      await _push(db, token);
      await _pull(db, token);
    } on AccountException catch (e) {
      if (e.statusCode != 401) return; // network/other: retry next time
      if (!await _refresh()) return;
      final refreshed = db.getString('account_token');
      if (refreshed == null) return;
      try {
        await _push(db, refreshed);
        await _pull(db, refreshed);
      } on AccountException {
        return;
      }
    }
  }

  Future<void> _push(AppDatabase db, String token) async {
    final api = _apiFactory(_baseUrl(db));
    final syncedFollows = <String>{};
    for (final record in _follows.dirty()) {
      if (record.deleted) {
        await api.deleteFollow(
            token, record.work.id, record.updatedAt.millisecondsSinceEpoch);
      } else {
        await api.putFollow(token, record.work.toJson(),
            record.updatedAt.millisecondsSinceEpoch);
      }
      syncedFollows.add(record.work.id);
    }
    if (syncedFollows.isNotEmpty) await _follows.markSynced(syncedFollows);

    final syncedHistory = <String>{};
    if (_history.pendingClear) {
      await api.clearHistory(token, DateTime.now().millisecondsSinceEpoch);
      for (final record in _history.dirty()) {
        syncedHistory.add(record.work.id);
      }
      await _history.clearPendingClear();
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
        syncedHistory.add(record.work.id);
      }
    }
    if (syncedHistory.isNotEmpty) await _history.markSynced(syncedHistory);
  }

  Future<void> _pull(AppDatabase db, String token) async {
    final sinceSeq = int.tryParse(db.getString(_kCursor) ?? '0') ?? 0;
    final page = await _apiFactory(_baseUrl(db)).sync(token, sinceSeq);

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

final syncProvider = Provider<SyncService>((ref) => SyncService());
```

`Work` needs importing: add `import '../models/work.dart';`.

Hmm — the 401 retry needs `accountProvider.notifier.refreshSession()`. Wiring that into a plain `SyncService` is awkward. Simplify: give `SyncService` a `Future<bool> Function()? refreshSession` setter, and wire it in the provider:

```dart
final syncProvider = Provider<SyncService>((ref) {
  final service = SyncService();
  service.refreshSession = () => ref.read(accountProvider.notifier).refreshSession();
  return service;
});
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/account/sync_service_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Wire the triggers**

- `lib/core/account/account_service.dart`: at the end of `_authenticate`'s success branch, after setting state, add
  `ref.read(syncProvider.notifier).schedule();` (add `import 'sync_service.dart';`).
- `lib/modules/anime/video_player_page.dart`: after `await history.record(work, episode);` add
  `ref.read(syncProvider.notifier).schedule();` (add `import '../../core/account/sync_service.dart';`).
- `lib/modules/anime/anime_history.dart`: after `await ref.read(watchHistoryProvider.notifier).clear();` add
  `ref.read(syncProvider.notifier).schedule();` (add the import).
- `lib/main.dart`: after the startup `unawaited(container.read(accountProvider.notifier).load());` add
  `unawaited(container.read(accountProvider.notifier).load().then((_) => container.read(syncProvider.notifier).sync()));`
  — i.e. chain a one-shot sync after the load future. (Replace the existing single `unawaited(...load())` line with a
  single `unawaited(container.read(accountProvider.notifier).load().then((_) => container.read(syncProvider.notifier).sync()));`
  and add `import 'core/account/sync_service.dart';`.)

- [ ] **Step 6: Analyze and run the full suite**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → all pass.

- [ ] **Step 7: Commit**

```bash
git add lib/core/account/sync_service.dart lib/core/account/account_service.dart lib/modules/anime/video_player_page.dart lib/modules/anime/anime_history.dart lib/main.dart test/core/account/sync_service_test.dart
git commit -m "feat(sync): add SyncService and its triggers"
```

---
