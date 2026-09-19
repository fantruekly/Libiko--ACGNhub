### Task 2: Extract `looksLikeMediaUrl` into the `HeadlessBrowser` abstraction

**Files:**
- Create: `lib/core/video/headless_browser.dart`
- Create: `test/core/video/headless_browser_test.dart`
- Delete: `test/core/video/stream_resolver_test.dart`
- Modify: `lib/core/video/stream_resolver.dart`

**Interfaces:**
- Consumes: `isDesktop` from `lib/core/platform.dart`.
- Produces: `abstract class HeadlessBrowser` and top-level `bool looksLikeMediaUrl(String url)`.

- [ ] **Step 1: Write the failing test**

Create `test/core/video/headless_browser_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/video/headless_browser.dart';

void main() {
  test('accepts a media URL whose path ends with .m3u8 or .mp4', () {
    expect(
      looksLikeMediaUrl(
          'https://vip15.play-cdn15.com/20230226/41_c8391dc5/index.m3u8'),
      isTrue,
    );
    expect(looksLikeMediaUrl('https://cdn.test/video/1.mp4'), isTrue);
    expect(looksLikeMediaUrl('https://cdn.test/v/1.m3u8?token=abc'), isTrue);
    expect(looksLikeMediaUrl('https://cdn.test/v/1.mp4#t=10'), isTrue);
  });

  test('rejects a player page that merely embeds a media URL in its query', () {
    expect(
      looksLikeMediaUrl(
          'https://www.bmmdmm.com/hdst/player/artplayer/index.html'
          '?url=https://vip15.play-cdn15.com/20230226/41_c8391dc5/index.m3u8'),
      isFalse,
    );
  });

  test('rejects non-media URLs', () {
    expect(looksLikeMediaUrl('https://www.bmmdmm.com/play/80993-0-0.html'),
        isFalse);
    expect(looksLikeMediaUrl('https://www.bmmdmm.com/time'), isFalse);
    expect(looksLikeMediaUrl('https://img.test/pic/a.webp'), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```powershell
C:\flutter\bin\flutter.bat test test/core/video/headless_browser_test.dart
```
Expected: FAIL 鈥?`Error: Couldn't resolve the package 'libiko'` / `headless_browser.dart` not found.

- [ ] **Step 3: Create the abstraction**

Create `lib/core/video/headless_browser.dart`:
```dart
import 'dart:async';

/// A hidden browser used to render source pages and sniff their media streams.
/// Windows and Android have different native implementations; callers see only
/// this interface.
abstract class HeadlessBrowser {
  /// Creates and starts the browser. [userAgent] defaults to the browser UA
  /// chosen by the implementation.
  Future<void> start({String? userAgent});

  /// Media URLs (.m3u8 / .mp4) the browser has observed, filtered by each
  /// implementation's own detection (native sniffing and/or [looksLikeMediaUrl]).
  Stream<String> get mediaUrls;

  /// Navigates to [url] and waits until the page finishes loading, at most
  /// [timeout]. Resolves normally on timeout.
  Future<void> load(String url,
      {Duration timeout = const Duration(seconds: 15)});

  /// Evaluates [script] and returns the decoded value, or null on failure.
  Future<dynamic> eval(String script);

  Future<void> dispose();
}

final RegExp _mediaRe = RegExp(r'\.(m3u8|mp4)$', caseSensitive: false);

/// True when the URL's *path* ends with a media extension. The path is used
/// (not the whole URL) so a player page like
/// `.../player/index.html?url=https://cdn/x/index.m3u8` is not mistaken for
/// the stream it embeds.
bool looksLikeMediaUrl(String url) {
  final path = Uri.tryParse(url)?.path ?? url;
  return _mediaRe.hasMatch(path);
}
```

- [ ] **Step 4: Point `StreamResolver` at the shared function**

In `lib/core/video/stream_resolver.dart`, add the import:
```dart
import 'headless_browser.dart';
```
and delete the class-level `_mediaRe`, the `looksLikeMediaUrl` static method and the `_mediaRe` usage 鈥?the body of the `onSourceLoaded` listener becomes:
```dart
      subs.add(webview.onSourceLoaded.listen((data) {
        final url = data['url'] ?? '';
        if (looksLikeMediaUrl(url)) finish(url);
      }));
```
Also drop the now-unused `package:flutter/foundation.dart` import only if nothing else in the file uses it (`debugPrint` does 鈥?keep it).

- [ ] **Step 5: Delete the old test file**

```powershell
Remove-Item test/core/video/stream_resolver_test.dart
```

- [ ] **Step 6: Run tests and analyzer**

Run:
```powershell
C:\flutter\bin\flutter.bat test test/core/video/headless_browser_test.dart
C:\flutter\bin\flutter.bat analyze
```
Expected: all tests pass; `No issues found!`

- [ ] **Step 7: Commit**

```powershell
git add lib/core/video/headless_browser.dart lib/core/video/stream_resolver.dart test/core/video/headless_browser_test.dart test/core/video/stream_resolver_test.dart
git commit -m "refactor(video): move looksLikeMediaUrl into a headless browser abstraction"
```

---

