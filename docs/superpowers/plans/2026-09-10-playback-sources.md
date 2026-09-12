# Playback Sources Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users watch anime from agedm.io and gimy.tv: search by title, list episodes, resolve the JS-obfuscated stream via a headless webview, and play it in an in-app media_kit player.

**Architecture:** A `VideoSource` interface with two rule-based implementations (agedm, gimy) handle HTTP search/episode parsing. A `StreamResolver` loads the site's play page in a headless `flutter_inappwebview` webview and captures the `.m3u8`/`.mp4` URL. A `VideoPlayerPage` plays it with `media_kit`. The anime detail page wires these together.

**Tech Stack:** Flutter 3.35, Dart 3, Dio 5, `html` (already a dependency), `flutter_inappwebview` 6.1.x (Windows), `media_kit` + `media_kit_video` + `media_kit_libs_windows_video`.

## Global Constraints

- Target platform: Windows first; WebView2 is installed.
- All site HTTP requests set a browser `User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36`.
- Sources: `agedm.io` (id `agedm`, name `AGE动漫`), `gimy.tv` (id `gimy`, name `gimy`).
- Stream capture matches URLs containing `.m3u8` or `.mp4`.
- `search`/`episodes` are pure HTTP + HTML parsing (unit-testable); the webview capture and the player are manual/integration-tested.
- Commits: only run `git commit` steps if the user explicitly asks; otherwise treat them as checkpoints.

---

### Task 1: `VideoSource` models + interface + `AgedmSource`

**Files:**
- Create: `lib/core/video/video_source.dart`
- Create: `lib/core/video/agedm_source.dart`
- Test: `test/core/video/agedm_source_test.dart`

**Interfaces:**
- Produces: `class VideoItem { final String id; final String title; final String? cover; final String detailUrl; }`
- Produces: `class VideoEpisode { final String id; final String title; final int index; final String playUrl; }`
- Produces: `abstract class VideoSource { String get id; String get name; String get baseUrl; Future<List<VideoItem>> search(String keyword); Future<List<VideoEpisode>> episodes(String detailUrl); }`
- Produces: `class AgedmSource implements VideoSource` with `AgedmSource({Dio? dio})` and static `parseSearch(String html)`, `parseEpisodes(String html, String base)`.

- [ ] **Step 1: Write the failing test**

Create `test/core/video/agedm_source_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/video/agedm_source.dart';

void main() {
  test('parseSearch extracts title, id, and normalized detail URL', () {
    const html = '''
    <div class="card">
      <a href="https://www.agedm.io/detail/20260029"><img src="https://img/x.jpg"></a>
      <h5 class="card-title"><a href="http://www.agedm.io/detail/20260029">葬送的芙莉莲 第二季</a></h5>
    </div>''';

    final items = AgedmSource.parseSearch(html);
    expect(items, hasLength(1));
    final it = items.first;
    expect(it.id, '20260029');
    expect(it.title, '葬送的芙莉莲 第二季');
    expect(it.detailUrl, 'https://www.agedm.io/detail/20260029');
    expect(it.cover, 'https://img/x.jpg');
  });

  test('parseEpisodes extracts ordered play links', () {
    const html = '''
    <div class="playlist">
      <a href="/play/20230207/1/1">第1集</a>
      <a href="/play/20230207/1/2">第2集</a>
    </div>''';

    final eps = AgedmSource.parseEpisodes(html, 'https://www.agedm.io');
    expect(eps, hasLength(2));
    expect(eps[0].title, '第1集');
    expect(eps[0].index, 0);
    expect(eps[0].playUrl, 'https://www.agedm.io/play/20230207/1/1');
    expect(eps[1].index, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/video/agedm_source_test.dart`
Expected: FAIL — `agedm_source.dart` not found.

- [ ] **Step 3: Create `lib/core/video/video_source.dart`**

```dart
class VideoItem {
  final String id;
  final String title;
  final String? cover;
  final String detailUrl;

  const VideoItem({required this.id, required this.title, this.cover, required this.detailUrl});
}

class VideoEpisode {
  final String id;
  final String title;
  final int index;
  final String playUrl;

  const VideoEpisode({required this.id, required this.title, required this.index, required this.playUrl});
}

abstract class VideoSource {
  String get id;
  String get name;
  String get baseUrl;
  Future<List<VideoItem>> search(String keyword);
  Future<List<VideoEpisode>> episodes(String detailUrl);
}
```

- [ ] **Step 4: Create `lib/core/video/agedm_source.dart`**

```dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'video_source.dart';

class AgedmSource implements VideoSource {
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  final Dio _dio;

  AgedmSource({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://www.agedm.io',
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 20),
              headers: {'User-Agent': _ua},
            ));

  @override
  String get id => 'agedm';

  @override
  String get name => 'AGE动漫';

  @override
  String get baseUrl => 'https://www.agedm.io';

  @override
  Future<List<VideoItem>> search(String keyword) async {
    final res = await _dio.get('/search', queryParameters: {'query': keyword});
    return parseSearch(res.data.toString());
  }

  @override
  Future<List<VideoEpisode>> episodes(String detailUrl) async {
    final res = await _dio.get(detailUrl);
    return parseEpisodes(res.data.toString(), baseUrl);
  }

  @visibleForTesting
  static List<VideoItem> parseSearch(String html) {
    final doc = html_parser.parse(html);
    final items = <VideoItem>[];
    for (final a in doc.querySelectorAll('h5.card-title a')) {
      final href = a.attributes['href'] ?? '';
      final title = a.text.trim();
      if (href.isEmpty || title.isEmpty) continue;
      final id = RegExp(r'/detail/(\d+)').firstMatch(href)?.group(1) ?? href;
      items.add(VideoItem(
        id: id,
        title: title,
        cover: _ancestorImg(a),
        detailUrl: _abs(href, 'https://www.agedm.io'),
      ));
    }
    return items;
  }

  @visibleForTesting
  static List<VideoEpisode> parseEpisodes(String html, String base) {
    final doc = html_parser.parse(html);
    final eps = <VideoEpisode>[];
    var i = 0;
    for (final a in doc.querySelectorAll('a[href*="/play/"]')) {
      final href = a.attributes['href'] ?? '';
      if (href.isEmpty) continue;
      final text = a.text.trim();
      eps.add(VideoEpisode(
        id: href,
        title: text.isEmpty ? '第${i + 1}集' : text,
        index: i,
        playUrl: _abs(href, base),
      ));
      i++;
    }
    return eps;
  }

  static String? _ancestorImg(dom.Element a) {
    dom.Element? node = a.parent;
    for (var depth = 0; node != null && depth < 4; depth++) {
      final img = node.querySelector('img');
      final src = img?.attributes['src'] ?? img?.attributes['data-src'];
      if (src != null && src.isNotEmpty) return src;
      node = node.parent;
    }
    return null;
  }

  static String _abs(String url, String base) {
    if (url.startsWith('http')) {
      return url.startsWith('http://') ? url.replaceFirst('http://', 'https://') : url;
    }
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('/')) return '$base$url';
    return '$base/$url';
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/video/agedm_source_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit (only if user asked)**

```bash
git add lib/core/video/video_source.dart lib/core/video/agedm_source.dart test/core/video/agedm_source_test.dart
git commit -m "feat(video): add VideoSource interface and AgedmSource"
```

---

### Task 2: `GimySource`

**Files:**
- Create: `lib/core/video/gimy_source.dart`
- Test: `test/core/video/gimy_source_test.dart`

**Interfaces:**
- Consumes: `VideoSource`, `VideoItem`, `VideoEpisode` (Task 1).
- Produces: `class GimySource implements VideoSource` with `GimySource({Dio? dio})` and static `parseSearch(String html)`, `parseEpisodes(String html, String base)`.

- [ ] **Step 1: Write the failing test**

Create `test/core/video/gimy_source_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/video/gimy_source.dart';

void main() {
  test('parseSearch extracts title and /vod/ detail URL', () {
    const html = '''
    <div class="result">
      <a href="/vod/247676.html">葬送的芙莉莲</a>
    </div>''';

    final items = GimySource.parseSearch(html);
    expect(items, hasLength(1));
    expect(items.first.id, '247676');
    expect(items.first.title, '葬送的芙莉莲');
    expect(items.first.detailUrl, 'https://gimy.tv/vod/247676.html');
  });

  test('parseEpisodes extracts ordered /ep- play links', () {
    const html = '''
    <div class="playlist">
      <a href="/ep-247676-1-1.html">第1集</a>
      <a href="/ep-247676-1-2.html">第2集</a>
    </div>''';

    final eps = GimySource.parseEpisodes(html, 'https://gimy.tv');
    expect(eps, hasLength(2));
    expect(eps[0].index, 0);
    expect(eps[0].playUrl, 'https://gimy.tv/ep-247676-1-1.html');
    expect(eps[1].title, '第2集');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/video/gimy_source_test.dart`
Expected: FAIL — `gimy_source.dart` not found.

- [ ] **Step 3: Create `lib/core/video/gimy_source.dart`**

```dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'video_source.dart';

class GimySource implements VideoSource {
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  final Dio _dio;

  GimySource({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://gimy.tv',
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 20),
              headers: {'User-Agent': _ua},
            ));

  @override
  String get id => 'gimy';

  @override
  String get name => 'gimy';

  @override
  String get baseUrl => 'https://gimy.tv';

  @override
  Future<List<VideoItem>> search(String keyword) async {
    final res = await _dio.get('/search/-------------.html', queryParameters: {'wd': keyword});
    return parseSearch(res.data.toString());
  }

  @override
  Future<List<VideoEpisode>> episodes(String detailUrl) async {
    final res = await _dio.get(detailUrl);
    return parseEpisodes(res.data.toString(), baseUrl);
  }

  @visibleForTesting
  static List<VideoItem> parseSearch(String html) {
    final doc = html_parser.parse(html);
    final items = <VideoItem>[];
    for (final a in doc.querySelectorAll('a[href*="/vod/"]')) {
      final href = a.attributes['href'] ?? '';
      final title = a.text.trim();
      if (href.isEmpty || title.isEmpty) continue;
      final id = RegExp(r'/vod/(\d+)').firstMatch(href)?.group(1) ?? href;
      items.add(VideoItem(
        id: id,
        title: title,
        cover: _ancestorImg(a),
        detailUrl: _abs(href, 'https://gimy.tv'),
      ));
    }
    return items;
  }

  @visibleForTesting
  static List<VideoEpisode> parseEpisodes(String html, String base) {
    final doc = html_parser.parse(html);
    final eps = <VideoEpisode>[];
    var i = 0;
    for (final a in doc.querySelectorAll('a[href*="/ep-"]')) {
      final href = a.attributes['href'] ?? '';
      if (href.isEmpty) continue;
      final text = a.text.trim();
      eps.add(VideoEpisode(
        id: href,
        title: text.isEmpty ? '第${i + 1}集' : text,
        index: i,
        playUrl: _abs(href, base),
      ));
      i++;
    }
    return eps;
  }

  static String? _ancestorImg(dom.Element a) {
    dom.Element? node = a.parent;
    for (var depth = 0; node != null && depth < 4; depth++) {
      final img = node.querySelector('img');
      final src = img?.attributes['src'] ?? img?.attributes['data-src'];
      if (src != null && src.isNotEmpty) return src;
      node = node.parent;
    }
    return null;
  }

  static String _abs(String url, String base) {
    if (url.startsWith('http')) {
      return url.startsWith('http://') ? url.replaceFirst('http://', 'https://') : url;
    }
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('/')) return '$base$url';
    return '$base/$url';
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/video/gimy_source_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit (only if user asked)**

```bash
git add lib/core/video/gimy_source.dart test/core/video/gimy_source_test.dart
git commit -m "feat(video): add GimySource"
```

---

### Task 3: Dependencies + `MediaKit` init + `StreamResolver`

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/main.dart`
- Create: `lib/core/video/stream_resolver.dart`

**Interfaces:**
- Produces: `class StreamResolver { Future<String?> resolve(String playPageUrl, {Duration timeout}); }`

- [ ] **Step 1: Add dependencies**

In `pubspec.yaml`, add under `dependencies:`:
```yaml
  flutter_inappwebview: ^6.1.5
  media_kit: ^1.2.0
  media_kit_video: ^1.2.0
  media_kit_libs_windows_video: ^1.0.9
```
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter pub get`
Expected: `Got dependencies!`

- [ ] **Step 2: Initialize MediaKit**

In `lib/main.dart`, add the import and the init call:
```dart
import 'package:media_kit/media_kit.dart';
```
and inside `main()`, after `WidgetsFlutterBinding.ensureInitialized();`:
```dart
  MediaKit.ensureInitialized();
```

- [ ] **Step 3: Create `lib/core/video/stream_resolver.dart`**

```dart
import 'dart:async';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class StreamResolver {
  static final _mediaRe = RegExp(r'\.(m3u8|mp4)(\?|$)', caseSensitive: false);

  Future<String?> resolve(
    String playPageUrl, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final completer = Completer<String?>();
    HeadlessInAppWebView? webView;

    void finish(String? url) {
      if (!completer.isCompleted) completer.complete(url);
    }

    try {
      webView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(playPageUrl)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          useShouldInterceptRequest: true,
          mediaPlaybackRequiresUserGesture: false,
        ),
        onWebViewCreated: (controller) {
          controller.addJavaScriptHandler(
            handlerName: 'stream',
            callback: (args) {
              if (args.isNotEmpty) finish(args.first.toString());
              return null;
            },
          );
        },
        shouldInterceptRequest: (controller, request) async {
          final url = request.url.toString();
          if (_mediaRe.hasMatch(url)) finish(url);
          return null;
        },
        onLoadStop: (controller, url) async {
          await controller.evaluateJavascript(source: _hookJs);
        },
      );
      await webView.run();
      return await completer.future.timeout(timeout, onTimeout: () => null);
    } catch (_) {
      return null;
    } finally {
      try {
        await webView?.dispose();
      } catch (_) {}
    }
  }

  static const _hookJs = r'''
  (function(){
    if (window.__streamHooked) return; window.__streamHooked = true;
    function report(u){ try{ if(u && /\.(m3u8|mp4)(\?|$)/i.test(u)){ window.flutter_inappwebview.callHandler('stream', u); } }catch(e){} }
    var oo = XMLHttpRequest.prototype.open;
    XMLHttpRequest.prototype.open = function(m,u){ report(u); return oo.apply(this, arguments); };
    var of = window.fetch;
    if (of) { window.fetch = function(i){ report(typeof i === 'string' ? i : (i && i.url)); return of.apply(this, arguments); }; }
    setInterval(function(){ document.querySelectorAll('video').forEach(function(v){ if(v.src) report(v.src); if(v.currentSrc) report(v.currentSrc); }); }, 1000);
  })();
  ''';
}
```

- [ ] **Step 4: Verify build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib`
Expected: `No issues found!`
Then: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug`
Expected: `Built build\windows\x64\runner\Debug\acgnhub.exe` (this downloads the mpv/ANGLE binaries; may take a few minutes).

- [ ] **Step 5: Commit (only if user asked)**

```bash
git add pubspec.yaml pubspec.lock lib/main.dart lib/core/video/stream_resolver.dart
git commit -m "feat(video): add webview stream resolver and media_kit deps"
```

---

### Task 4: `VideoPlayerPage`

**Files:**
- Create: `lib/modules/anime/video_player_page.dart`

**Interfaces:**
- Consumes: `media_kit`.
- Produces: `class VideoPlayerPage extends StatefulWidget { const VideoPlayerPage({super.key, required this.title, required this.streamUrl}); final String title; final String streamUrl; }`

- [ ] **Step 1: Create `lib/modules/anime/video_player_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class VideoPlayerPage extends StatefulWidget {
  final String title;
  final String streamUrl;

  const VideoPlayerPage({super.key, required this.title, required this.streamUrl});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late final Player _player;
  late final VideoController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _player.stream.error.listen((e) {
      if (mounted) setState(() => _error = e);
    });
    _player.open(Media(widget.streamUrl));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Center(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text('播放失败：$_error', style: const TextStyle(color: Colors.white70)),
              )
            : Video(controller: _controller),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib`
Expected: `No issues found!`

- [ ] **Step 3: Commit (only if user asked)**

```bash
git add lib/modules/anime/video_player_page.dart
git commit -m "feat(video): add media_kit player page"
```

---

### Task 5: Detail-page playback section

**Files:**
- Modify: `lib/modules/anime/anime_detail_page.dart`

**Interfaces:**
- Consumes: `AgedmSource`, `GimySource`, `VideoSource`, `VideoItem`, `VideoEpisode` (Tasks 1–2); `StreamResolver` (Task 3); `VideoPlayerPage` (Task 4).

- [ ] **Step 1: Replace the `_playSection` method**

In `lib/modules/anime/anime_detail_page.dart`, add these imports:
```dart
import '../../core/video/agedm_source.dart';
import '../../core/video/gimy_source.dart';
import '../../core/video/stream_resolver.dart';
import '../../core/video/video_source.dart';
import 'video_player_page.dart';
```

Replace the existing `_playSection` method with a stateful playback UI. Add these fields to `_AnimeDetailPageState`:
```dart
  final List<VideoSource> _sources = [AgedmSource(), GimySource()];
  int _sourceIndex = 0;
  List<VideoItem>? _videoResults;
  List<VideoEpisode>? _videoEpisodes;
  bool _videoLoading = false;
  String? _videoError;
```

Replace `_playSection(Work w, ColorScheme cs)` with:
```dart
  Widget _playSection(Work w, ColorScheme cs) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('播放源', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (var i = 0; i < _sources.length; i++)
                      ChoiceChip(
                        label: Text(_sources[i].name),
                        selected: _sourceIndex == i,
                        onSelected: (_) {
                          setState(() {
                            _sourceIndex = i;
                            _videoResults = null;
                            _videoEpisodes = null;
                            _videoError = null;
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_videoLoading)
                  const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)))
                else if (_videoError != null)
                  Text(_videoError!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))
                else if (_videoEpisodes != null)
                  _episodeGrid(cs)
                else if (_videoResults != null)
                  _resultList(cs)
                else
                  OutlinedButton.icon(
                    onPressed: () => _searchVideos(w),
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('搜索播放资源'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultList(ColorScheme cs) {
    final results = _videoResults!;
    if (results.isEmpty) {
      return Text('未找到资源', style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.5)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in results)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _loadEpisodes(item),
          ),
      ],
    );
  }

  Widget _episodeGrid(ColorScheme cs) {
    final eps = _videoEpisodes!;
    if (eps.isEmpty) {
      return Text('暂无剧集', style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.5)));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final ep in eps)
          ActionChip(
            label: Text(ep.title, style: const TextStyle(fontSize: 12)),
            onPressed: () => _playEpisode(ep),
          ),
      ],
    );
  }

  Future<void> _searchVideos(Work w) async {
    setState(() {
      _videoLoading = true;
      _videoError = null;
      _videoResults = null;
      _videoEpisodes = null;
    });
    try {
      final results = await _sources[_sourceIndex].search(w.title);
      if (!mounted) return;
      setState(() {
        _videoResults = results;
        _videoLoading = false;
        if (results.isEmpty) _videoError = '未找到资源';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _videoLoading = false;
        _videoError = '搜索失败：$e';
      });
    }
  }

  Future<void> _loadEpisodes(VideoItem item) async {
    setState(() {
      _videoLoading = true;
      _videoError = null;
    });
    try {
      final eps = await _sources[_sourceIndex].episodes(item.detailUrl);
      if (!mounted) return;
      setState(() {
        _videoEpisodes = eps;
        _videoLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _videoLoading = false;
        _videoError = '获取剧集失败：$e';
      });
    }
  }

  Future<void> _playEpisode(VideoEpisode ep) async {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final url = await StreamResolver().resolve(ep.playUrl);
    if (!mounted) return;
    Navigator.of(context).pop(); // close the loading dialog
    if (url == null) {
      messenger.showSnackBar(const SnackBar(content: Text('无法解析播放地址')));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VideoPlayerPage(title: _work.title, streamUrl: url)),
    );
  }
```

- [ ] **Step 2: Verify build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib`
Expected: `No issues found!`

- [ ] **Step 3: Commit (only if user asked)**

```bash
git add lib/modules/anime/anime_detail_page.dart
git commit -m "feat(anime): add playback source section to the detail page"
```

---

### Task 6: Final verification

**Files:** none (verification only).

- [ ] **Step 1: Analyze**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

- [ ] **Step 2: Run the full test suite**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: all tests pass.

- [ ] **Step 3: Build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug`
Expected: `Built build\windows\x64\runner\Debug\acgnhub.exe`.

- [ ] **Step 4: Smoke-run (manual)**

Run: `flutter run -d windows`
Expected: open an anime detail page → 播放源 section → pick AGE动漫 → 搜索播放资源 → select the result → an episode grid appears → tap an episode → a loading dialog → the player opens and plays. If the webview capture or Windows webview plugin misbehaves, record the exact error.

---

## Self-Review

- **Spec coverage:** `VideoSource` + models (§3) → Task 1; agedm rules (§4.1) → Task 1; gimy rules (§4.2) → Task 2; stream resolver + deps + MediaKit init (§5, §8) → Task 3; player (§6) → Task 4; detail integration (§7) → Task 5; tests (§9) → Tasks 1–2, 6. All spec sections covered.
- **Placeholders:** none.
- **Type consistency:** `VideoItem{id,title,cover,detailUrl}`, `VideoEpisode{id,title,index,playUrl}`, `VideoSource{id,name,baseUrl,search,episodes}`, `AgedmSource({Dio?})`/`GimySource({Dio?})`, `StreamResolver().resolve(url)`, `VideoPlayerPage({title, streamUrl})` are consistent across tasks.
