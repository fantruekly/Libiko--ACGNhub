import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acgnhub/core/account/account_api.dart';
import 'package:acgnhub/core/account/account_models.dart';
import 'package:acgnhub/core/account/account_service.dart';
import 'package:acgnhub/core/storage/database.dart';

class _FakeApi implements AccountApi {
  _FakeApi({this.meThrows401 = false, this.refreshOk = true});
  bool meThrows401;
  bool refreshOk;
  int meCalls = 0;
  int refreshCalls = 0;

  @override
  String get baseUrl => 'http://127.0.0.1:8080';

  @override
  Future<AuthSession> login(String username, String password) async =>
      AuthSession(
          token: 't1',
          refreshToken: 'r1',
          user: AccountUser(id: 1, username: username));

  @override
  Future<AuthSession> register(String username, String password) =>
      login(username, password);

  @override
  Future<String> refresh(String refreshToken) async {
    refreshCalls++;
    if (!refreshOk) {
      throw const AccountException(
          statusCode: 401, code: 'unauthorized', message: 'expired');
    }
    return 't2';
  }

  @override
  Future<AccountUser> me(String token) async {
    meCalls++;
    if (meThrows401 && token == 't1') {
      throw const AccountException(statusCode: 401, code: 'unauthorized', message: 'expired');
    }
    return const AccountUser(id: 1, username: 'alice');
  }
}

ProviderContainer _container(_FakeApi api) => ProviderContainer(overrides: [
      accountProvider.overrideWith(() => AccountNotifier(apiFactory: (_) => api)),
    ]);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('login persists the session and exposes the token', () async {
    await AppDatabase.init();
    final api = _FakeApi();
    final container = _container(api);
    addTearDown(container.dispose);

    await container.read(accountProvider.notifier).login('alice', 'secret1');

    final state = container.read(accountProvider);
    expect(state.isLoggedIn, isTrue);
    expect(state.user!.username, 'alice');
    expect(container.read(accountProvider.notifier).token, 't1');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('account_token'), 't1');
    expect(prefs.getString('account_refresh_token'), 'r1');
  });

  test('a failed login sets an inline error and stays logged out', () async {
    await AppDatabase.init();
    final container = _container(_FailingLoginApi());
    addTearDown(container.dispose);

    await container.read(accountProvider.notifier).login('alice', 'bad');

    final state = container.read(accountProvider);
    expect(state.isLoggedIn, isFalse);
    expect(state.error, '用户名或密码错误');
    expect(state.loading, isFalse);
  });

  test('logout clears the stored session', () async {
    await AppDatabase.init();
    final container = _container(_FakeApi());
    addTearDown(container.dispose);

    await container.read(accountProvider.notifier).login('alice', 'secret1');
    await container.read(accountProvider.notifier).logout();

    expect(container.read(accountProvider).isLoggedIn, isFalse);
    expect(container.read(accountProvider.notifier).token, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('account_token'), isNull);
  });

  test('load validates the stored token', () async {
    await AppDatabase.init();
    final api = _FakeApi();
    final container = _container(api);
    addTearDown(container.dispose);

    await container.read(accountProvider.notifier).login('alice', 'secret1');
    await container.read(accountProvider.notifier).load();

    expect(api.meCalls, greaterThan(0));
    expect(container.read(accountProvider).isLoggedIn, isTrue);
  });

  test('load refreshes after a 401 and keeps the session', () async {
    await AppDatabase.init();
    final api = _FakeApi(meThrows401: true);
    final container = _container(api);
    addTearDown(container.dispose);

    await container.read(accountProvider.notifier).login('alice', 'secret1');
    await container.read(accountProvider.notifier).load();

    expect(api.refreshCalls, 1);
    expect(container.read(accountProvider).isLoggedIn, isTrue);
    expect(container.read(accountProvider.notifier).token, 't2');
  });

  test('load clears the session when validation and refresh both fail', () async {
    await AppDatabase.init();
    final api = _FakeApi(meThrows401: true, refreshOk: false);
    final container = _container(api);
    addTearDown(container.dispose);

    await container.read(accountProvider.notifier).login('alice', 'secret1');
    await container.read(accountProvider.notifier).load();

    expect(container.read(accountProvider).isLoggedIn, isFalse);
    expect(container.read(accountProvider.notifier).token, isNull);
  });

  test('setBaseUrl persists a normalised url and keeps the session', () async {
    await AppDatabase.init();
    final container = _container(_FakeApi());
    addTearDown(container.dispose);

    await container.read(accountProvider.notifier).login('alice', 'secret1');
    await container.read(accountProvider.notifier).setBaseUrl('http://example.com/');

    expect(container.read(accountProvider).baseUrl, 'http://example.com');
    expect(container.read(accountProvider).isLoggedIn, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('account_base_url'), 'http://example.com');
  });

  test('load keeps the stored session but clears the user on a network error',
      () async {
    await AppDatabase.init();
    final container = _container(_NetworkErrorApi());
    addTearDown(container.dispose);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('account_token', 't1');
    await prefs.setString('account_refresh_token', 'r1');

    await container.read(accountProvider.notifier).load();

    expect(container.read(accountProvider).isLoggedIn, isFalse);
    expect(prefs.getString('account_token'), 't1');
  });

  test('refreshSession does not clear the session on a network error', () async {
    await AppDatabase.init();
    final container = _container(_NetworkErrorApi());
    addTearDown(container.dispose);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('account_token', 't1');
    await prefs.setString('account_refresh_token', 'r1');

    expect(
        await container.read(accountProvider.notifier).refreshSession(), isFalse);
    expect(prefs.getString('account_refresh_token'), 'r1');
  });
}

class _FailingLoginApi extends _FakeApi {
  @override
  Future<AuthSession> login(String username, String password) async {
    throw const AccountException(
        statusCode: 401, code: 'unauthorized', message: '用户名或密码错误');
  }
}

class _NetworkErrorApi extends _FakeApi {
  @override
  Future<AccountUser> me(String token) async {
    throw const AccountException(code: 'network', message: '网络错误');
  }

  @override
  Future<String> refresh(String refreshToken) async {
    throw const AccountException(code: 'network', message: '网络错误');
  }
}
