### Task 1: Engine account support

**Files:**
- Modify: `assets/comic_source/init.js`
- Modify: `lib/core/comic/js_engine.dart`
- Modify: `lib/core/comic/comic_source.dart`

**Interfaces:**
- Produces: JS `Cookie` global and `ComicSource.isLogged`; `ComicSource` gains `bool hasLogin`, `bool hasCookieLogin`, `List<String> cookieFields`; `ComicSourceManager.login(source, username, password) → Future<bool>`, `loginWithCookies(source, values) → Future<bool>`, `logout(source) → Future<void>`, `isLogged(source) → Future<bool>`.

- [ ] **Step 1: Add the `Cookie` global and `isLogged` to `init.js`**

In `assets/comic_source/init.js`, add a `Cookie` class near the other globals (e.g. after `class Convert { ... }`):

```js
  class Cookie {
    constructor({ name, value, domain, path } = {}) {
      this.name = name || '';
      this.value = value || '';
      this.domain = domain || '';
      this.path = path || '/';
    }
  }
```

and register it before `globalThis.ComicSource = ComicSource;`:

```js
  globalThis.Cookie = Cookie;
```

Inside `class ComicSource`, add after `saveSetting(key, value)`:

```js
    get isLogged() {
      const token = this.loadData('token');
      const account = this.loadData('account');
      return (token !== null && token !== undefined && token !== '') ||
             (account !== null && account !== undefined);
    }
```

- [ ] **Step 2: Serialize cookie objects in `js_engine.dart`**

In `lib/core/comic/js_engine.dart`, replace the loop body of `_cookieHeaderFor` so a list of cookie objects becomes `name=value` pairs:

```dart
  String? _cookieHeaderFor(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return null;
    final values = <String>[];
    for (final entry in _cookieJar.entries) {
      final key = Uri.tryParse(entry.key.toString());
      if (key == null || key.host != uri.host) continue;
      final value = entry.value;
      if (value is List) {
        for (final cookie in value) {
          if (cookie is Map) {
            final name = cookie['name']?.toString() ?? '';
            final cookieValue = cookie['value']?.toString() ?? '';
            if (name.isNotEmpty) values.add('$name=$cookieValue');
          }
        }
      } else {
        final text = value?.toString();
        if (text != null && text.isNotEmpty) values.add(text);
      }
    }
    return values.isEmpty ? null : values.join('; ');
  }
```

- [ ] **Step 3: Add the account fields to `ComicSource`**

In `lib/core/comic/comic_source.dart`, add to `ComicSource` after `categoryOptions`:

```dart
  final bool hasLogin;
  final bool hasCookieLogin;
  final List<String> cookieFields;
```

and to the constructor:

```dart
    this.hasLogin = false,
    this.hasCookieLogin = false,
    this.cookieFields = const [],
```

- [ ] **Step 4: Parse the account metadata in `fromMetadata`**

In `fromMetadata`, before `return ComicSource(...)`:

```dart
    final account = meta['account'];
```

and in the constructor call add:

```dart
      hasLogin: account is Map && account['hasLogin'] == true,
      hasCookieLogin: account is Map && account['hasCookieLogin'] == true,
      cookieFields: account is Map && account['cookieFields'] is List
          ? (account['cookieFields'] as List).map((e) => e.toString()).toList()
          : const [],
```

- [ ] **Step 5: Return the account metadata from the registry**

In `_registryJs`, inside `__acgnhub_registerSource`'s `finish` return object, add after `category: ...`:

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

- [ ] **Step 6: Add the manager methods**

In `ComicSourceManager`, add after `category`:

```dart
  Future<bool> login(
      ComicSource source, String username, String password) async {
    await _ensureInitialized();
    if (!source.hasLogin) return false;
    try {
      await _engine.evaluate('''
        (async () => {
          const s = await globalThis.__acgnhub_instance(${jsonEncode(source.key)});
          await s.account.login(${jsonEncode(username)}, ${jsonEncode(password)});
          return true;
        })()
      ''');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> loginWithCookies(
      ComicSource source, List<String> values) async {
    await _ensureInitialized();
    if (!source.hasCookieLogin) return false;
    try {
      final ok = await _engine.evaluate('''
        (async () => {
          const s = await globalThis.__acgnhub_instance(${jsonEncode(source.key)});
          return await s.account.loginWithCookies.validate(${jsonEncode(values)});
        })()
      ''');
      if (ok == true) {
        await AppDatabase()
            .setString('source_data.${source.key}.logged_in', '1');
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout(ComicSource source) async {
    await _ensureInitialized();
    try {
      await _engine.evaluate('''
        (async () => {
          const s = await globalThis.__acgnhub_instance(${jsonEncode(source.key)});
          if (s.account && typeof s.account.logout === 'function') {
            await s.account.logout();
          }
          return true;
        })()
      ''');
    } catch (_) {
      // Best-effort logout.
    }
    await AppDatabase().remove('source_data.${source.key}.logged_in');
  }

  Future<bool> isLogged(ComicSource source) async {
    await _ensureInitialized();
    if (!source.hasLogin && source.hasCookieLogin) {
      return AppDatabase()
              .getString('source_data.${source.key}.logged_in') ==
          '1';
    }
    try {
      final result = await _engine.evaluate('''
        (async () => {
          const s = await globalThis.__acgnhub_instance(${jsonEncode(source.key)});
          return !!s.isLogged;
        })()
      ''');
      return result == true;
    } catch (_) {
      return false;
    }
  }
```

(`AppDatabase` is already imported in `comic_source.dart`.)

- [ ] **Step 7: Analyze and build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug` → built.

- [ ] **Step 8: Commit and push**

```bash
git add assets/comic_source/init.js lib/core/comic/js_engine.dart lib/core/comic/comic_source.dart
git commit -m "feat(comic): add account login support to the comic engine"
git push
```

---
