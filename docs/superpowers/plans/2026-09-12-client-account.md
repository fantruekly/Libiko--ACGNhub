# Client Account Implementation Plan (B2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user register/login against the self-hosted backend from the settings page, keep the session locally, and expose the access token (with refresh) to the rest of the app.

**Architecture:** A new `lib/core/account/` package: `AccountApi` (its own JSON `Dio`, mapping errors to `AccountException`), `AccountUser`/`AuthSession` models, and `AccountNotifier`/`accountProvider` holding an `AccountState` and persisting the session through `AppDatabase`. The settings page renders an 账号 section; `main()` kicks off `load()`.

**Tech Stack:** Flutter 3.35, Dart 3, Riverpod 2 (`NotifierProvider`), `dio`, `shared_preferences` via `AppDatabase`.

## Global Constraints

- The account API must NOT reuse `lib/core/services/http_client.dart` (it is HTML/browser-UA oriented); `AccountApi` owns a JSON `Dio`.
- The backend contract (B1): `POST /api/auth/register|login` → `{token, refreshToken, user:{id, username}}`; `POST /api/auth/refresh` → `{token}`; `GET /api/me` → `{id, username}`; errors `{"error","message"}`.
- Default base URL `http://127.0.0.1:8080`; a trailing `/` is stripped.
- Persistence keys via `AppDatabase`: `account_base_url`, `account_token`, `account_refresh_token`, `account_user`.
- Design tokens: accent `#007AFF`, muted `#8E8E93`.
- Commit after every task. Flutter commands run with `$env:Path = "C:\flutter\bin;$env:Path";` prefixed.

---

### Task 1: Account models

**Files:**
- Create: `lib/core/account/account_models.dart`
- Test: `test/core/account/account_models_test.dart`

**Interfaces:**
- Produces: `class AccountUser { final int id; final String username; }` with `fromJson`/`toJson`; `class AuthSession { final String token; final String refreshToken; final AccountUser user; }` with `fromJson`.

- [ ] **Step 1: Write the failing test**

Create `test/core/account/account_models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/account/account_models.dart';

void main() {
  test('AccountUser round-trips through JSON', () {
    const user = AccountUser(id: 7, username: 'alice');
    final restored = AccountUser.fromJson(user.toJson());
    expect(restored.id, 7);
    expect(restored.username, 'alice');
  });

  test('AuthSession parses the backend response', () {
    final session = AuthSession.fromJson({
      'token': 'access-1',
      'refreshToken': 'refresh-1',
      'user': {'id': 3, 'username': 'bob'},
    });
    expect(session.token, 'access-1');
    expect(session.refreshToken, 'refresh-1');
    expect(session.user.id, 3);
    expect(session.user.username, 'bob');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/account/account_models_test.dart`
Expected: FAIL — `account_models.dart` not found.

- [ ] **Step 3: Create `lib/core/account/account_models.dart`**

```dart
class AccountUser {
  final int id;
  final String username;

  const AccountUser({required this.id, required this.username});

  factory AccountUser.fromJson(Map<String, dynamic> json) => AccountUser(
        id: json['id'] as int,
        username: json['username'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'username': username};
}

class AuthSession {
  final String token;
  final String refreshToken;
  final AccountUser user;

  const AuthSession({
    required this.token,
    required this.refreshToken,
    required this.user,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        token: json['token'] as String,
        refreshToken: json['refreshToken'] as String,
        user: AccountUser.fromJson(json['user'] as Map<String, dynamic>),
      );
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/account/account_models_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/account/account_models.dart test/core/account/account_models_test.dart
git commit -m "feat(account): add account models"
```

---

### Task 2: `AccountApi`

**Files:**
- Create: `lib/core/account/account_api.dart`
- Test: `test/core/account/account_api_test.dart`

**Interfaces:**
- Consumes: `AccountUser`, `AuthSession` (Task 1).
- Produces: `class AccountException implements Exception { final int? statusCode; final String code; final String message; }`; `class AccountApi { AccountApi(String baseUrl, {Dio? dio}); final String baseUrl; Future<AuthSession> register(String, String); Future<AuthSession> login(String, String); Future<String> refresh(String); Future<AccountUser> me(String token); }`.

- [ ] **Step 1: Write the failing test**

Create `test/core/account/account_api_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/account/account_api.dart';

/// A Dio adapter that records the last request and returns a canned response.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.statusCode, this.body);
  final int statusCode;
  final String body;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    last = options;
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

AccountApi _api(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(validateStatus: (_) => true));
  dio.httpClientAdapter = adapter;
  return AccountApi('http://127.0.0.1:8080/', dio: dio);
}

void main() {
  test('login posts to /api/auth/login and parses the session', () async {
    final adapter = _FakeAdapter(
      200,
      jsonEncode({
        'token': 't1',
        'refreshToken': 'r1',
        'user': {'id': 1, 'username': 'alice'},
      }),
    );
    final session = await _api(adapter).login('alice', 'secret1');

    expect(session.token, 't1');
    expect(session.refreshToken, 'r1');
    expect(session.user.username, 'alice');
    expect(adapter.last!.method, 'POST');
    expect(adapter.last!.uri.toString(), 'http://127.0.0.1:8080/api/auth/login');
    expect(adapter.last!.data, {'username': 'alice', 'password': 'secret1'});
  });

  test('me sends the bearer token and parses the user', () async {
    final adapter = _FakeAdapter(200, jsonEncode({'id': 2, 'username': 'bob'}));
    final user = await _api(adapter).me('tok');

    expect(user.id, 2);
    expect(user.username, 'bob');
    expect(adapter.last!.uri.path, '/api/me');
    expect(adapter.last!.headers['authorization'], 'Bearer tok');
  });

  test('refresh returns the new access token', () async {
    final adapter = _FakeAdapter(200, jsonEncode({'token': 't2'}));
    expect(await _api(adapter).refresh('r1'), 't2');
    expect(adapter.last!.uri.path, '/api/auth/refresh');
  });

  test('a non-2xx response becomes an AccountException with the backend code',
      () async {
    final adapter = _FakeAdapter(
      409,
      jsonEncode({'error': 'conflict', 'message': 'Username already taken'}),
    );
    await expectLater(
      _api(adapter).register('alice', 'secret1'),
      throwsA(isA<AccountException>()
          .having((e) => e.statusCode, 'statusCode', 409)
          .having((e) => e.code, 'code', 'conflict')
          .having((e) => e.message, 'message', 'Username already taken')),
    );
  });

  test('a connection failure becomes a network AccountException', () async {
    final dio = Dio(BaseOptions(validateStatus: (_) => true));
    dio.httpClientAdapter = _ThrowingAdapter();
    final api = AccountApi('http://127.0.0.1:8080', dio: dio);

    await expectLater(
      api.login('alice', 'secret1'),
      throwsA(isA<AccountException>().having((e) => e.code, 'code', 'network')),
    );
  });
}

class _ThrowingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    throw DioException.connectionError(
        requestOptions: options, reason: 'refused');
  }

  @override
  void close({bool force = false}) {}
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/account/account_api_test.dart`
Expected: FAIL — `account_api.dart` not found.

- [ ] **Step 3: Create `lib/core/account/account_api.dart`**

```dart
import 'package:dio/dio.dart';

import 'account_models.dart';

class AccountException implements Exception {
  final int? statusCode;
  final String code;
  final String message;

  const AccountException({
    this.statusCode,
    required this.code,
    required this.message,
  });

  @override
  String toString() => 'AccountException($statusCode, $code): $message';
}

class AccountApi {
  AccountApi(String baseUrl, {Dio? dio})
      : baseUrl = _normalize(baseUrl),
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              contentType: Headers.jsonContentType,
              validateStatus: (_) => true,
            ));

  final String baseUrl;
  final Dio _dio;

  static String _normalize(String url) {
    final trimmed = url.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  Future<AuthSession> register(String username, String password) =>
      _session('/api/auth/register', username, password);

  Future<AuthSession> login(String username, String password) =>
      _session('/api/auth/login', username, password);

  Future<AuthSession> _session(
      String path, String username, String password) async {
    final json =
        await _request(() => _dio.post('$baseUrl$path', data: {
              'username': username,
              'password': password,
            }));
    return AuthSession.fromJson(json);
  }

  Future<String> refresh(String refreshToken) async {
    final json = await _request(() => _dio.post('$baseUrl/api/auth/refresh',
        data: {'refreshToken': refreshToken}));
    return json['token'] as String;
  }

  Future<AccountUser> me(String token) async {
    final json = await _request(() => _dio.get('$baseUrl/api/me',
        options: Options(headers: {'authorization': 'Bearer $token'})));
    return AccountUser.fromJson(json);
  }

  Future<Map<String, dynamic>> _request(
      Future<Response> Function() send) async {
    final Response response;
    try {
      response = await send();
    } on DioException catch (e) {
      throw AccountException(code: 'network', message: _networkMessage(e));
    }
    final status = response.statusCode ?? 0;
    final data = response.data;
    final map = data is Map<String, dynamic> ? data : <String, dynamic>{};
    if (status >= 200 && status < 300) return map;
    throw AccountException(
      statusCode: status,
      code: map['error'] as String? ?? 'http',
      message: map['message'] as String? ?? '请求失败（$status）',
    );
  }

  static String _networkMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return '连接超时';
      case DioExceptionType.connectionError:
        return '无法连接服务器';
      default:
        return '网络错误';
    }
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/account/account_api_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Analyze**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/core/account/account_api.dart test/core/account/account_api_test.dart
git commit -m "feat(account): add the account API client"
```

---

### Task 3: `AccountNotifier` + `accountProvider`

**Files:**
- Create: `lib/core/account/account_service.dart`
- Test: `test/core/account/account_service_test.dart`

**Interfaces:**
- Consumes: `AccountApi`/`AccountException`, `AccountUser`/`AuthSession` (Tasks 1–2); `AppDatabase`.
- Produces: `class AccountState { final String baseUrl; final AccountUser? user; final bool loading; final String? error; bool get isLoggedIn; }`; `class AccountNotifier extends Notifier<AccountState> { AccountNotifier({AccountApi Function(String)? apiFactory}); Future<void> load(); Future<void> setBaseUrl(String); Future<void> register(String, String); Future<void> login(String, String); Future<void> logout(); String? get token; Future<bool> refreshSession(); }`; `final accountProvider`; `const kDefaultBaseUrl`.

- [ ] **Step 1: Write the failing test**

Create `test/core/account/account_service_test.dart`:

```dart
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
    if (!refreshOk) throw const AccountException(code: 'unauthorized', message: 'expired');
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
}

class _FailingLoginApi extends _FakeApi {
  @override
  Future<AuthSession> login(String username, String password) async {
    throw const AccountException(
        statusCode: 401, code: 'unauthorized', message: '用户名或密码错误');
  }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/account/account_service_test.dart`
Expected: FAIL — `account_service.dart` not found.

- [ ] **Step 3: Create `lib/core/account/account_service.dart`**

```dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/database.dart';
import 'account_api.dart';
import 'account_models.dart';

const kDefaultBaseUrl = 'http://127.0.0.1:8080';
const _kBaseUrl = 'account_base_url';
const _kToken = 'account_token';
const _kRefreshToken = 'account_refresh_token';
const _kUser = 'account_user';

class AccountState {
  final String baseUrl;
  final AccountUser? user;
  final bool loading;
  final String? error;

  const AccountState({
    required this.baseUrl,
    this.user,
    this.loading = false,
    this.error,
  });

  bool get isLoggedIn => user != null;

  AccountState copyWith({
    String? baseUrl,
    AccountUser? user,
    bool? loading,
    String? error,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AccountState(
      baseUrl: baseUrl ?? this.baseUrl,
      user: clearUser ? null : (user ?? this.user),
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AccountNotifier extends Notifier<AccountState> {
  AccountNotifier({AccountApi Function(String baseUrl)? apiFactory})
      : _apiFactory = apiFactory ?? ((baseUrl) => AccountApi(baseUrl));

  final AccountApi Function(String baseUrl) _apiFactory;

  @override
  AccountState build() {
    final db = AppDatabase();
    AccountUser? user;
    final userJson = db.getString(_kUser);
    if (userJson != null) {
      try {
        user = AccountUser.fromJson(
            json.decode(userJson) as Map<String, dynamic>);
      } catch (_) {
        user = null;
      }
    }
    return AccountState(
      baseUrl: db.getString(_kBaseUrl) ?? kDefaultBaseUrl,
      user: user,
    );
  }

  String? get token => AppDatabase().getString(_kToken);

  Future<void> setBaseUrl(String url) async {
    final normalized = url.trim().replaceAll(RegExp(r'/+$'), '');
    await AppDatabase().setString(_kBaseUrl, normalized);
    state = state.copyWith(baseUrl: normalized);
  }

  Future<void> register(String username, String password) =>
      _authenticate((api) => api.register(username, password));

  Future<void> login(String username, String password) =>
      _authenticate((api) => api.login(username, password));

  Future<void> _authenticate(
      Future<AuthSession> Function(AccountApi api) call) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final session = await call(_apiFactory(state.baseUrl));
      final db = AppDatabase();
      await db.setString(_kToken, session.token);
      await db.setString(_kRefreshToken, session.refreshToken);
      await db.setString(_kUser, json.encode(session.user.toJson()));
      state = state.copyWith(
          loading: false, user: session.user, clearError: true);
    } on AccountException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    } catch (_) {
      state = state.copyWith(loading: false, error: '登录失败，请重试');
    }
  }

  Future<void> logout() async {
    final db = AppDatabase();
    await db.remove(_kToken);
    await db.remove(_kRefreshToken);
    await db.remove(_kUser);
    state = state.copyWith(clearUser: true, clearError: true);
  }

  Future<bool> refreshSession() async {
    final db = AppDatabase();
    final refreshToken = db.getString(_kRefreshToken);
    if (refreshToken == null) {
      await logout();
      return false;
    }
    try {
      final newToken = await _apiFactory(state.baseUrl).refresh(refreshToken);
      await db.setString(_kToken, newToken);
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  Future<void> load() async {
    final db = AppDatabase();
    final storedToken = db.getString(_kToken);
    if (storedToken == null) return;

    state = state.copyWith(loading: true, clearError: true);
    try {
      final user = await _apiFactory(state.baseUrl).me(storedToken);
      await db.setString(_kUser, json.encode(user.toJson()));
      state = state.copyWith(loading: false, user: user);
      return;
    } on AccountException catch (e) {
      if (e.statusCode != 401) {
        state = state.copyWith(loading: false);
        return;
      }
    } catch (_) {
      state = state.copyWith(loading: false);
      return;
    }

    if (await refreshSession()) {
      final refreshed = token;
      if (refreshed != null) {
        try {
          final user = await _apiFactory(state.baseUrl).me(refreshed);
          await db.setString(_kUser, json.encode(user.toJson()));
          state = state.copyWith(loading: false, user: user);
          return;
        } catch (_) {}
      }
    }
    state = state.copyWith(loading: false);
  }
}

final accountProvider =
    NotifierProvider<AccountNotifier, AccountState>(() => AccountNotifier());
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/account/account_service_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Analyze**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/core/account/account_service.dart test/core/account/account_service_test.dart
git commit -m "feat(account): add the account session service and provider"
```

---

### Task 4: Settings account section + startup load

**Files:**
- Modify: `lib/shell/settings_page.dart`
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `accountProvider`, `AccountState` (Task 3).
- Produces: the 账号 UI; `main()` triggers `load()`.

- [ ] **Step 1: Rewrite `lib/shell/settings_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/account/account_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          const _SectionHeader(title: '账号'),
          const _AccountSection(),
          const Divider(),
          const _SectionHeader(title: '缓存'),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('清除图片缓存'),
            onTap: () async {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('缓存已清除')),
                );
              }
            },
          ),
          const Divider(),
          const _SectionHeader(title: '关于'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('ACGNhub'),
            subtitle: Text('v0.1.0 - 动漫聚合应用'),
          ),
        ],
      ),
    );
  }
}

class _AccountSection extends ConsumerStatefulWidget {
  const _AccountSection();

  @override
  ConsumerState<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends ConsumerState<_AccountSection> {
  final _baseUrl = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _seeded = false;

  @override
  void dispose() {
    _baseUrl.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountProvider);
    if (!_seeded) {
      _baseUrl.text = state.baseUrl;
      _seeded = true;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _baseUrl,
            decoration: const InputDecoration(
              labelText: '服务器地址',
              hintText: kDefaultBaseUrl,
              isDense: true,
            ),
            onSubmitted: (value) =>
                ref.read(accountProvider.notifier).setBaseUrl(value),
          ),
          const SizedBox(height: 14),
          if (state.isLoggedIn) _loggedIn(state) else _loggedOut(state),
        ],
      ),
    );
  }

  Widget _loggedIn(AccountState state) {
    return Row(
      children: [
        const Icon(Icons.account_circle_rounded,
            size: 30, color: Color(0xFF007AFF)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(state.user!.username,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              const Text('已登录',
                  style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
            ],
          ),
        ),
        TextButton(
          onPressed: () => ref.read(accountProvider.notifier).logout(),
          child: const Text('退出登录'),
        ),
      ],
    );
  }

  Widget _loggedOut(AccountState state) {
    final canSubmit = !state.loading &&
        _username.text.trim().isNotEmpty &&
        _password.text.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _username,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: '用户名', isDense: true),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _password,
          obscureText: true,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: '密码', isDense: true),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              onPressed: canSubmit ? () => _submit(login: true) : null,
              child: const Text('登录'),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              onPressed: canSubmit ? () => _submit(login: false) : null,
              child: const Text('注册'),
            ),
            const SizedBox(width: 12),
            if (state.loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(state.error!,
                style: const TextStyle(
                    fontSize: 13, color: Colors.redAccent)),
          ),
      ],
    );
  }

  void _submit({required bool login}) {
    final username = _username.text.trim();
    final password = _password.text;
    if (username.isEmpty || password.isEmpty) return;
    final notifier = ref.read(accountProvider.notifier);
    if (login) {
      notifier.login(username, password);
    } else {
      notifier.register(username, password);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Wire `load()` into `lib/main.dart`**

Add imports:

```dart
import 'dart:async';
import 'core/account/account_service.dart';
```

In `main()`, after `await AppDatabase.init();`:

```dart
  final container = ProviderContainer();
  unawaited(container.read(accountProvider.notifier).load());
```

and change the final `runApp` line to:

```dart
  runApp(UncontrolledProviderScope(
      container: container, child: const ACGNhubApp()));
```

- [ ] **Step 3: Analyze and test**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: all tests pass.

- [ ] **Step 4: Build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug`
Expected: `Built build\windows\x64\runner\Debug\acgnhub.exe`

- [ ] **Step 5: Commit**

```bash
git add lib/shell/settings_page.dart lib/main.dart
git commit -m "feat(account): add the settings account section and startup session load"
```

---

### Task 5: Final verification

**Files:** none (verification only).

- [ ] **Step 1: Analyze and test**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → all pass.

- [ ] **Step 2: Build and manual smoke (with the backend running)**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug`, launch the app, open 设置, and with the backend running locally (`cd server; $env:ACGHUB_JWT_SECRET="dev-secret"; dart run bin/server.dart`) register a new account, then log out and log back in. Expected: the 账号 section shows the username after register/login, 退出登录 returns to the form, and a wrong password shows the backend's message inline.

- [ ] **Step 3: Record the observed result**

Write the outcome (including any issue) into the task report.

---

## Self-Review

- **Spec coverage:** §3 models → Task 1; `AccountApi`/`AccountException` → Task 2; `AccountState`/`AccountNotifier`/`accountProvider`, persistence keys, `load`/`refreshSession`/`token` → Task 3; §4 settings UI + §7 `main.dart` → Task 4; §6 tests → Tasks 1–3, 5.
- **Placeholders:** none — every step has complete code or an exact command.
- **Type consistency:** `AccountUser{id, username}`, `AuthSession{token, refreshToken, user}`, `AccountException{statusCode, code, message}`, `AccountApi(baseUrl, {dio})` with `register/login/refresh/me`, `AccountState{baseUrl, user, loading, error}` + `isLoggedIn`, `AccountNotifier({apiFactory})` with `load/setBaseUrl/register/login/logout/token/refreshSession`, `kDefaultBaseUrl` — used consistently across tasks.
