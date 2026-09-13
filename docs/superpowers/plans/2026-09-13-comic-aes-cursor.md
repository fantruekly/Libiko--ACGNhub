# Comic AES + Cursor Paging Implementation Plan (C2d)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add AES-ECB decryption and `loadNext` cursor paging to the comic engine, then import 禁漫 (jm) and ehentai.

**Architecture:** A new pure AES helper (`lib/core/comic/crypto_util.dart`) is exposed to JS as `Convert.decryptAesEcb`; the source-section metadata gains `usesLoadNext`, and the explore provider chains cursors for `loadNext`-only sections.

**Tech Stack:** Flutter 3.35, Dart 3, Riverpod 2, `pointycastle` (new), `flutter_qjs` (native QuickJS; not runnable under `flutter test`).

## Global Constraints

- Engine in `lib/core/comic/`; UI/providers in `lib/modules/comic/`.
- No code comments unless the surrounding file already has them.
- Any provider calling the C1 engine must catch/surface errors, never an unhandled exception.
- The engine cannot run under `flutter test`; verification is `flutter analyze`, `flutter build windows --debug`, and app-level probes.
- Flutter commands run with `$env:Path = "C:\flutter\bin;$env:Path";` prefixed. Commit after every task and push to `origin/dev`.

---

### Task 1: AES-ECB decryption

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/core/comic/crypto_util.dart`
- Test: `test/core/comic/crypto_util_test.dart`
- Modify: `assets/comic_source/init.js`
- Modify: `lib/core/comic/js_engine.dart`

**Interfaces:**
- Produces: `Uint8List aesEcbDecrypt(List<int> data, List<int> key)`; JS `Convert.decryptAesEcb(data, key)` → bridge `{method:'convert', type:'aesEcbDecrypt', data, key}`.

- [ ] **Step 1: Add the `pointycastle` dependency**

In `pubspec.yaml`, under `dependencies:` next to `crypto:` and `fast_gbk:`, add:

```yaml
  pointycastle: ^3.9.1
```

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter pub get`

- [ ] **Step 2: Write the failing test**

Create `test/core/comic/crypto_util_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/comic/crypto_util.dart';

List<int> _hex(String s) => [
      for (var i = 0; i < s.length; i += 2)
        int.parse(s.substring(i, i + 2), radix: 16)
    ];

void main() {
  test('aesEcbDecrypt decrypts a known AES-256-ECB/PKCS7 vector', () {
    final key = List<int>.generate(32, (i) => i);
    final cipher = _hex(
        'f9decd47c8e1eb0e30883ecb87144c2b2cc90868386a7fd66d3c86b0dd9021f3');
    final plain = aesEcbDecrypt(cipher, key);
    expect(String.fromCharCodes(plain), '{"hello":"world"}');
  });
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/comic/crypto_util_test.dart`
Expected: FAIL — `crypto_util.dart` not found.

- [ ] **Step 4: Create `lib/core/comic/crypto_util.dart`**

```dart
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// AES-ECB decryption with PKCS7 padding (Venera's `Convert.decryptAesEcb`).
Uint8List aesEcbDecrypt(List<int> data, List<int> key) {
  final cipher =
      PaddedBlockCipherImpl(PKCS7Padding(), ECBBlockCipher(AESEngine()));
  cipher.init(
      false,
      PaddedBlockCipherParameters<CipherParameters, CipherParameters>(
          KeyParameter(Uint8List.fromList(key)), null));
  return cipher.process(Uint8List.fromList(data));
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/comic/crypto_util_test.dart`
Expected: PASS (1 test).

- [ ] **Step 6: Expose `decryptAesEcb` in the JS shim**

In `assets/comic_source/init.js`, inside `class Convert`, add after `hmacString(...)`:

```js
    static decryptAesEcb(data, key) {
      return call({ method: 'convert', type: 'aesEcbDecrypt', data: data, key: key });
    }
```

- [ ] **Step 7: Handle the bridge type in `js_engine.dart`**

Add the import at the top of `lib/core/comic/js_engine.dart`:

```dart
import 'crypto_util.dart';
```

In `_convert`, add a case before `default:`:

```dart
      case 'aesEcbDecrypt':
        return aesEcbDecrypt(_bytes(map['data']), _bytes(map['key']));
```

- [ ] **Step 8: Analyze and build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug` → built.

- [ ] **Step 9: Commit and push**

```bash
git add pubspec.yaml pubspec.lock lib/core/comic/crypto_util.dart test/core/comic/crypto_util_test.dart assets/comic_source/init.js lib/core/comic/js_engine.dart
git commit -m "feat(comic): add AES-ECB decryption for comic sources"
git push
```

---

### Task 2: `loadNext` cursor paging

**Files:**
- Modify: `lib/core/comic/comic_source.dart`
- Modify: `lib/modules/comic/comic_providers.dart`

**Interfaces:**
- Consumes: `ExplorePage.next` (C2c), `ComicSourceManager.explore(..., {cursor})` (C2c).
- Produces: `ComicSourceSection` gains `final bool usesLoadNext;`; the provider gains a cursor-paged branch.

- [ ] **Step 1: Add `usesLoadNext` to the section model**

In `lib/core/comic/comic_source.dart`, add the field and constructor parameter to `ComicSourceSection`:

```dart
class ComicSourceSection {
  final String title;
  final String type;
  final bool usesLoadNext;

  const ComicSourceSection(
      {required this.title, required this.type, this.usesLoadNext = false});
}
```

In `_sectionsFrom`, parse it:

```dart
        .map((e) => ComicSourceSection(
              title: e['title']?.toString() ?? '',
              type: e['type']?.toString() ?? '',
              usesLoadNext: e['usesLoadNext'] == true,
            ))
```

In the `_registryJs` pass-2 `finish` `sections` map, add the flag:

```js
      sections: (Array.isArray(s.explore) ? s.explore : []).map(function (e) {
        return {
          title: e.title || '',
          type: e.type || '',
          usesLoadNext: typeof e.loadNext === 'function'
        };
      })
```

- [ ] **Step 2: Add the cursor branch to `comicExploreProvider`**

In `lib/modules/comic/comic_providers.dart`, replace the section-type resolution and add the cursor branch before the `multiPageComicList` branch:

```dart
  final sectionMeta = section >= 0 && section < source.sections.length
      ? source.sections[section]
      : null;
  final type = sectionMeta?.type ?? '';
  if (sectionMeta?.usesLoadNext == true) {
    final cursor = page <= 1
        ? null
        : (await ref.watch(
                comicExploreProvider((sourceKey, section, page - 1)).future))
            .next;
    final result =
        await manager.explore(source, section, page: page, cursor: cursor);
    return ComicExplorePage(
      comics: result.comics,
      page: page,
      maxPage: null,
      hasNext: result.next != null,
      serverPaged: true,
    );
  }
  if (type == 'multiPageComicList') {
```

(The existing `multiPageComicList` and client-paged branches stay as they are; the old `final type = ...` line is replaced by the two lines above.)

- [ ] **Step 3: Analyze and build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug` → built.

- [ ] **Step 4: Commit and push**

```bash
git add lib/core/comic/comic_source.dart lib/modules/comic/comic_providers.dart
git commit -m "feat(comic): page loadNext-based explore sections by cursor"
git push
```

---

### Task 3: Import and verify jm + ehentai

**Files:**
- No source changes; operates on `<app support>/comic_source/*.js` and runs the probes.

- [ ] **Step 1: Copy the two sources into the app source directory**

```powershell
$src = "C:\Users\26568\AppData\Roaming\com.github.wgh136\venera\comic_source"
$dst = "C:\Users\26568\AppData\Roaming\com.acgnhub\acgnhub\comic_source"
Copy-Item -LiteralPath (Join-Path $src 'jm.js') -Destination (Join-Path $dst 'jm.js') -Force
Copy-Item -LiteralPath (Join-Path $src 'ehentai.js') -Destination (Join-Path $dst 'ehentai.js') -Force
```

- [ ] **Step 2: Run the explore probe (sections × pages)**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter run -d windows -t .superpowers/sdd/comic_explore_probe.dart 2>&1 | Tee-Object -FilePath ".superpowers\sdd\explore_probe5.log"`

Expected: `jm` reports its section; `ehentai` reports two sections (`eh latest`, `eh popular`) with `maxPage=null`; if the network allows, page 2's count/content differs from page 1 (cursor advanced). Record the table.

- [ ] **Step 3: Run the search probe**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter run -d windows -t .superpowers/sdd/comic_venera_probe.dart 2>&1 | Tee-Object -FilePath ".superpowers\sdd\venera_probe5.log"`

Expected: `jm` and `ehentai` search either return a count or a site/network error (record which). A `decryptAesEcb`/`aesEcbDecrypt` error would indicate an AES problem — there should be none.

- [ ] **Step 4: Keep the sources that loaded, rebuild the real app, and smoke-test**

Launch `build\windows\x64\runner\Debug\acgnhub.exe`; open 漫画 → 发现; select ehentai and confirm the two section chips and that 下一页 advances (第 X 页); select 禁漫 and confirm its section loads. Record the outcome.

- [ ] **Step 5: Report**

Record which of jm/ehentai loaded and searched, and the per-section/page probe table. No commit is needed (no source changes); if a source was removed, note it.

---

## Self-Review

- **Spec coverage:** §4 AES → Task 1 (pubspec, `crypto_util`, test, `init.js`, `js_engine`); §5 cursor paging → Task 2 (`usesLoadNext` metadata + provider branch); §6 import/verify → Task 3; §8 tests → Task 1 + probes. §10 out-of-scope items (login, picacg, encryptAesEcb) appear in no task.
- **Placeholders:** none; every step shows the code.
- **Type consistency:** `aesEcbDecrypt(List<int>, List<int>) → Uint8List`; `Convert.decryptAesEcb(data, key)` → `{type:'aesEcbDecrypt'}`; `ComicSourceSection.usesLoadNext` produced in Task 2 and read by the provider in Task 2; the cursor branch reuses the existing `(String, int, int)` family key and `ExplorePage.next`.
