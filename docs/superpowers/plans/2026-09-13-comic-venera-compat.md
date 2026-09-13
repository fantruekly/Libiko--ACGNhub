# Venera Source Compatibility Shim Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make real Venera comic sources load and run on the C1 engine by adding the missing API surface (data storage, `Convert` aliases, `randomInt`, `fetch`, and running `init()` on each instance), then import the working main sources into the app.

**Architecture:** The C1 engine already re-implements a renamed subset of the Venera JS API. This plan adds the missing names in three places: the bundled JS shim (`assets/comic_source/init.js`), the Dart bridge (`lib/core/comic/js_engine.dart`), and the source-instance factory (`lib/core/comic/comic_source.dart`). No new files.

**Tech Stack:** Flutter 3.35, Dart 3, `flutter_qjs` (native QuickJS), `crypto`, `dio`, `shared_preferences` (`AppDatabase`).

## Global Constraints

- Scope is the **minimal** compatibility layer: `loadData`/`saveData`, `Convert` aliases (`decodeBase64`/`encodeBase64`/`decodeUtf8`/`encodeUtf8`/`hmacString`), `Network.deleteCookies`, global `randomInt`, global `fetch`, and running `init()` per instance. **AES (`decryptAesEcb`), account/WebView login, `Cache`/`IO`, and `minAppVersion` gating are out of scope** — sources needing them may still fail.
- The engine cannot be exercised by `flutter test` (QuickJS native lib is not loadable there). Verification is `flutter analyze`, `flutter build windows --debug`, and the app-level probe `flutter run -d windows -t .superpowers/sdd/comic_venera_probe.dart`.
- No code comments unless the surrounding file already has them. `init.js` already has comments; `js_engine.dart`/`comic_source.dart` have a few.
- Flutter commands run with `$env:Path = "C:\flutter\bin;$env:Path";` prefixed.
- Commit after the task and push to `origin/dev`.

---

### Task 1: Venera compatibility shim

**Files:**
- Modify: `assets/comic_source/init.js`
- Modify: `lib/core/comic/js_engine.dart`
- Modify: `lib/core/comic/comic_source.dart`
- Verify (no change): `.superpowers/sdd/comic_venera_probe.dart`

**Interfaces:**
- Consumes: the existing `sendMessage` bridge (`http`/`convert`/`html`/`setting`/`cookie`/`log`).
- Produces (JS): `ComicSource.loadData(name)` / `saveData(name, value)`; `Convert.decodeBase64/encodeBase64/decodeUtf8/encodeUtf8/hmacString(key, data, algo)`; `Network.deleteCookies(url)`; `globalThis.randomInt(min, max)`; `globalThis.fetch(url, {method, headers, body})` → `{status, ok, headers, url, text(), json(), arrayBuffer()}`. `__acgnhub_instance(key)` returns a `Promise<instance>` that has run `init()`.

- [ ] **Step 1: Extend the JS shim (`assets/comic_source/init.js`)**

In `class Network`, add after `getCookies(url)`:

```js
    static deleteCookies(url) {
      return call({ method: 'cookie', op: 'set', url: url, cookies: null });
    }
```

In `class Convert`, add after `hmac(data, key)`:

```js
    static decodeBase64(s) { return call({ method: 'convert', type: 'base64Decode', data: s }); }
    static encodeBase64(s) { return call({ method: 'convert', type: 'base64Encode', data: s }); }
    static decodeUtf8(bytes) { return call({ method: 'convert', type: 'utf8', data: bytes }); }
    static encodeUtf8(s) { return call({ method: 'convert', type: 'utf8Encode', data: s }); }
    static hmacString(key, data, algorithm) {
      return call({ method: 'convert', type: 'hmac', key: key, data: data, algo: algorithm });
    }
```

In `class ComicSource`, add after `saveSetting(key, value)`:

```js
    loadData(name) {
      const v = call({ method: 'setting', op: 'get', key: 'source_data.' + this.key + '.' + name });
      return v === null || v === undefined || v === '' ? null : v;
    }
    saveData(name, value) {
      const v = typeof value === 'string' ? value : JSON.stringify(value);
      return call({ method: 'setting', op: 'set', key: 'source_data.' + this.key + '.' + name, value: v });
    }
```

Before the `globalThis.ComicSource = ComicSource;` block at the bottom, add the globals:

```js
  globalThis.randomInt = function (min, max) {
    if (max === undefined) { max = min; min = 0; }
    return Math.floor(Math.random() * (max - min + 1)) + min;
  };

  globalThis.fetch = async function (url, options) {
    options = options || {};
    const method = (options.method || 'GET').toUpperCase();
    const r = Network.sendRequest(method, url, options.headers || {}, options.body, null, false);
    return {
      status: r.status,
      ok: r.status >= 200 && r.status < 300,
      headers: r.headers || {},
      url: url,
      text: async () => r.body,
      json: async () => JSON.parse(r.body),
      arrayBuffer: async () => Convert.encodeUtf8(r.body),
    };
  };
```

- [ ] **Step 2: Extend the Dart bridge (`lib/core/comic/js_engine.dart`)**

In `_bytes`, make it accept a String (utf8) so both string and byte keys work:

```dart
  List<int> _bytes(dynamic data) {
    if (data is String) return utf8.encode(data);
    if (data is List<int>) return data;
    if (data is List) return data.map((e) => (e as num).toInt()).toList();
    if (data is Uint8List) return data;
    throw ArgumentError('expected a byte array, got ${data.runtimeType}');
  }
```

Replace the `case 'hmac':` branch in `_convert` with:

```dart
      case 'hmac':
        final algo = (map['algo']?.toString() ?? 'sha256').toLowerCase();
        final hash = algo == 'sha1'
            ? sha1
            : algo == 'md5'
                ? md5
                : sha256;
        return Hmac(hash, _bytes(map['key']))
            .convert(_bytes(map['data']))
            .toString();
```

In `_setting`, accept the new `source_data.` namespace alongside `source_setting.`:

```dart
    if (!key.startsWith(_settingPrefix) && !key.startsWith(_dataPrefix)) {
      throw Exception('setting key out of scope: $key');
    }
```

and add the constant next to `_settingPrefix`:

```dart
  static const _dataPrefix = 'source_data.';
```

- [ ] **Step 3: Run `init()` when creating a source instance (`lib/core/comic/comic_source.dart`)**

In `_registryJs`, replace `__acgnhub_instance` with an async version that runs `init()`:

```js
globalThis.__acgnhub_instance = function (key) {
  const cls = globalThis.__acgnhub_sources[key];
  if (!cls) throw new Error('comic source not registered: ' + key);
  const s = new cls();
  if (typeof s.init === 'function') {
    return Promise.resolve(s.init()).then(function () { return s; });
  }
  return Promise.resolve(s);
};
```

Update the five capability evaluations to `await` the instance. In `search`:

```dart
    final result = await _engine.evaluate('''
      (async () => {
        const s = await globalThis.__acgnhub_instance(${jsonEncode(source.key)});
        return s.search.load(${jsonEncode(keyword)}, {}, $page);
      })()
    ''');
```

In `explore`:

```dart
    final result = await _engine.evaluate('''
      (async () => {
        const s = await globalThis.__acgnhub_instance(${jsonEncode(source.key)});
        return s.explore[$index].load($page);
      })()
    ''');
```

In `loadInfo`:

```dart
    final result = await _engine.evaluate('''
      (async () => {
        const s = await globalThis.__acgnhub_instance(${jsonEncode(source.key)});
        return s.comic.loadInfo(${jsonEncode(id)});
      })()
    ''');
```

In `loadEp`:

```dart
    final result = await _engine.evaluate('''
      (async () => {
        const s = await globalThis.__acgnhub_instance(${jsonEncode(source.key)});
        return s.comic.loadEp(${jsonEncode(comicId)}, ${jsonEncode(epId)});
      })()
    ''');
```

In `onImageLoad`:

```dart
    final result = await _engine.evaluate('''
      (async () => {
        const s = await globalThis.__acgnhub_instance(${jsonEncode(source.key)});
        return s.comic.onImageLoad(${jsonEncode(url)}, ${jsonEncode(comicId)}, ${jsonEncode(epId)});
      })()
    ''');
```

- [ ] **Step 4: Analyze and build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug` → built.

- [ ] **Step 5: Run the probe to verify the main sources**

Copy the general Venera sources into the app's source directory, run the probe, then remove the copies again (the probe's `load()` only reads the app directory):

```powershell
$src = "C:\Users\26568\AppData\Roaming\com.github.wgh136\venera\comic_source"
$dst = "C:\Users\26568\AppData\Roaming\com.acgnhub\acgnhub\comic_source"
$set = @('copy_manga.js','manhuagui.js','baozi.js','ykmh.js','zaimanhua.js','ikmmh.js','komiic.js','manwaba.js','manga_dex.js','comick.js','shonen_jump_plus.js','copy_manga.data')
foreach ($f in $set) { Copy-Item -LiteralPath (Join-Path $src $f) -Destination (Join-Path $dst $f) -Force }
$env:Path = "C:\flutter\bin;$env:Path"; flutter run -d windows -t .superpowers/sdd/comic_venera_probe.dart 2>&1 | Tee-Object -FilePath ".superpowers\sdd\venera_probe2.log"
```

Expected: more sources load, and `PROBE SEARCH ... count=` (non-error) for the majority. Record the per-source load/search results.

- [ ] **Step 6: Commit and push**

```bash
git add assets/comic_source/init.js lib/core/comic/js_engine.dart lib/core/comic/comic_source.dart
git commit -m "feat(comic): add the Venera source compatibility shim"
git push
```

---

### Task 2: Import the working main sources

**Files:**
- No source changes; operates on `<app support>/comic_source/*.js`.

- [ ] **Step 1: Keep the sources that loaded and searched cleanly**

From Task 1's probe log, retain in the app source directory every source whose `PROBE LOADED` appeared and whose `PROBE SEARCH` did **not** error (count=0 is acceptable — the site simply had no hit for the probe keyword). Remove any that errored.

- [ ] **Step 2: Restart the app and smoke-test**

Launch `build\windows\x64\runner\Debug\acgnhub.exe`; open 漫画; confirm the imported sources appear in 源管理 with their capability chips; search a keyword and open a detail page.

- [ ] **Step 3: Report**

Record which sources were kept and their probe results.

---

## Self-Review

- **Spec coverage:** the discovered gaps map 1:1 — `loadData`/`saveData` (Step 1 JS + Step 2 `source_data.` prefix), `Convert` aliases + `hmacString` (Step 1 JS + Step 2 hmac algo/bytes), `randomInt` (Step 1), `fetch` (Step 1), `Network.deleteCookies` (Step 1), per-instance `init()` (Step 3).
- **Placeholders:** none; every step shows the code.
- **Type consistency:** `hmacString(key, data, algorithm)` → `{type:'hmac', key, data, algo}` → Dart `_convert` reads `map['key']`/`map['data']`/`map['algo']`; `saveData`/`loadData` use `source_data.<key>.<name>` and Dart `_setting` allow-lists `source_data.`.
- **Out of scope:** AES, account/WebView login, `Cache`/`IO`, `minAppVersion` — not implemented.
