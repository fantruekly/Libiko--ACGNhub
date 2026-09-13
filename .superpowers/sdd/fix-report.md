# Fix Report: skip the JS engine smoke test under `flutter test`

## Status: DONE

## Change

`test/core/comic/js_engine_smoke_test.dart` — marked the
`'evaluates a trivial script'` test with a `skip:` reason instead of deleting it.
The test body is unchanged; the reason documents that the `flutter_qjs` native
library (`flutter_qjs_plugin.dll`, error 126) is not loadable under
`flutter test` and that engine behaviour is verified with the app-level probe
`flutter run -d windows -t .superpowers/sdd/js_probe.dart`.

No other files changed.

## Commands run and output

### 1. Targeted test

```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/comic/js_engine_smoke_test.dart
```

```
00:00 +0: loading D:/ACGNhub/test/core/comic/js_engine_smoke_test.dart
00:00 +0: evaluates a trivial script
  Skip: The flutter_qjs native library is not loadable under flutter test (flutter_qjs_plugin.dll, error 126); engine behaviour is verified with an app-level probe: flutter run -d windows -t .superpowers/sdd/js_probe.dart
00:00 +0 ~1: All tests skipped.
```

Result: reported as **skipped**, not failed.

### 2. Full suite

```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test
```

```
...
00:01 +37 ~1: D:/ACGNhub/test/core/comic/js_engine_smoke_test.dart: evaluates a trivial script
  Skip: The flutter_qjs native library is not loadable under flutter test (flutter_qjs_plugin.dll, error 126); engine behaviour is verified with an app-level probe: flutter run -d windows -t .superpowers/sdd/js_probe.dart
...
00:11 +121 ~1: All tests passed!
```

Result: **121 passed, 1 skipped, 0 failed** — all green.

### 3. Analyzer

```
$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test
```

```
Analyzing 2 items...
No issues found! (ran in 2.9s)
```

## Commit

`abcbf6e test(comic): skip the engine smoke test under flutter test`
(1 file changed, 12 insertions, 6 deletions)
