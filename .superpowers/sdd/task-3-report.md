# Task 3 Report: Windows implementation + factory, callers switched to the abstraction

## What I implemented

- **`lib/core/video/headless_browser_windows.dart`** (new): `WindowsHeadlessBrowser
  implements HeadlessBrowser`, wrapping the forked `webview_windows`
  `HeadlessWebview`. Preserves existing behaviour exactly:
  - `start` runs the webview, denies popups, sets the optional user agent, and
    subscribes to the three native detection streams.
  - `onM3USourceLoaded` / `onVideoSourceLoaded` emit **without** the
    `looksLikeMediaUrl` path check (`always: true`).
  - the generic `onSourceLoaded` stream **is** filtered by `looksLikeMediaUrl`.
  - `load` resolves on `navigationCompleted` for a non-blank current URL, with
    a 15s default timeout; `eval` delegates to `executeScript`; `dispose`
    cancels subscriptions, closes the broadcast controller, and disposes the
    webview.
- **`lib/core/video/headless_browser_android.dart`** (new): temporary
  `AndroidHeadlessBrowser` scaffold (throws `UnimplementedError`) so the tree
  compiles; Task 4 replaces it.
- **`lib/core/video/headless_browser.dart`** (modified): added the two
  implementation imports plus `../platform.dart`, and the
  `HeadlessBrowser createHeadlessBrowser({bool? desktop})` factory that selects
  `WindowsHeadlessBrowser` when `desktop ?? isDesktop`, else the Android stub.
- **`lib/core/video/stream_resolver.dart`** (rewritten): now depends only on the
  `HeadlessBrowser` abstraction / factory. Still starts listening before
  `load`, keeps the 30s default timeout, returns null on timeout/failure, and
  cancels the subscription + disposes the browser in `finally`.
- **`lib/core/video/webview_scraper.dart`** (modified): imports and `fetchJson`
  replaced; `fetchJson` now goes through `createHeadlessBrowser()`, keeping the
  20s default timeout, 3 attempts, 600ms retry delay, and
  `userAgent ?? kBrowserUserAgent`. `kBrowserUserAgent`, `_helpersJs`,
  `buildSearchScript`, `buildEpisodesScript`, `decodeResult` are unchanged
  (verified via `git show` — only the import block and `fetchJson` body differ).
- **`test/core/video/headless_browser_test.dart`** (modified): added the factory
  test asserting `createHeadlessBrowser(desktop: true)` is a
  `WindowsHeadlessBrowser`.

No `webview_windows` import remains in `stream_resolver.dart` or
`webview_scraper.dart` (only in `headless_browser_windows.dart`, as intended).

## TDD evidence

### RED

Command:
```
C:\flutter\bin\flutter.bat test test/core/video/headless_browser_test.dart
```
Output (excerpt):
```
test/core/video/headless_browser_test.dart:3:8: Error: Error when reading 'lib/core/video/headless_browser_windows.dart': 系统找不到指定的文件。
import 'package:libiko/core/video/headless_browser_windows.dart';
       ^
test/core/video/headless_browser_test.dart:34:12: Error: Method not found: 'createHeadlessBrowser'.
    expect(createHeadlessBrowser(desktop: true), isA<WindowsHeadlessBrowser>());
           ^^^^^^^^^^^^^^^^^^^^^
test/core/video/headless_browser_test.dart:34:54: Error: 'WindowsHeadlessBrowser' isn't a type.
    expect(createHeadlessBrowser(desktop: true), isA<WindowsHeadlessBrowser>());
                                                     ^^^^^^^^^^^^^^^^^^^^^^
00:00 +0 -1: Some tests failed.
```
Why expected: the test imports the not-yet-created
`headless_browser_windows.dart` and calls the not-yet-added
`createHeadlessBrowser` factory, so compilation fails before any test runs.
This is the correct failure for the first (test) step of the TDD cycle.

### GREEN

Command (after steps 3–5):
```
C:\flutter\bin\flutter.bat test test/core/video/headless_browser_test.dart
```
Output:
```
00:00 +0: accepts a media URL whose path ends with .m3u8 or .mp4
00:00 +1: rejects a player page that merely embeds a media URL in its query
00:00 +2: rejects non-media URLs
00:00 +3: factory returns the Windows implementation on desktop
00:00 +4: All tests passed!
```

## Full-suite result

```
C:\flutter\bin\flutter.bat test
...
00:26 +346 ~1: All tests passed!
```
346 pass / 1 skip (the pre-existing flutter_qjs skip). Previous baseline was
345 pass / 1 skip; the +1 is the new factory test.

## Analyzer result

```
C:\flutter\bin\flutter.bat analyze
Analyzing ACGNhub...
No issues found! (ran in 6.9s)
```

## Windows release build result

```
C:\flutter\bin\flutter.bat build windows --release
...
√ Built build\windows\x64\runner\Release\libiko.exe
```
(Two pre-existing CMake `add_custom_command(DEPENDS)` dev warnings from the
`flutter_inappwebview_windows` / `webview_windows` plugins; not errors.)

Per the task instructions I did **not** launch the built app — the controller
does the interactive playback confirmation.

## Files changed

Commit `bc3c50d` — `refactor(video): route stream resolution and scraping through HeadlessBrowser` (6 files):
- `lib/core/video/headless_browser_windows.dart` (new)
- `lib/core/video/headless_browser_android.dart` (new)
- `lib/core/video/headless_browser.dart`
- `lib/core/video/stream_resolver.dart`
- `lib/core/video/webview_scraper.dart`
- `test/core/video/headless_browser_test.dart`

## Self-review findings

- **Commit scope deviation:** the brief's step 11 stages only `lib/core/video`,
  but this task also modifies `test/core/video/headless_browser_test.dart`.
  Staging only `lib/core/video` would have left the new test uncommitted, so I
  staged that one test file as well. No other files were staged (`.superpowers/`,
  `docs/`, `build/` untouched).
- Behaviour preservation confirmed: path filter only on the generic source
  stream; `StreamResolver` listens before `load`, 30s default, null on
  timeout/failure; `WebviewScraper.fetchJson` keeps 20s / 3 attempts / 600ms /
  `userAgent ?? kBrowserUserAgent`.
- No Task 4/5 work implemented (Android browser is a throwing scaffold only; no
  player changes).
- `import 'dart:async';` is retained in `webview_scraper.dart` per the brief;
  the analyzer reports no unused-import issue.

## Issues or concerns

- None blocking. The only open item is the interactive Windows playback check,
  which the controller performs.

---

# Task 3 Review Fix: restore `resolve`'s timeout contract

## Finding

The Task 3 refactor changed `StreamResolver.resolve` from
`await browser.load(...)` (which returned immediately in the old code) followed
by a 30s media wait, to awaiting a navigation wait (15s default) *before*
starting the 30s media wait. Worst case grew from ≈30s to ≈45s, and a
caller-supplied `timeout` no longer bounded the navigation wait.

## Change

- **`lib/core/video/stream_resolver.dart`** — replaced the blocking
  `await browser.load(playPageUrl)` with a concurrent, fire-and-forget
  `unawaited(() async { await browser.load(playPageUrl, timeout: timeout); }())`.
  The media subscription is still created *before* the load is kicked off, so
  media requested during the page load is captured. The single `timeout` now
  bounds the whole operation again. Default 30s, the `debugPrint` lines, and the
  `finally` subscription-cancel + `dispose` cleanup are unchanged.
- **`lib/core/video/webview_scraper.dart`** — line ~73 doc comment updated from
  "Mirrors [StreamResolver]'s lifecycle: create, run, load, dispose." to
  "Loads a URL in a [HeadlessBrowser] and evaluates an extraction script."
  No other byte in the file changed.

## Verification

Command 1:
```
C:\flutter\bin\flutter.bat analyze
```
Output (tail):
```
Analyzing ACGNhub...
No issues found! (ran in 6.7s)
```

Command 2:
```
C:\flutter\bin\flutter.bat test
```
Output (tail):
```
00:22 +345 ~1: D:/ACGNhub/test/shell/main_shell_test.dart: game tab exposes the search entry
00:22 +346 ~1: All tests passed!
```
346 pass / 1 skip (the pre-existing flutter_qjs native-library skip).

There is no unit test for `StreamResolver.resolve` itself — it requires a native
webview and cannot run under `flutter test`. The analyzer and full suite above
are the verification evidence; the interactive Windows playback check remains
with the controller.

## Commit

```
git add lib/core/video/stream_resolver.dart lib/core/video/webview_scraper.dart
git commit -m "fix(video): keep resolve's timeout bounding the whole operation"
```
```
[dev 590c509] fix(video): keep resolve's timeout bounding the whole operation
 2 files changed, 10 insertions(+), 3 deletions(-)
```
Only the two source files were staged (`.superpowers/`, `docs/`, `build/`
untouched).
