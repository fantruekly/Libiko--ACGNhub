### Task 3: Windows implementation + factory, and switch callers to the abstraction

**Files:**
- Create: `lib/core/video/headless_browser_windows.dart`
- Modify: `lib/core/video/headless_browser.dart` (add `createHeadlessBrowser`)
- Modify: `lib/core/video/stream_resolver.dart`
- Modify: `lib/core/video/webview_scraper.dart`
- Modify: `test/core/video/headless_browser_test.dart`

**Interfaces:**
- Consumes: `HeadlessBrowser`, `looksLikeMediaUrl` (Task 2); `isDesktop`.
- Produces: `HeadlessBrowser createHeadlessBrowser({bool? desktop})`; `class WindowsHeadlessBrowser implements HeadlessBrowser`.

- [ ] **Step 1: Write the failing factory test**

Append to `test/core/video/headless_browser_test.dart`:
```dart
import 'package:libiko/core/video/headless_browser_windows.dart';

// inside main():
  test('factory returns the Windows implementation on desktop', () {
    expect(createHeadlessBrowser(desktop: true), isA<WindowsHeadlessBrowser>());
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```powershell
C:\flutter\bin\flutter.bat test test/core/video/headless_browser_test.dart
```
Expected: FAIL 鈥?`headless_browser_windows.dart` not found / `createHeadlessBrowser` undefined.

- [ ] **Step 3: Implement the Windows browser**

Create `lib/core/video/headless_browser_windows.dart`:
```dart
import 'dart:async';

import 'package:webview_windows/webview_windows.dart';

import 'headless_browser.dart';

/// [HeadlessBrowser] backed by the forked `webview_windows` headless WebView2.
class WindowsHeadlessBrowser implements HeadlessBrowser {
  final _media = StreamController<String>.broadcast();
  final _subs = <StreamSubscription<dynamic>>[];
  HeadlessWebview? _webview;

  @override
  Stream<String> get mediaUrls => _media.stream;

  @override
  Future<void> start({String? userAgent}) async {
    final webview = HeadlessWebview();
    _webview = webview;
    await webview.run();
    try {
      await webview.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
    } catch (_) {}
    if (userAgent != null) await webview.setUserAgent(userAgent);

    // Native detection is authoritative for these two: some HLS URLs carry no
    // extension, so the path check must not be applied here.
    _subs.add(webview.onM3USourceLoaded
        .listen((data) => _emit(data['url'] ?? '', always: true)));
    _subs.add(webview.onVideoSourceLoaded
        .listen((data) => _emit(data['url'] ?? '', always: true)));
    // Generic fallback for streams the native detector misses: some sites serve
    // the m3u8 as `text/html`, so neither content-type nor body detection fires.
    _subs.add(webview.onSourceLoaded
        .listen((data) => _emit(data['url'] ?? '')));
  }

  void _emit(String url, {bool always = false}) {
    if (url.isEmpty || _media.isClosed) return;
    if (!always && !looksLikeMediaUrl(url)) return;
    _media.add(url);
  }

  @override
  Future<void> load(String url,
      {Duration timeout = const Duration(seconds: 15)}) async {
    final webview = _webview;
    if (webview == null) return;
    final loaded = Completer<void>();
    final subs = <StreamSubscription<dynamic>>[];
    var currentUrl = '';
    subs.add(webview.url.listen((value) => currentUrl = value));
    subs.add(webview.loadingState.listen((state) {
      if (state == LoadingState.navigationCompleted &&
          currentUrl.isNotEmpty &&
          currentUrl != 'about:blank' &&
          !loaded.isCompleted) {
        loaded.complete();
      }
    }));
    try {
      await webview.loadUrl(url);
      await loaded.future.timeout(timeout, onTimeout: () {});
    } finally {
      for (final s in subs) {
        try {
          await s.cancel();
        } catch (_) {}
      }
    }
  }

  @override
  Future<dynamic> eval(String script) async => _webview?.executeScript(script);

  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      try {
        await s.cancel();
      } catch (_) {}
    }
    _subs.clear();
    if (!_media.isClosed) await _media.close();
    try {
      await _webview?.dispose();
    } catch (_) {}
    _webview = null;
  }
}
```

- [ ] **Step 4: Create the temporary Android stub**

Create `lib/core/video/headless_browser_android.dart`. It is a scaffold so this task compiles; Task 4 replaces it with the real implementation.
```dart
import 'dart:async';

import 'headless_browser.dart';

/// Temporary scaffold: Task 4 replaces this with the flutter_inappwebview
/// implementation.
class AndroidHeadlessBrowser implements HeadlessBrowser {
  @override
  Stream<String> get mediaUrls => const Stream.empty();

  @override
  Future<void> start({String? userAgent}) async =>
      throw UnimplementedError('AndroidHeadlessBrowser');

  @override
  Future<void> load(String url,
          {Duration timeout = const Duration(seconds: 15)}) async =>
      throw UnimplementedError('AndroidHeadlessBrowser');

  @override
  Future<dynamic> eval(String script) async =>
      throw UnimplementedError('AndroidHeadlessBrowser');

  @override
  Future<void> dispose() async {}
}
```

- [ ] **Step 5: Add the factory**

In `lib/core/video/headless_browser.dart`, add these imports at the top of the file:
```dart
import 'headless_browser_android.dart';
import 'headless_browser_windows.dart';
import '../platform.dart';
```
and add this at the end of the file:
```dart
/// Creates the platform's [HeadlessBrowser]. [desktop] overrides the platform
/// check for tests.
HeadlessBrowser createHeadlessBrowser({bool? desktop}) =>
    (desktop ?? isDesktop)
        ? WindowsHeadlessBrowser()
        : AndroidHeadlessBrowser();
```

- [ ] **Step 6: Run tests to verify they pass**

Run:
```powershell
C:\flutter\bin\flutter.bat test test/core/video/headless_browser_test.dart
```
Expected: PASS (3 media-URL tests + 1 factory test).

- [ ] **Step 7: Rewrite `StreamResolver` on top of the abstraction**

Replace the whole of `lib/core/video/stream_resolver.dart` with:
```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'headless_browser.dart';

/// Resolves a video source's play page to a playable stream URL: the page is
/// loaded in a hidden browser and the app waits for it to request the media
/// stream. The user never sees the source site 鈥?playback happens in the app's
/// own media_kit player.
class StreamResolver {
  Future<String?> resolve(
    String playPageUrl, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final browser = createHeadlessBrowser();
    StreamSubscription<String>? sub;
    try {
      await browser.start();
      final completer = Completer<String?>();
      sub = browser.mediaUrls.listen((url) {
        if (url.isNotEmpty && !completer.isCompleted) completer.complete(url);
      });
      await browser.load(playPageUrl);
      final url = await completer.future.timeout(timeout, onTimeout: () {
        debugPrint('[StreamResolver] TIMEOUT for $playPageUrl');
        return null;
      });
      debugPrint('[StreamResolver] resolved=$url');
      return url;
    } catch (e) {
      debugPrint('[StreamResolver] failed for $playPageUrl: $e');
      return null;
    } finally {
      try {
        await sub?.cancel();
      } catch (_) {}
      try {
        await browser.dispose();
      } catch (_) {}
    }
  }
}
```

- [ ] **Step 8: Rewrite `WebviewScraper` on top of the abstraction**

In `lib/core/video/webview_scraper.dart`: keep `kBrowserUserAgent`, `_helpersJs`, `buildSearchScript`, `buildEpisodesScript` and `decodeResult` unchanged; replace the imports and `fetchJson` with:
```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'headless_browser.dart';
import 'source_rule.dart';
```
```dart
  Future<dynamic> fetchJson({
    required String url,
    required String script,
    String? userAgent,
    Duration timeout = const Duration(seconds: 20),
    int attempts = 3,
  }) async {
    final browser = createHeadlessBrowser();
    try {
      await browser.start(userAgent: userAgent ?? kBrowserUserAgent);
      await browser.load(url, timeout: timeout);

      for (var attempt = 0; attempt < attempts; attempt++) {
        dynamic result;
        try {
          result = await browser.eval(script);
        } catch (_) {
          result = null;
        }
        final list = decodeResult(result);
        if (list.isNotEmpty) return list;
        if (attempt < attempts - 1) {
          await Future.delayed(const Duration(milliseconds: 600));
        }
      }
      return const <dynamic>[];
    } catch (e) {
      debugPrint('[WebviewScraper] failed for $url: $e');
      return null;
    } finally {
      try {
        await browser.dispose();
      } catch (_) {}
    }
  }
```
Remove the now-unused `package:webview_windows/webview_windows.dart` import.

- [ ] **Step 9: Run tests and analyzer**

Run:
```powershell
C:\flutter\bin\flutter.bat test
C:\flutter\bin\flutter.bat analyze
```
Expected: all tests pass; `No issues found!`

- [ ] **Step 10: Verify Windows behaviour is unchanged**

Run:
```powershell
C:\flutter\bin\flutter.bat build windows --release
```
Expected: `鉁?Built build\windows\x64\runner\Release\libiko.exe`

Then launch the built app, open an anime detail page, pick a source and an episode, and confirm playback still resolves and starts exactly as before.

- [ ] **Step 11: Commit**

```powershell
git add lib/core/video
git commit -m "refactor(video): route stream resolution and scraping through HeadlessBrowser"
```

---

