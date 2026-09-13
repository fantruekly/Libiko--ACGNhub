# Comic AES + Cursor Paging — Design (Sub-project C2d)

> Date: 2026-09-13
> Status: Approved (design)
> Scope: the engine additions needed to run 禁漫 (jm) and ehentai without account login — AES-ECB decryption and `loadNext` cursor paging — plus importing those two sources. Account login and 哔咔 (picacg) are the separate sub-project C2e.

## 1. Goal

1. Let 禁漫 (jm) run by implementing `Convert.decryptAesEcb(data, key)` (AES-ECB + PKCS7), which its `convertData` helper uses to decrypt API responses.
2. Let ehentai's explore sections (which use `loadNext(next)` instead of `load(page)`) paginate via a cursor.
3. Import both sources and verify their sections/search in-app.

## 2. Background

- The C1 engine re-implements the Venera API subset. `Convert` currently lacks AES (C1 deferred it), and `ComicSourceManager.explore` already supports `sec.loadNext(cursor)` but no provider ever supplies a cursor, so a `loadNext`-only section returns the same first page forever.
- jm (`jm.js:229-238`): `key = Convert.encodeUtf8(Convert.hexEncode(Convert.md5(Convert.encodeUtf8(secret))))` (a 32-byte ASCII key), `data = Convert.decodeBase64(input)`, `Convert.decryptAesEcb(data, key)` → bytes → `Convert.decodeUtf8`. AES-256-ECB, PKCS7. Only decrypt is used across all sources (`grep` confirms no `encryptAesEcb`).
- ehentai (`ehentai.js:359-382`): two sections `eh latest` / `eh popular`, each `type: "multiPageComicList"`, each `loadNext(next) => this.getGalleries(next ?? <url>, false)`. `getGalleries` (`:193-355`) returns `{ comics, next }` where `next` is the `href` of `a#dnext` (absent on the last page). Its `baseUrl` is `'https://' + loadSetting("domain")` with a `settings.domain` default of `e-hentai.org` — browsable without login.
- `pubspec.yaml` already has `crypto` and `fast_gbk` but **not** `pointycastle` (C1 deferred it with AES).
- The engine cannot run under `flutter test`; verification is `flutter analyze`, `flutter build windows --debug`, and app-level probes.

## 3. Architecture

| File | Change |
|---|---|
| `pubspec.yaml` | Add `pointycastle`. |
| `lib/core/comic/crypto_util.dart` (new) | Pure `Uint8List aesEcbDecrypt(List<int> data, List<int> key)` (AES-ECB + PKCS7). Unit-tested. |
| `assets/comic_source/init.js` | Add `Convert.decryptAesEcb(data, key)`. |
| `lib/core/comic/js_engine.dart` | `_convert` handles `type: 'aesEcbDecrypt'` via `crypto_util`. |
| `lib/core/comic/comic_source.dart` | `ComicSourceSection` gains `usesLoadNext`; registry + `fromMetadata` read it. |
| `lib/modules/comic/comic_providers.dart` | `comicExploreProvider` gains a cursor-paged branch for `usesLoadNext` sections. |

## 4. AES-ECB decrypt

`lib/core/comic/crypto_util.dart`:

```dart
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

Uint8List aesEcbDecrypt(List<int> data, List<int> key) {
  final cipher = PaddedBlockCipherImpl(
      PKCS7Padding(), ECBBlockCipher(AESEngine()));
  cipher.init(
      false,
      PaddedBlockCipherParameters<CipherParameters, CipherParameters>(
          KeyParameter(Uint8List.fromList(key)), null));
  return cipher.process(Uint8List.fromList(data));
}
```

`init.js` (inside `class Convert`):

```js
    static decryptAesEcb(data, key) {
      return call({ method: 'convert', type: 'aesEcbDecrypt', data: data, key: key });
    }
```

`js_engine.dart` `_convert` gains a case:

```dart
      case 'aesEcbDecrypt':
        return aesEcbDecrypt(_bytes(map['data']), _bytes(map['key']));
```

with `import 'crypto_util.dart';` (or the fully-qualified call).

## 5. Cursor paging

`ComicSourceSection` gains `final bool usesLoadNext;` (default `false`). The registry pass-2 `sections` map sets `usesLoadNext: typeof e.loadNext === 'function' && typeof e.load !== 'function'` (true only when the section has a `loadNext` and no `load`, since `loadNext` is ignored when `load` is implemented); `fromMetadata` parses it.

`comicExploreProvider`'s server branch becomes three-way:
- `usesLoadNext` → cursor-paged: for page `N`, obtain the cursor from page `N-1`'s result (`page == 1 ? null : (await ref.watch(comicExploreProvider((sourceKey, section, N-1)).future)).next`), call `manager.explore(source, section, page: N, cursor: cursor)`, return `maxPage: null`, `hasNext: result.next != null`.
- else `type == 'multiPageComicList'` → page-paged (unchanged).
- else → client-paged (unchanged).

## 6. Import and verify

Copy `jm.js` and `ehentai.js` into the app source directory; run the explore probe (sections × pages) and a search probe; record which sections/search work. ehentai should show two sections and page 2 should differ from page 1 (cursor advanced).

## 7. Error Handling

- A jm/ehentai network/site failure surfaces as the provider's error state (existing 重试 path).
- An AES failure throws inside `_convert`; the JS `Convert` bridge propagates it and the source may catch it. Never an unhandled Dart exception.

## 8. Testing

- `test/core/comic/crypto_util_test.dart`: `aesEcbDecrypt` against the known vector — key `000102…1f` (32 bytes), plaintext `{"hello":"world"}`, ciphertext `f9decd47c8e1eb0e30883ecb87144c2b2cc90868386a7fd66d3c86b0dd9021f3` — and a wrong-key/`FormatException` case is not required (ECB decrypt of garbage yields garbage; no throw expected).
- Probe: jm + ehentai explore sections/pages and search.
- `flutter analyze lib test`, `flutter test`, `flutter build windows --debug`.

## 9. Files

**New**
- `lib/core/comic/crypto_util.dart`
- `test/core/comic/crypto_util_test.dart`

**Modified**
- `pubspec.yaml`
- `assets/comic_source/init.js`
- `lib/core/comic/js_engine.dart`
- `lib/core/comic/comic_source.dart`
- `lib/modules/comic/comic_providers.dart`

## 10. Out of Scope

- Account login (form/WebView) and 哔咔 (picacg) — C2e.
- AES encryption (`encryptAesEcb`); no source uses it.
- ehentai login/`loginWithCookies`/`loginWithWebview`; only the anonymous sections are targeted.
- `mixed` section semantics (nhentai) and the reader (C2b, done).
