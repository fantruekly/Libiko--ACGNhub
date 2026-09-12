# Playback Sources — Design

> Date: 2026-09-10
> Status: Approved (design)
> Scope: Anime video sources + in-app playback. Metadata is a separate spec.

## 1. Goal

Let users watch anime from rule-based Chinese video sources. Start with **agedm.io** and **gimy.tv**: search by title, list episodes, resolve the stream URL, and play it in an in-app player.

## 2. Background / Constraints

- Most anime sites are unreachable or anti-bot from this network. Reachable with real content: **agedm.io**, **gimy.tv** (and Bilibili/mikan, deferred).
- Both sites hide the stream URL behind JavaScript: agedm encrypts it in `play.min.js`; gimy loads it via JS (no `m3u8`/`iframe` in the HTML). So a **webview must run the page's JS** to obtain the stream.
- **WebView2** is installed (151.x); `flutter_inappwebview` 6.1.5 supports Windows.
- The `media_kit` (mpv) binary now downloads (via the user's proxy), so in-app playback is feasible.
- All HTTP needs a browser `User-Agent`.

## 3. Architecture

New package folder `lib/core/video/`:

| File | Responsibility |
|---|---|
| `video_source.dart` | `VideoSource` interface + `VideoItem` / `VideoEpisode` models |
| `agedm_source.dart` | agedm.io rule implementation |
| `gimy_source.dart` | gimy.tv rule implementation |
| `stream_resolver.dart` | Load a play page in a headless webview and capture the `.m3u8`/`.mp4` URL |

Models:
```dart
class VideoItem {
  final String id;
  final String title;
  final String? cover;
  final String detailUrl;
}

class VideoEpisode {
  final String id;
  final String title;
  final int index;
  final String playUrl; // the site's play page URL
}

abstract class VideoSource {
  String get id;
  String get name;
  String get baseUrl;
  Future<List<VideoItem>> search(String keyword);
  Future<List<VideoEpisode>> episodes(String detailUrl);
}
```

`search` and `episodes` are pure HTTP + HTML parsing (testable). Only stream resolution needs the webview.

## 4. Sources

### 4.1 agedm.io (AGE)
- `search(kw)`: `GET https://www.agedm.io/search?query=<url-encoded kw>`.
  - Items: `h5.card-title a` → title = link text, `detailUrl` = the `href` (e.g. `http://www.agedm.io/detail/20260029`; normalize `http://` → `https://`).
  - `cover`: the card's `<img src>`.
  - `id`: the trailing number of `/detail/{id}`.
- `episodes(detailUrl)`: `GET detailUrl`.
  - Episodes: every `a[href*="/play/"]` → `playUrl` (absolute, e.g. `https://www.agedm.io/play/20230207/1/1`), title = link text, `index` = 0-based order.
  - `id`: the `/play/...` path.

### 4.2 gimy.tv
- `search(kw)`: `GET https://gimy.tv/search/-------------.html?wd=<url-encoded kw>`.
  - Items: `a[href*="/vod/"]` → title = link text, `detailUrl` = absolute `/vod/{id}.html`.
  - `cover`: the result card's `<img src>` (best-effort; may be null).
  - `id`: the trailing number of `/vod/{id}.html`.
- `episodes(detailUrl)`: `GET detailUrl`.
  - Episodes: every `a[href*="/ep-"]` → `playUrl` = absolute `/ep-{id}-{road}-{ep}.html`, title = link text, `index` = 0-based order.

Both sources set a browser `User-Agent` on requests.

## 5. Stream resolver

`StreamResolver.resolve(String playPageUrl, {Duration timeout = const Duration(seconds: 25)}) -> Future<String?>`:

- Create a headless `InAppWebView` (`flutter_inappwebview`) with `initialUrlRequest: URLRequest(url: playPageUrl)`, `initialSettings: InAppWebViewSettings(useShouldInterceptRequest: true, javaScriptEnabled: true)`.
- Capture the stream via `shouldInterceptRequest`: when a request URL contains `.m3u8` or `.mp4`, record it and complete.
- Fallback: `onLoadStop` injects a JS hook that overrides `XMLHttpRequest.prototype.open`, `window.fetch`, and watches `HTMLMediaElement.src`, calling `window.flutter_inappwebview.callHandler('stream', url)` for matching URLs.
- Return the first captured URL, or `null` on timeout. Always dispose the webview.

**Risk:** the Windows webview implementation may not fully support `shouldInterceptRequest` or JS handlers. Mitigation: if `shouldInterceptRequest` is unavailable, rely on the injected JS hook plus periodic `evaluateJavascript` polling of a global `window.__capturedStream` variable; the implementation should verify which path works and use it.

## 6. Player

`lib/modules/anime/video_player_page.dart` — a `StatefulWidget` taking `(title, streamUrl)`:
- Uses `media_kit`: `MediaKit.ensureInitialized()` at app start; a `Player` + `VideoController`; `Video(controller: controller)`.
- Controls: play/pause, a seek bar, current/total time, speed cycle (0.5–2.0), fullscreen toggle.
- Shows a loading spinner until the first frame, and an error message on failure.

## 7. Detail-page integration

In `lib/modules/anime/anime_detail_page.dart`, replace the placeholder "搜索播放资源" section with a **播放源** section:
- A row of source chips (agedm / gimy).
- On source select: `search(work.title)`; show the matching `VideoItem`s (usually 1) or an error/empty state.
- On item select: `episodes(detailUrl)`; show a numbered episode grid.
- On episode tap: `StreamResolver.resolve(episode.playUrl)` (show a loading dialog) → push `VideoPlayerPage(title, streamUrl)`; on null, show a snackbar "无法解析播放地址".

## 8. Dependencies (pubspec.yaml)

- `flutter_inappwebview: ^6.1.5`
- `media_kit: ^1.2.0`
- `media_kit_video: ^1.2.0`
- `media_kit_libs_windows_video: ^1.0.9`

`main.dart`: call `MediaKit.ensureInitialized()` before `runApp`.

## 9. Testing

- `test/core/video/agedm_source_test.dart`: fixture HTML for search + detail → `VideoItem`/`VideoEpisode` mapping (title, normalized https URL, id, episode order).
- `test/core/video/gimy_source_test.dart`: same for gimy.
- `StreamResolver` and the player are integration/manual-tested (a headless webview and native video aren't unit-testable in `flutter test`); document the manual check in the report.
- Re-run `flutter analyze lib test`, `flutter test`, `flutter build windows --debug`.

## 10. Files

**New**
- `lib/core/video/video_source.dart`
- `lib/core/video/agedm_source.dart`
- `lib/core/video/gimy_source.dart`
- `lib/core/video/stream_resolver.dart`
- `lib/modules/anime/video_player_page.dart`
- `test/core/video/agedm_source_test.dart`
- `test/core/video/gimy_source_test.dart`

**Modified**
- `lib/modules/anime/anime_detail_page.dart` (playback section)
- `lib/main.dart` (`MediaKit.ensureInitialized()`)
- `pubspec.yaml` (dependencies)

## 11. Out of scope

- More sources (Bilibili, mikan, user-imported Kazumi rules).
- Danmaku, subtitles, downloads, casting.
- The old `AnimeSource`/`AnimeRule`/`assets/rules/*` scaffolding (unreachable sites) — left in place, unused, unless a later cleanup removes it.
