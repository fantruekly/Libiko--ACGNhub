# Comic Account Login — Design (Sub-project C2e)

> Date: 2026-09-13
> Status: Approved (design)
> Scope: form login (哔咔) and cookie login (ehentai) for comic sources — engine support, a per-source login dialog in 源管理, and importing 哔咔. WebView login and ehentai search options are out of scope.

## 1. Goal

Let the user sign in to sources that require an account so their browse/search works: 哔咔 (form login: email + password) and ehentai (cookie login: 4 fields). The 源管理 page gets a 账号 action per source that opens the right dialog and shows login status.

## 2. Background

- 哔咔 (`picacg.js`): `account.login(email, password)` POSTs `/auth/sign-in`, saves the token via `this.saveData('token', ...)`; `account.logout()` deletes it; browse methods guard on `this.isLogged`. `isLogged` is **not** defined by the source — Venera's `ComicSource` base provides it.
- ehentai (`ehentai.js`): `account.loginWithCookies = { fields: ['ipb_member_id','ipb_pass_hash','igneous','star'], validate(values) → Promise<boolean> }` builds `new Cookie({name, value, domain})` objects and sets them via `Network.setCookies`; `account.logout()` clears cookies. There is also `loginWithWebview` (out of scope).
- `new Cookie` is a Venera global used by baozi/ehentai/ikmmh; our engine does not define it, and the cookie bridge stores the raw `setCookies` argument, which for an array of Cookie objects does not serialize to a `Cookie` header.
- The engine cannot run under `flutter test`; verification is `flutter analyze`, `flutter build windows --debug`, and app-level probes. Login itself needs real credentials, so it is verified manually by the user.

## 3. Architecture

| File | Change |
|---|---|
| `assets/comic_source/init.js` | Add a `Cookie` class/global; add a base `ComicSource.isLogged` getter. |
| `lib/core/comic/js_engine.dart` | Serialize cookie objects into the `Cookie` request header. |
| `lib/core/comic/comic_source.dart` | `ComicSource` gains `hasLogin`/`hasCookieLogin`/`cookieFields`; the registry returns `account` metadata; `ComicSourceManager` gains `login`/`loginWithCookies`/`logout`/`isLogged`. |
| `lib/modules/comic/comic_source_page.dart` | A 账号 `PopupMenuButton` item + a login dialog. |

## 4. Engine

### 4.1 `Cookie` global and `isLogged`

In `assets/comic_source/init.js`:

```js
  class Cookie {
    constructor({ name, value, domain, path } = {}) {
      this.name = name || ''; this.value = value || '';
      this.domain = domain || ''; this.path = path || '/';
    }
  }
  globalThis.Cookie = Cookie;
```

and on `class ComicSource`:

```js
    get isLogged() {
      const token = this.loadData('token');
      const account = this.loadData('account');
      return (token !== null && token !== undefined && token !== '') ||
             (account !== null && account !== undefined);
    }
```

### 4.2 Cookie serialization

`JsEngine._cookieHeaderFor` currently joins `entry.value?.toString()`. Make it handle a list of cookie objects:

```dart
for (final entry in _cookieJar.entries) {
  ...
  final value = entry.value;
  if (value is List) {
    for (final c in value) {
      if (c is Map) {
        final name = c['name']?.toString() ?? '';
        final v = c['value']?.toString() ?? '';
        if (name.isNotEmpty) values.add('$name=$v');
      }
    }
  } else {
    final s = value?.toString();
    if (s != null && s.isNotEmpty) values.add(s);
  }
}
```

`_cookie`'s set op stores the value as-is (already does).

### 4.3 Account metadata

`ComicSource` gains `bool hasLogin`, `bool hasCookieLogin`, `List<String> cookieFields`. The registry pass-2 `finish` object adds:

```js
      account: (function () {
        const a = s.account;
        const cw = a && a.loginWithCookies;
        return {
          hasLogin: !!(a && typeof a.login === 'function'),
          hasCookieLogin: !!(cw && typeof cw.validate === 'function'),
          cookieFields: cw && Array.isArray(cw.fields) ? cw.fields.map(String) : []
        };
      })()
```

`fromMetadata` parses it.

### 4.4 Manager methods

```dart
Future<bool> login(ComicSource source, String username, String password);
Future<bool> loginWithCookies(ComicSource source, List<String> values);
Future<void> logout(ComicSource source);
Future<bool> isLogged(ComicSource source);
```

- `login`: evaluate `s.account.login(u, p)` (returns any value on success; throws on failure) → return true, else false.
- `loginWithCookies`: evaluate `await s.account.loginWithCookies.validate(values)` → the boolean; on true, persist a `source_data.<key>.logged_in` flag.
- `logout`: evaluate `s.account.logout()` if present; clear the flag.
- `isLogged`: evaluate `!!s.isLogged`; if false and `source.hasCookieLogin`, fall back to the persisted `source_data.<key>.logged_in` flag.

## 5. UI (`comic_source_page.dart`)

For each source whose `hasLogin || hasCookieLogin` is true, the existing `PopupMenuButton` gains a `账号` item (before 刷新/删除). It opens a dialog:

- Title: the source name; subtitle: the current status (`已登录` / `未登录`).
- Form (`hasLogin`): two `TextField`s (账号/邮箱, 密码, obscured) + a 登录 `FilledButton`.
- Cookie (`hasCookieLogin`): one `TextField` per `source.cookieFields` + a 登录 `FilledButton`.
- When logged in: a 退出登录 `TextButton`.
- On submit: call `manager.login`/`loginWithCookies`; show a `SnackBar` (`已登录`/`登录失败`) and refresh the status. On 退出: call `manager.logout`.

The dialog is a `StatefulWidget` (or uses `StatefulBuilder`) to track the in-flight state and re-read `isLogged` after an action.

## 6. Import 哔咔

Copy the upstream `picacg.js` into the app source directory (its `settings.base_url` needs a default; the source provides one). Verify via the account probe that its metadata exposes `hasLogin`.

## 7. Error Handling

- A login call that throws → the dialog shows the error inline / in a `SnackBar`; the app stays logged out.
- A source without an account → no 账号 item.
- Cookie serialization must never throw on a malformed entry.

## 8. Testing

- `test/core/comic/js_engine_test` is unavailable (native engine); the cookie-serialization helper is Dart but private — no unit test.
- `.superpowers/sdd/comic_account_probe.dart`: a `ProviderContainer` probe that prints each source's `hasLogin`/`hasCookieLogin`/`cookieFields` and `isLogged` before login.
- Manual: the user signs in with real credentials and browses 哔咔/ehentai.
- `flutter analyze lib test`, `flutter test`, `flutter build windows --debug`.

## 9. Files

**Modified**
- `assets/comic_source/init.js`
- `lib/core/comic/js_engine.dart`
- `lib/core/comic/comic_source.dart`
- `lib/modules/comic/comic_source_page.dart`

## 10. Out of Scope

- WebView login (`loginWithWebview`) — needs a browser integration.
- ehentai search options (`search.loadNext` + `optionList`).
- Persisting the account password for `reLogin`; a token expiry re-prompts the user.
- Syncing comic accounts with the backend.
