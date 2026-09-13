# Comic Account Login Implementation Plan (C2e)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user sign in to comic sources — form login (哔咔) and cookie login (ehentai) — from a 账号 dialog in 源管理, and import 哔咔.

**Architecture:** The JS shim gains a `Cookie` global and a base `ComicSource.isLogged`; the Dart cookie bridge serializes cookie objects; `ComicSource` exposes account metadata and `ComicSourceManager` gains login/logout/isLogged; `comic_source_page.dart` renders the dialog.

**Tech Stack:** Flutter 3.35, Dart 3, Riverpod 2, `flutter_qjs` (native QuickJS; not runnable under `flutter test`).

## Global Constraints

- Engine in `lib/core/comic/`; UI in `lib/modules/comic/`.
- Cookie serialization must never throw on a malformed entry.
- A source without an account shows no 账号 action.
- No code comments unless the surrounding file already has them.
- Flutter commands run with `$env:Path = "C:\flutter\bin;$env:Path";` prefixed. Commit after every task and push to `origin/dev`.

---

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

### Task 2: Account dialog in 源管理

**Files:**
- Modify: `lib/modules/comic/comic_source_page.dart`

**Interfaces:**
- Consumes: `ComicSource.hasLogin`/`hasCookieLogin`/`cookieFields` and the manager's `login`/`loginWithCookies`/`logout`/`isLogged` (Task 1).

- [ ] **Step 1: Add the 账号 menu item**

In `_sourceTile`'s `PopupMenuButton`, add to `onSelected`:

```dart
            if (value == 'account') _openAccount(source);
```

and to `itemBuilder`, before the 刷新 entry:

```dart
            if (source.hasLogin || source.hasCookieLogin)
              const PopupMenuItem(value: 'account', child: Text('账号')),
```

Add the handler near `_refresh`/`_confirmDelete`:

```dart
  void _openAccount(ComicSource source) {
    showDialog<void>(
      context: context,
      builder: (_) => _AccountDialog(source: source),
    );
  }
```

- [ ] **Step 2: Add the `_AccountDialog` widget**

Append at the end of `comic_source_page.dart`:

```dart
class _AccountDialog extends ConsumerStatefulWidget {
  final ComicSource source;

  const _AccountDialog({required this.source});

  @override
  ConsumerState<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends ConsumerState<_AccountDialog> {
  late final List<TextEditingController> _controllers;
  bool _logged = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final count = widget.source.hasCookieLogin
        ? widget.source.cookieFields.length
        : 2;
    _controllers =
        List.generate(count, (_) => TextEditingController());
    _refreshStatus();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    final logged =
        await ref.read(comicSourceManagerProvider).isLogged(widget.source);
    if (mounted) setState(() => _logged = logged);
  }

  String _label(int index) {
    if (widget.source.hasCookieLogin) {
      return widget.source.cookieFields[index];
    }
    return index == 0 ? '账号 / 邮箱' : '密码';
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final manager = ref.read(comicSourceManagerProvider);
    final bool ok;
    if (widget.source.hasLogin) {
      ok = await manager.login(widget.source, _controllers[0].text.trim(),
          _controllers[1].text);
    } else {
      ok = await manager.loginWithCookies(
          widget.source, _controllers.map((c) => c.text.trim()).toList());
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _logged = ok;
      _error = ok ? null : '登录失败';
    });
  }

  Future<void> _logout() async {
    setState(() => _busy = true);
    await ref.read(comicSourceManagerProvider).logout(widget.source);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _logged = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.source.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_logged ? '已登录' : '未登录',
              style: TextStyle(
                  fontSize: 13,
                  color: _logged
                      ? const Color(0xFF34C759)
                      : const Color(0xFF8E8E93))),
          if (!_logged) ...[
            const SizedBox(height: 12),
            for (var i = 0; i < _controllers.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: _controllers[i],
                  obscureText: widget.source.hasLogin && i == 1,
                  decoration: InputDecoration(
                    labelText: _label(i),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
          ],
          if (_error != null)
            Text(_error!,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFFE81123))),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
        if (_logged)
          TextButton(
            onPressed: _busy ? null : _logout,
            child: const Text('退出登录'),
          )
        else
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: const Text('登录'),
          ),
      ],
    );
  }
}
```

- [ ] **Step 3: Analyze and build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug` → built.

- [ ] **Step 4: Commit and push**

```bash
git add lib/modules/comic/comic_source_page.dart
git commit -m "feat(comic): add the source account dialog"
git push
```

---

### Task 3: Import 哔咔 + account probe

**Files:**
- No source changes; operates on `<app support>/comic_source/picacg.js` and runs a probe.

- [ ] **Step 1: Copy 哔咔 into the app source directory**

```powershell
Copy-Item -LiteralPath "C:\Users\26568\AppData\Roaming\com.github.wgh136\venera\comic_source\picacg.js" -Destination "C:\Users\26568\AppData\Roaming\com.acgnhub\acgnhub\comic_source\picacg.js" -Force
```

(If the upstream is newer, download `https://git.nyne.dev/nyne/venera-configs/raw/branch/main/picacg.js` instead.)

- [ ] **Step 2: Write the account probe**

Create `.superpowers/sdd/comic_account_probe.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:acgnhub/core/storage/database.dart';
import 'package:acgnhub/modules/comic/comic_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProbeApp());
}

class ProbeApp extends StatefulWidget {
  const ProbeApp({super.key});

  @override
  State<ProbeApp> createState() => _ProbeAppState();
}

class _ProbeAppState extends State<ProbeApp> {
  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await AppDatabase.init();
    final container = ProviderContainer();
    try {
      final sources = await container.read(comicSourcesProvider.future);
      final manager = container.read(comicSourceManagerProvider);
      for (final source in sources) {
        if (!source.hasLogin && !source.hasCookieLogin) continue;
        final logged = await manager.isLogged(source);
        print('PROBE ${source.key} hasLogin=${source.hasLogin} '
            'hasCookieLogin=${source.hasCookieLogin} '
            'fields=${source.cookieFields} logged=$logged');
      }
    } catch (e, st) {
      print('PROBE ERROR $e\n$st');
    } finally {
      container.dispose();
    }
    print('PROBE DONE');
    exit(0);
  }

  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: Scaffold(body: Center(child: Text('account probe'))),
      );
}
```

- [ ] **Step 3: Run the probe**

```powershell
$env:Path = "C:\flutter\bin;$env:Path"; flutter run -d windows -t .superpowers/sdd/comic_account_probe.dart 2>&1 | Tee-Object -FilePath ".superpowers\sdd\account_probe.log"
```

Expected: `picacg` shows `hasLogin=true`; `ehentai` shows `hasCookieLogin=true` with `fields=[ipb_member_id, ipb_pass_hash, igneous, star]`; both `logged=false` before signing in. Record the table.

- [ ] **Step 4: Rebuild the real app and smoke-test the dialog**

Launch `build\windows\x64\runner\Debug\acgnhub.exe`, open 漫画 → 源管理; confirm the 账号 menu appears for 哔咔/ehentai and the dialog shows the right fields. (Actual sign-in needs the user's credentials; record that it is left to the human.)

- [ ] **Step 5: Analyze, test, build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → all pass.
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug` → built.

- [ ] **Step 6: Report**

Record picacg/ehentai account metadata and that actual sign-in is left to the human. No commit (no source changes; the probe is untracked scratch).

---

## Self-Review

- **Spec coverage:** §4.1 Cookie/isLogged → Task 1 Step 1; §4.2 cookie serialization → Task 1 Step 2; §4.3 account metadata → Task 1 Steps 3–5; §4.4 manager methods → Task 1 Step 6; §5 UI → Task 2; §6 import → Task 3. §10 out-of-scope items appear in no task.
- **Placeholders:** none; every step shows the code.
- **Type consistency:** `ComicSource.hasLogin/hasCookieLogin/cookieFields` (Task 1) are read by the UI (Task 2); `login`/`loginWithCookies`/`logout`/`isLogged` signatures match between Task 1 and Task 2; the cookie flag key `source_data.<key>.logged_in` is written and read in Task 1.
