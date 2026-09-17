### Task 4: Android implementation

**Files:**
- Modify: `lib/core/video/headless_browser_android.dart` (replace the stub)
- Modify: `test/core/video/headless_browser_test.dart`

**Interfaces:**
- Consumes: `HeadlessBrowser`, `looksLikeMediaUrl` (Task 2); factory (Task 3).
- Produces: `class AndroidHeadlessBrowser implements HeadlessBrowser` 鈥?the real Android implementation.

- [ ] **Step 1: Write the failing factory test**

Append to `test/core/video/headless_browser_test.dart`:
```dart
import 'package:libiko/core/video/headless_browser_android.dart';

// inside main():
  test('factory returns the Android implementation on mobile', () {
    expect(
        createHeadlessBrowser(desktop: false), isA<AndroidHeadlessBrowser>());
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```powershell
C:\flutter\bin\flutter.bat test test/core/video/headless_browser_test.dart
```
Expected: FAIL 鈥?`AndroidHeadlessBrowser` is still the stub whose `start` throws, or the import is missing the real class.

- [ ] **Step 3: Replace the stub with the real implementation**

Replace the whole of `lib/core/video/headless_browser_android.dart` with:
```dart
import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'headless_browser.dart';

/// [HeadlessBrowser] backed by `flutter_inappwebview`'s headless WebView.
///
/// Media detection happens in [shouldInterceptRequest]: every subresource the
/// page requests is checked against [looksLikeMediaUrl]. Returning null leaves
/// the request untouched.
class AndroidHeadlessBrowser implements HeadlessBrowser {
  final _media = StreamController<String>.broadcast();
  HeadlessInAppWebView? _headless;
  Completer<void>? _loaded;

  @override
  Stream<String> get mediaUrls => _media.stream;

  @override
  Future<void> start({String? userAgent}) async {
    final headless = HeadlessInAppWebView(
      initialSettings: InAppWebViewSettings(
        userAgent: userAgent,
        useShouldInterceptRequest: true,
        javaScriptEnabled: true,
        mediaPlaybackRequiresUserGesture: false,
        supportMultipleWindows: false,
        javaScriptCanOpenWindowsAutomatically: false,
      ),
      onLoadStop: (controller, url) {
        if (url == null || url.toString() == 'about:blank') return;
        final completer = _loaded;
        if (completer != null && !completer.isCompleted) completer.complete();
      },
      shouldInterceptRequest: (controller, request) async {
        final url = request.url.toString();
        if (looksLikeMediaUrl(url) && !_media.isClosed) _media.add(url);
        return null;
      },
    );
    _headless = headless;
    await headless.run();
  }

  @override
  Future<void> load(String url,
      {Duration timeout = const Duration(seconds: 15)}) async {
    final controller = _headless?.webViewController;
    if (controller == null) return;
    final completer = Completer<void>();
    _loaded = completer;
    try {
      await controller.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
      await completer.future.timeout(timeout, onTimeout: () {});
    } finally {
      _loaded = null;
    }
  }

  @override
  Future<dynamic> eval(String script) async =>
      _headless?.webViewController?.evaluateJavascript(source: script);

  @override
  Future<void> dispose() async {
    _loaded = null;
    if (!_media.isClosed) await _media.close();
    try {
      await _headless?.dispose();
    } catch (_) {}
    _headless = null;
  }
}
```

- [ ] **Step 4: Run tests and analyzer**

Run:
```powershell
C:\flutter\bin\flutter.bat test
C:\flutter\bin\flutter.bat analyze
```
Expected: all tests pass; `No issues found!`

(If `flutter_inappwebview`'s API differs from the code above 鈥?e.g. `HeadlessInAppWebView` constructor parameters or `evaluateJavascript` return type 鈥?adjust the implementation to the installed version and re-run. The interface in `headless_browser.dart` must not change.)

- [ ] **Step 5: Build and install on the emulator**

Run:
```powershell
C:\flutter\bin\flutter.bat build apk --release
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adb install -r build\app\outputs\flutter-apk\app-release.apk
& $adb shell settings put global http_proxy 10.0.2.2:10888
```
Expected: `Success` (the emulator needs the host proxy to reach the network).

- [ ] **Step 6: Verify resolution on a real source**

In the app on the emulator: open an anime detail page 鈫?pick **AGE鍔ㄦ极** 鈫?pick a matching title 鈫?open an episode 鈫?confirm the player resolves a URL and starts playing (check `adb logcat -s flutter` for `[StreamResolver] resolved=`).

- [ ] **Step 7: Commit**

```powershell
git add lib/core/video/headless_browser_android.dart test/core/video/headless_browser_test.dart
git commit -m "feat(video): implement the android headless browser with flutter_inappwebview"
```

---

