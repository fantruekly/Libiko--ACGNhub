# Task 1 Report: engine account support (C2e)

## What I implemented

Sub-project C2e Task 1, for the ACGNhub Flutter comic module. Added the
JS-side `Cookie` global and `ComicSource.isLogged`, made the Dart cookie bridge
serialize cookie objects, and added account metadata plus manager login methods.

### `assets/comic_source/init.js`

- Added a `Cookie` class (`name`/`value`/`domain`/`path`, defaults `''`/`''`/`''`/`'/'`)
  after `class Convert`.
- Added a `get isLogged()` getter to `class ComicSource` after `saveSetting`:
  true when `loadData('token')` is non-null/non-empty or `loadData('account')`
  is non-null.
- Registered `globalThis.Cookie = Cookie;` before `globalThis.ComicSource`.

### `lib/core/comic/js_engine.dart`

- Rewrote the body of `_cookieHeaderFor`: a jar entry whose value is a `List` is
  expanded into `name=value` pairs (skipping non-`Map` items and empty names);
  any other value falls back to `value?.toString()`. Malformed entries are
  skipped rather than throwing. Values are joined with `'; '`.

### `lib/core/comic/comic_source.dart`

- `ComicSource`: added `hasLogin`, `hasCookieLogin`, `cookieFields` fields and
  constructor defaults (`false`, `false`, `const []`).
- `fromMetadata`: reads `meta['account']` and maps it to the three fields
  (`cookieFields` coerced with `.map((e) => e.toString())`).
- `_registryJs`: the `__acgnhub_registerSource` return object now includes an
  `account` block derived from `s.account` / `s.account.loginWithCookies`
  (`hasLogin`, `hasCookieLogin`, `cookieFields`).
- `ComicSourceManager`: added `login`, `loginWithCookies`, `logout`, `isLogged`
  after `category`. Form login evaluates `s.account.login`; cookie login
  evaluates `s.account.loginWithCookies.validate(values)` and persists a
  `source_data.<key>.logged_in` flag via `AppDatabase`; logout best-effort calls
  `s.account.logout()` and removes the flag; `isLogged` reads the flag for
  cookie-only sources and otherwise evaluates `!!s.isLogged`.

## Verification commands and results

- `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
  - `No issues found! (ran in 2.2s)`
- `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug`
  - `√ Built build\windows\x64\runner\Debug\acgnhub.exe` (11.2s). Only the
    unrelated CMake `CMP0175` dev warning from `webview_windows`.
- `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/comic/comic_source_test.dart test/core/comic/js_engine_smoke_test.dart`
  - `+3 ~1: All tests passed!` (the smoke test is skipped because the
    `flutter_qjs` native library is not loadable under `flutter test`, as
    expected).

The engine cannot run under `flutter test`; behavioral verification of the
account metadata is deferred to the Task 3 probe per the task context.

## Files changed + commit

- `assets/comic_source/init.js`
- `lib/core/comic/js_engine.dart`
- `lib/core/comic/comic_source.dart`

Commit `1347214` — `feat(comic): add account login support to the comic engine`
Pushed to `origin/dev` (`caf51ef..1347214`).

## Self-review findings

- `isLogged` getter uses the existing `loadData`, which already returns `null`
  for missing/empty values and JSON-parses otherwise; the explicit
  `null`/`undefined`/`''` checks are redundant but harmless and match the brief.
- `_cookieHeaderFor` never throws on malformed entries: non-`Map` list items are
  skipped, and a non-list `Map` value degrades to its `toString()` (no throw),
  satisfying the global constraint.
- `fromMetadata` `account is Map && account['cookieFields'] is List` parses as
  `(account is Map) && (...)` because `is` binds tighter than `&&`; correct.
- `AppDatabase` is already imported and used elsewhere in the file, so the new
  manager methods need no extra import.
- `jsonEncode(values)` for `List<String>` and the source key produce valid JS
  literals inside the `evaluate` templates.
- No new analyzer warnings; no comments added beyond the brief's `// Best-effort
  logout.` (the file already contains comments).

## Concerns

- `loginWithCookies` and `logout` call `AppDatabase()` directly, which throws if
  `AppDatabase.init()` has not run. This matches the brief and the app's
  lifecycle, but is a latent ordering dependency.
- Behavioral correctness of the `account` registry metadata and login/logout
  round-trips is not covered by `flutter test`; relies on the Task 3 probe.
- A non-list `Map` cookie-jar value serializes as a Dart map `toString()` rather
  than a `Cookie` header. Sources are expected to pass an array, so this is an
  unreachable edge case handled without throwing.

## Task 1 review fix

### What changed

`ComicSourceManager.login` in `lib/core/comic/comic_source.dart` discarded the
JS result and returned `true` whenever the evaluate did not throw, so a source
that signals failure by returning `false` was reported as a successful login.

- The evaluated snippet now captures the login result and returns
  `result !== false`.
- `login` now stores that value in `ok` and returns `ok == true`, so an explicit
  `false` is treated as failure.
- The surrounding `try`/`catch` still returns `false` on a thrown error.

No other changes; no comments added.

### Verification

- `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
  - `No issues found! (ran in 1.7s)`
- `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug`
  - `√ Built build\windows\x64\runner\Debug\acgnhub.exe` (11.2s). Only the
    unrelated CMake `CMP0175` dev warning from `webview_windows`.

### Commit

Commit `5f4f5f9` — `fix(comic): treat an explicit false login result as a failure`
Pushed to `origin/dev` (`1347214..5f4f5f9`).
