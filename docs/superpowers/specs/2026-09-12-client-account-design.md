# Client Account — Design (Sub-project B2)

> Date: 2026-09-12
> Status: Approved (design)
> Scope: the client-side account UI, API client and session storage. The 追番 button and the sync wiring are B3.

## 1. Goal

Let a user register/login against the self-hosted backend (B1) from the settings page, keep the session locally, and expose a usable access token (with automatic refresh) to the rest of the app.

## 2. Background

- `lib/shell/settings_page.dart` is a simple `ListView` with 缓存 / 关于 sections — the account section is added there.
- `lib/core/services/http_client.dart` is a singleton `Dio` configured with a browser User-Agent and HTML `Accept` headers for scraping. The account API must NOT reuse it; it uses its own JSON `Dio`.
- `AppDatabase` (`lib/core/storage/database.dart`) wraps `SharedPreferences` and is already used by `FavoriteManager` / `WatchHistoryManager`.
- The backend (B1) exposes `POST /api/auth/register`, `POST /api/auth/login`, `POST /api/auth/refresh`, `GET /api/me`; errors are `{"error": "<code>", "message": "<text>"}`.

## 3. Architecture

New package folder `lib/core/account/`:

| File | Responsibility |
|---|---|
| `account_models.dart` | `AccountUser`, `AuthSession` (+ JSON) |
| `account_api.dart` | `AccountApi` — HTTP calls + `AccountException` |
| `account_service.dart` | `AccountState`, `AccountNotifier`, `accountProvider` — session persistence + refresh |

**`account_models.dart`**

```dart
class AccountUser {
  final int id;
  final String username;
  const AccountUser({required this.id, required this.username});
  factory AccountUser.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}

class AuthSession {
  final String token;
  final String refreshToken;
  final AccountUser user;
  const AuthSession({required this.token, required this.refreshToken, required this.user});
  factory AuthSession.fromJson(Map<String, dynamic> json);
}
```

**`account_api.dart`**

```dart
class AccountException implements Exception {
  final int? statusCode; // null for a network/timeout failure
  final String code;     // backend `error`, or 'network'
  final String message;
  const AccountException({this.statusCode, required this.code, required this.message});
}

class AccountApi {
  AccountApi(this.baseUrl, {Dio? dio});
  final String baseUrl;
  Future<AuthSession> register(String username, String password);
  Future<AuthSession> login(String username, String password);
  Future<String> refresh(String refreshToken); // returns a new access token
  Future<AccountUser> me(String token);
}
```

- Its `Dio` sets `contentType: application/json`, a 15 s connect/receive timeout, and `validateStatus: (_) => true` so non-2xx responses are mapped rather than thrown by Dio.
- Every response is inspected: 2xx → parse; otherwise throw `AccountException(statusCode: r.statusCode, code: body['error'] ?? 'http', message: body['message'] ?? '...')`. A `DioException` → `AccountException(code: 'network', message: '网络错误')`.
- `baseUrl` is normalised (trailing `/` stripped) and joined with `/api/...`.
- `me`/`register`/`login`/`refresh` send/parse exactly the B1 contract: `register`/`login` → `{token, refreshToken, user:{id, username}}`; `refresh` → `{token}`; `me` → `{id, username}` with `Authorization: Bearer <token>`.

**`account_service.dart`**

```dart
class AccountState {
  final String baseUrl;
  final AccountUser? user;
  final bool loading;
  final String? error;
  const AccountState({required this.baseUrl, this.user, this.loading = false, this.error});
  bool get isLoggedIn => user != null;
  AccountState copyWith({...});
}

class AccountNotifier extends Notifier<AccountState> {
  @override
  AccountState build();                 // reads baseUrl + stored user synchronously
  Future<void> load();                  // validate/refresh the stored token
  Future<void> setBaseUrl(String url);
  Future<void> register(String username, String password);
  Future<void> login(String username, String password);
  Future<void> logout();
  String? get token;                    // the stored access token, or null
  Future<bool> refreshSession();        // refresh; false + logout on failure
}

final accountProvider = NotifierProvider<AccountNotifier, AccountState>(AccountNotifier.new);
```

Persistence keys in `AppDatabase`: `account_base_url`, `account_token`, `account_refresh_token`, `account_user` (the user's JSON). `baseUrl` defaults to `http://127.0.0.1:8080`.

Behaviour:
- `build()` returns the current base URL and, if a stored `account_user` exists, that user — so the UI can render immediately, then `load()` runs (called from `main()` after `AppDatabase.init()`).
- `load()`: if a token exists, call `me(token)`; on success set the user. If it throws with `statusCode == 401`, try `refresh(refreshToken)`; on success store the new token and call `me` again; if either step fails (or there is no refresh token), clear the token + user (base URL is kept).
- `register`/`login`: call the API, persist `token`/`refreshToken`/`user`, set `loading`/`error` around the call; a thrown `AccountException` sets `error` to its `message` and leaves the user logged out.
- `logout()`: clear `token`/`refreshToken`/`user` (keep `baseUrl`).
- `setBaseUrl(url)`: trim, strip a trailing `/`, persist; does not touch the session.
- `ensureToken`-style behaviour is expressed as two explicit members so B3 can control retries: `token` returns the stored access token (or `null` when logged out), and `refreshSession()` exchanges the refresh token for a new access token (persisting it) — returning `true`, or `false` after clearing the session when there is no refresh token or the refresh fails. B3 uses `token` for a request and, on a 401, calls `refreshSession()` once and retries.

## 4. UI — `lib/shell/settings_page.dart`

Convert the page to a `ConsumerWidget` and add an 账号 section above 缓存:

- **服务器地址**: a `TextField` seeded with `state.baseUrl`, saved on submit/focus loss (`setBaseUrl`), with `hintText: 'http://127.0.0.1:8080'`.
- **Logged out**: a username `TextField`, a password `TextField` (`obscureText`), a 登录 `FilledButton` and a 注册 `OutlinedButton` (both disabled while `loading` or when either field is empty); `state.error` shown as red 13 px text below.
- **Logged in**: a `ListTile` with `Icons.account_circle_rounded`, the username as the title and `已登录` as the subtitle, plus a 退出登录 `TextButton`.
- Styling follows the existing page: `_SectionHeader` for the section title, `ListTile`/`TextField` with the app's default themes (accent `#007AFF`).

## 5. Error Handling

- Network/timeout → `AccountException(code: 'network', message: '网络错误')`; the UI shows it inline.
- Backend 4xx/5xx → the backend's `message` (e.g. `用户名已被占用`, `用户名或密码错误`) shown inline.
- An invalid/expired session on startup degrades silently to logged-out (no error banner).
- `setBaseUrl` accepts anything; a malformed URL surfaces as a network error on the next call.

## 6. Testing

- `test/core/account/account_models_test.dart`: `AccountUser`/`AuthSession` JSON round-trips.
- `test/core/account/account_api_test.dart`: inject a fake `HttpClientAdapter` into `AccountApi`'s `Dio` to assert the request path/method/headers/body and the mapping of a 2xx body and of a 4xx error body (code + message + statusCode).
- `test/core/account/account_service_test.dart`: `SharedPreferences.setMockInitialValues({})` + `AppDatabase.init()`, and an injected fake `AccountApi`; cover register/login persisting the session, logout clearing it, `load()` succeeding with a valid token, `load()` refreshing after a 401, and `load()` clearing the session when both fail.
- Re-run `flutter analyze lib test`, `flutter test`, `flutter build windows --debug`.

## 7. Files

**New**
- `lib/core/account/account_models.dart`
- `lib/core/account/account_api.dart`
- `lib/core/account/account_service.dart`
- `test/core/account/account_models_test.dart`
- `test/core/account/account_api_test.dart`
- `test/core/account/account_service_test.dart`

**Modified**
- `lib/shell/settings_page.dart` (account section)
- `lib/main.dart` (call `accountProvider`'s `load()` after `AppDatabase.init()`)

## 8. Out of Scope

- The 追番 button and pushing/pulling follows/history (B3).
- Email, password reset, account deletion, multi-account.
- Encrypting the stored token (it lives in `SharedPreferences`, per the approved decision).
- HTTPS/self-signed-certificate handling beyond Dio's defaults.
