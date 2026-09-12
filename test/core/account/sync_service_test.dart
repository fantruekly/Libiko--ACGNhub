import 'dart:async';

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
  final putHistoryIds = <String>[];
  final clearHistoryAts = <int>[];
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
    return syncPage ?? SyncPage(follows: const [], history: const [], nextSeq: sinceSeq);
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
      putHistoryIds.add(work['id'] as String);

  @override
  Future<void> clearHistory(String token, int updatedAt) async {
    clearHistoryCalls++;
    clearHistoryAts.add(updatedAt);
  }

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
    expect(api.putHistoryIds, ['h']);
    expect(follows.dirty(), isEmpty);
    expect(history.dirty(), isEmpty);
    expect(follows.isFollowing('server'), isTrue);
    expect(AppDatabase().getString('sync_cursor'), '9');
  });

  test('a local write during a push stays dirty and is pushed next time', () async {
    await AppDatabase.init();
    late FollowManager follows;
    var mutations = 0;
    final api = _MutatingApi(() async {
      if (mutations++ == 0) {
        await Future.delayed(const Duration(milliseconds: 2));
        await follows.follow(_work('local'));
      }
    });
    follows = FollowManager();
    await follows.follow(_work('local'));
    await AppDatabase().setString('account_token', 'tok');

    final service = SyncService(
        apiFactory: (_) => api,
        follows: follows,
        history: WatchHistoryManager());
    await service.sync();

    expect(follows.dirty().map((r) => r.work.id), ['local']);

    await service.sync();
    expect(follows.dirty(), isEmpty);
    expect(api.putFollows, ['local', 'local']);
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
    expect(api.putHistoryIds, isEmpty);
    expect(history.pendingClear, isFalse);
    expect(history.dirty(), isEmpty);
  });

  test('a record after a clear is pushed with the stored clear time', () async {
    await AppDatabase.init();
    final api = _FakeApi();
    final history = WatchHistoryManager();
    const ep = VideoEpisode(id: 'e', title: '第1集', index: 0, playUrl: 'u');
    await history.record(_work('h'), ep);
    await history.clear();
    final clearAt = history.clearAt;
    await history.record(_work('h'), ep);
    await AppDatabase().setString('account_token', 'tok');

    await SyncService(
            apiFactory: (_) => api,
            follows: FollowManager(),
            history: history)
        .sync();

    expect(api.clearHistoryCalls, 1);
    expect(clearAt, isNotNull);
    expect(api.clearHistoryAts.single, clearAt);
    expect(api.putHistoryIds, ['h']);
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

  test('a non-account error during sync is swallowed and leaves dirty flags', () async {
    await AppDatabase.init();
    final api = _MalformedApi();
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

  test('a non-account error on the 401 retry is swallowed and leaves dirty flags', () async {
    await AppDatabase.init();
    final api = _RefreshRetryMalformedApi();
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
    expect(follows.dirty(), isNotEmpty);
  });

  test('a sync requested during a run is rerun once', () async {
    await AppDatabase.init();
    final api = _GatedApi();
    await AppDatabase().setString('account_token', 'tok');
    final service = SyncService(
        apiFactory: (_) => api,
        follows: FollowManager(),
        history: WatchHistoryManager());

    final first = service.sync();
    await Future.delayed(const Duration(milliseconds: 5));
    await service.sync(); // dropped while running, but flags a rerun
    api.gate.complete();
    await first;

    expect(api.syncCalls, 2);
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

class _GatedApi extends _FakeApi {
  final gate = Completer<void>();

  @override
  Future<SyncPage> sync(String token, int sinceSeq) async {
    syncCalls++;
    if (syncCalls == 1) await gate.future;
    return SyncPage(follows: const [], history: const [], nextSeq: sinceSeq);
  }
}

class _MalformedApi extends _FakeApi {
  @override
  Future<SyncPage> sync(String token, int sinceSeq) async {
    throw const FormatException('malformed payload');
  }
}

class _RefreshRetryMalformedApi extends _FakeApi {
  @override
  Future<SyncPage> sync(String token, int sinceSeq) async {
    syncCalls++;
    if (syncCalls == 1) {
      throw const AccountException(
          statusCode: 401, code: 'unauthorized', message: 'expired');
    }
    throw const FormatException('bad payload');
  }
}

class _MutatingApi extends _FakeApi {
  _MutatingApi(this.onPutFollow);
  final Future<void> Function() onPutFollow;

  @override
  Future<void> putFollow(
      String token, Map<String, dynamic> work, int updatedAt) async {
    putFollows.add(work['id'] as String);
    await onPutFollow();
  }
}
