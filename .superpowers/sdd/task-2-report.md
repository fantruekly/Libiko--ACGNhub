# Task 2 Report: `WebviewScraper` + XPath→JS script builders

## Status
DONE

## What I implemented
- `lib/core/video/webview_scraper.dart`, exactly as specified in the brief:
  - `const String kBrowserUserAgent` (Chrome 120 desktop UA).
  - `String buildSearchScript(SourceRule rule)` — emits an IIFE embedding the rule's
    `searchList`/`searchName`/`searchResult` XPaths via `jsonEncode`, uses `document.evaluate`
    helpers (`__ev`/`__txt`/`__attr`), and returns `JSON.stringify` of `[{name, href}]`.
  - `String buildEpisodesScript(SourceRule rule)` — emits an IIFE embedding
    `chapterRoads`/`chapterResult`, scoping the result query to the first road element,
    returning `JSON.stringify` of `[{title, href}]`.
  - `class WebviewScraper.fetchJson(...)` — headless WebView lifecycle mirroring
    `StreamResolver`: `HeadlessWebview()` → `run()` → `setPopupWindowPolicy(deny)` →
    `setUserAgent(...)` → subscribe `loadingState` for `navigationCompleted` → `loadUrl` →
    wait with `timeout` → retry `executeScript` up to `attempts` times (600ms backoff) →
    dispose in `finally`. Returns the extracted `List`, `const <dynamic>[]` when empty, or
    `null` on failure.
- `test/core/video/xpath_js_test.dart` — the brief's 2 unit tests, verbatim.

`SourceRule` was not modified.

## What I tested and results
- Focused test: `flutter test test/core/video/xpath_js_test.dart` → **2 tests passed**.
- Full suite: `flutter test` → **55 tests passed**.
- Static analysis: `flutter analyze lib test` → **No issues found!**

The `WebviewScraper` runtime path is not unit-testable under `flutter test` (needs the
Windows runner/WebView2), per the brief. It is verified to compile and type-check via
`flutter analyze`.

## TDD evidence

### RED
Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/video/xpath_js_test.dart
```
Output (excerpt):
```
test/core/video/xpath_js_test.dart:3:8: Error: Error when reading 'lib/core/video/webview_scraper.dart': 系统找不到指定的文件。
import 'package:acgnhub/core/video/webview_scraper.dart';
test/core/video/xpath_js_test.dart:18:16: Error: Method not found: 'buildSearchScript'.
test/core/video/xpath_js_test.dart:27:16: Error: Method not found: 'buildEpisodesScript'.
00:00 +0 -1: loading D:/ACGNhub/test/core/video/xpath_js_test.dart [E]
  Failed to load "D:/ACGNhub/test/core/video/xpath_js_test.dart":
  Compilation failed for testPath=D:/ACGNhub/test/core/video/xpath_js_test.dart
00:00 +0 -1: Some tests failed.
```
Why expected: `webview_scraper.dart` and both builder functions did not exist yet, so the
test could not compile — proving the test exercises the missing feature rather than passing
against pre-existing code.

### GREEN
Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/video/xpath_js_test.dart
```
Output:
```
00:00 +0: buildSearchScript embeds the search XPaths and returns JSON
00:00 +1: buildEpisodesScript embeds the chapter XPaths and returns JSON
00:00 +2: All tests passed!
```

## Files changed
- Added `lib/core/video/webview_scraper.dart` (127 lines).
- Added `test/core/video/xpath_js_test.dart` (31 lines).

Commit:
- `e504d96` feat(video): add headless webview scraper and XPath-to-JS builders

## Self-review findings
- Completeness: all Produces interfaces (`kBrowserUserAgent`, `buildSearchScript`,
  `buildEpisodesScript`, `WebviewScraper.fetchJson`) are present with the specified
  signatures. `SourceRule` untouched.
- Verbatim fidelity: implementation and test match the brief character-for-character.
- Quality: lifecycle, subscription cancellation, and dispose are wrapped defensively like
  the existing `StreamResolver`; no leaks of the WebView on any path.
- YAGNI: no extra parameters, classes, or speculative features added.
- Tests verify real behavior: they assert that the generated JS actually embeds the exact
  quoted XPaths (via `jsonEncode`) and calls `document.evaluate`/`JSON.stringify`. The
  assertions are string-`contains` based, as mandated by the brief — they confirm the
  builder output shape but do not execute the JS. Runtime extraction correctness depends on
  Task 3 / manual Windows-runner validation.

## Concerns
- `WebviewScraper.fetchJson` is not exercised by any automated test (inherent: headless
  WebView2 requires the Windows runner). Its runtime behavior (navigation-completed timing,
  `executeScript` decoding of the returned JSON string into a `List`, retry semantics) is
  unverified until Task 3 or a manual run.
- `executeScript` is assumed to auto-decode the `JSON.stringify` payload into a `List`
  (consistent with `webview_windows` behavior and the brief's `result is List` check); if
  it instead returns a `String`, the scraper would return `const <dynamic>[]`. Worth
  confirming in Task 3 integration.
- The test file's path in the brief is `test/core/video/xpath_js_test.dart`, while the
  task's Context mentions tests live in `test/core/video/` — consistent, no conflict.

## Fix report

### What changed
Confirmed bug: `buildSearchScript`/`buildEpisodesScript` returned `JSON.stringify(...)`,
i.e. a JS **string**. `HeadlessWebview.executeScript` returns the WebView2 JSON result
already decoded by `json.decode`, so a JS string arrives as a Dart `String`, never a
`List`; `fetchJson`'s `result is List` check always failed and it always returned `[]`.

- `lib/core/video/webview_scraper.dart`
  1. `buildSearchScript`: `return JSON.stringify(rows);` → `return rows;`.
  2. `buildEpisodesScript`: `return JSON.stringify(out);` → `return out;`.
  3. Added `@visibleForTesting static List<dynamic> WebviewScraper.decodeResult(dynamic)`
     — returns a `List` as-is, tolerates a JSON string that decodes to a list, otherwise
     returns `const <dynamic>[]`.
  4. `fetchJson` retry loop: `if (result is List && result.isNotEmpty) return result;` →
     `final list = decodeResult(result); if (list.isNotEmpty) return list;`.
  - `document.evaluate` and `jsonEncode`-embedded XPaths left unchanged.
- `test/core/video/xpath_js_test.dart`
  - Replaced the two `contains('JSON.stringify')` assertions with array-return contract
    assertions (`return rows;` / `return out;` plus `isNot(contains('JSON.stringify'))`).
  - Added 4 `decodeResult` unit tests: `List` as-is, JSON string → list, non-list JSON
    string → empty, `null`/non-JSON string → empty.

### Commands run and output
1. Focused test:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/video/xpath_js_test.dart
```
```
00:00 +0: loading D:/ACGNhub/test/core/video/xpath_js_test.dart
00:00 +0: buildSearchScript embeds the search XPaths and returns JSON
00:00 +1: buildEpisodesScript embeds the chapter XPaths and returns JSON
00:00 +2: decodeResult returns a List as-is
00:00 +3: decodeResult decodes a JSON string to a list
00:00 +4: decodeResult returns empty for a non-list JSON string
00:00 +5: decodeResult returns empty for null and non-JSON strings
00:00 +6: All tests passed!
```

2. Static analysis:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test
```
```
Analyzing 2 items...
No issues found! (ran in 1.5s)
```

3. Full suite:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test
```
```
00:06 +59: All tests passed!
```

### Commit
- `5a79918` fix(video): return extraction arrays directly so executeScript decodes to a list
