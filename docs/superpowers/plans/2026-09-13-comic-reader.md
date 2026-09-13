# Comic Reader Implementation Plan (C2b)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the comic reader — continuous vertical scroll (default) and horizontal page flip, with zoom, preloading, cross-chapter navigation, auto-hiding chrome, and reading-history recording — and wire it to the detail page and the home history tab.

**Architecture:** A new `ComicReaderPage` (`lib/modules/comic/`) consumes the C2a providers (`comicEpProvider`, `comicDetailProvider`, `comicImageProvider`) and a new pure-Dart navigation module (`lib/core/comic/reader_nav.dart`). A small persisted settings store (`lib/core/comic/comic_reader_settings.dart`) holds the reading mode. The detail page's chapter buttons / 继续阅读 and the home history rows are rewired from placeholders to the reader.

**Tech Stack:** Flutter 3.35, Dart 3, Riverpod 2, `cached_network_image` (via C1's `ComicImageProvider`), `window_manager`, `shared_preferences` (`AppDatabase`). C1 (`lib/core/comic/`) and C2a (`lib/modules/comic/`) are already implemented.

## Global Constraints

- The reader lives in `lib/modules/comic/comic_reader_page.dart`; pure reader maths in `lib/core/comic/reader_nav.dart`; reader settings in `lib/core/comic/comic_reader_settings.dart`.
- Default mode is `ComicReaderMode.continuousVertical`.
- Design tokens: accent `#007AFF`, muted `#8E8E93`, border `#E5E5EA`, fg `#1C1C1E`, surface `#FFFFFF`. The reader's page background is black.
- Out of scope (design §12): right-to-left page flip, webtoon gap trimming, double-spread rules, downloading/offline chapters, danmaku, comments, network favorites, account/WebView login, backend sync of comic favorites/history, AES-requiring sources. Do NOT build any of these.
- Any provider that calls the C1 engine must catch and surface errors (never an unhandled exception), because the engine runs third-party JS.
- No code comments unless the surrounding file already has them (C1 core files already do; the module UI files do not).
- The reader's chapter/page maths is unit-tested (pure Dart). The reader widget itself is verified by `flutter analyze` and `flutter build windows --debug`; do NOT add widget tests for it.
- Flutter commands run with `$env:Path = "C:\flutter\bin;$env:Path";` prefixed.
- Commit after every task and push to `origin/dev`.

---

### Task 1: `ComicReaderSettings` + provider

**Files:**
- Create: `lib/core/comic/comic_reader_settings.dart`
- Modify: `lib/modules/comic/comic_providers.dart` (add the provider)
- Test: `test/core/comic/comic_reader_settings_test.dart`

**Interfaces:**
- Consumes: `AppDatabase` (`lib/core/storage/database.dart`).
- Produces: `enum ComicReaderMode { continuousVertical, pageHorizontal }`; `class ComicReaderSettings { final ComicReaderMode mode; const ComicReaderSettings({this.mode = ComicReaderMode.continuousVertical}); factory ComicReaderSettings.fromJson(Map<String, dynamic> json); Map<String, dynamic> toJson(); ComicReaderSettings copyWith({ComicReaderMode? mode}); }`; `class ComicReaderSettingsManager { ComicReaderSettings read(); Future<void> write(ComicReaderSettings settings); }`; `final comicReaderSettingsProvider = NotifierProvider<ComicReaderSettingsNotifier, ComicReaderSettings>(...)` with `Future<void> setMode(ComicReaderMode mode)`.

- [ ] **Step 1: Write the failing test**

Create `test/core/comic/comic_reader_settings_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acgnhub/core/comic/comic_reader_settings.dart';
import 'package:acgnhub/core/storage/database.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to continuous vertical', () {
    expect(const ComicReaderSettings().mode,
        ComicReaderMode.continuousVertical);
  });

  test('JSON round-trips the mode', () {
    const settings = ComicReaderSettings(mode: ComicReaderMode.pageHorizontal);
    final restored = ComicReaderSettings.fromJson(settings.toJson());
    expect(restored.mode, ComicReaderMode.pageHorizontal);
  });

  test('an unknown mode falls back to continuous vertical', () {
    final restored = ComicReaderSettings.fromJson({'mode': 'bogus'});
    expect(restored.mode, ComicReaderMode.continuousVertical);
  });

  test('the manager persists and reads the mode', () async {
    await AppDatabase.init();
    final manager = ComicReaderSettingsManager();
    expect(manager.read().mode, ComicReaderMode.continuousVertical);
    await manager.write(
        const ComicReaderSettings(mode: ComicReaderMode.pageHorizontal));
    expect(manager.read().mode, ComicReaderMode.pageHorizontal);
  });

  test('a malformed stored value falls back to the default', () async {
    await AppDatabase.init();
    await AppDatabase().setString('comic_reader_settings', 'not json');
    expect(ComicReaderSettingsManager().read().mode,
        ComicReaderMode.continuousVertical);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/comic/comic_reader_settings_test.dart`
Expected: FAIL — `comic_reader_settings.dart` not found.

- [ ] **Step 3: Create `lib/core/comic/comic_reader_settings.dart`**

```dart
import 'dart:convert';

import '../storage/database.dart';

enum ComicReaderMode { continuousVertical, pageHorizontal }

class ComicReaderSettings {
  final ComicReaderMode mode;

  const ComicReaderSettings({this.mode = ComicReaderMode.continuousVertical});

  factory ComicReaderSettings.fromJson(Map<String, dynamic> json) =>
      ComicReaderSettings(
        mode: ComicReaderMode.values.firstWhere(
          (m) => m.name == json['mode'],
          orElse: () => ComicReaderMode.continuousVertical,
        ),
      );

  Map<String, dynamic> toJson() => {'mode': mode.name};

  ComicReaderSettings copyWith({ComicReaderMode? mode}) =>
      ComicReaderSettings(mode: mode ?? this.mode);
}

class ComicReaderSettingsManager {
  static const _key = 'comic_reader_settings';

  ComicReaderSettings read() {
    final raw = AppDatabase().getString(_key);
    if (raw == null || raw.isEmpty) return const ComicReaderSettings();
    try {
      return ComicReaderSettings.fromJson(
          json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const ComicReaderSettings();
    }
  }

  Future<void> write(ComicReaderSettings settings) =>
      AppDatabase().setString(_key, json.encode(settings.toJson()));
}
```

- [ ] **Step 4: Add the provider to `lib/modules/comic/comic_providers.dart`**

Add the import:

```dart
import '../../core/comic/comic_reader_settings.dart';
```

Append at the end of the file:

```dart
/// The persisted reader mode (continuous vertical vs. horizontal page flip).
class ComicReaderSettingsNotifier extends Notifier<ComicReaderSettings> {
  final _manager = ComicReaderSettingsManager();

  @override
  ComicReaderSettings build() => _manager.read();

  Future<void> setMode(ComicReaderMode mode) async {
    final next = state.copyWith(mode: mode);
    await _manager.write(next);
    state = next;
  }
}

final comicReaderSettingsProvider =
    NotifierProvider<ComicReaderSettingsNotifier, ComicReaderSettings>(
        ComicReaderSettingsNotifier.new);
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/comic/comic_reader_settings_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 6: Analyze**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`

- [ ] **Step 7: Commit and push**

```bash
git add lib/core/comic/comic_reader_settings.dart lib/modules/comic/comic_providers.dart test/core/comic/comic_reader_settings_test.dart
git commit -m "feat(comic): add the reader settings store"
git push
```

---

### Task 2: Reader navigation maths

**Files:**
- Create: `lib/core/comic/reader_nav.dart`
- Test: `test/core/comic/reader_nav_test.dart`

**Interfaces:**
- Produces: `class ChapterNav { final String? previous; final String? next; const ChapterNav({this.previous, this.next}); }`; `ChapterNav chapterNav(List<String> chapterIds, String currentId)`; `List<int> preloadIndices(int current, int total, {int ahead = 3})`; `int currentPageFromScroll(double pixels, double maxScrollExtent, int total)`.

- [ ] **Step 1: Write the failing test**

Create `test/core/comic/reader_nav_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/comic/reader_nav.dart';

void main() {
  test('chapterNav returns the neighbours in list order', () {
    final nav = chapterNav(['a', 'b', 'c'], 'b');
    expect(nav.previous, 'a');
    expect(nav.next, 'c');
  });

  test('chapterNav clamps at the ends', () {
    expect(chapterNav(['a', 'b'], 'a').previous, isNull);
    expect(chapterNav(['a', 'b'], 'a').next, 'b');
    expect(chapterNav(['a', 'b'], 'b').next, isNull);
  });

  test('chapterNav returns empty for an unknown chapter', () {
    final nav = chapterNav(['a', 'b'], 'z');
    expect(nav.previous, isNull);
    expect(nav.next, isNull);
  });

  test('preloadIndices returns up to three following pages', () {
    expect(preloadIndices(2, 10), [3, 4, 5]);
    expect(preloadIndices(8, 10), [9]);
    expect(preloadIndices(9, 10), isEmpty);
  });

  test('currentPageFromScroll maps the scroll fraction to a page', () {
    expect(currentPageFromScroll(0, 100, 11), 0);
    expect(currentPageFromScroll(100, 100, 11), 10);
    expect(currentPageFromScroll(50, 100, 11), 5);
    expect(currentPageFromScroll(0, 0, 1), 0);
    expect(currentPageFromScroll(10, 0, 5), 0);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/comic/reader_nav_test.dart`
Expected: FAIL — `reader_nav.dart` not found.

- [ ] **Step 3: Create `lib/core/comic/reader_nav.dart`**

```dart
/// The previous/next chapter ids for a chapter within the chapter list.
class ChapterNav {
  final String? previous;
  final String? next;

  const ChapterNav({this.previous, this.next});
}

/// The neighbours of [currentId] in [chapterIds] (insertion order is the
/// reading order). An unknown id yields an empty nav.
ChapterNav chapterNav(List<String> chapterIds, String currentId) {
  final index = chapterIds.indexOf(currentId);
  if (index < 0) return const ChapterNav();
  return ChapterNav(
    previous: index > 0 ? chapterIds[index - 1] : null,
    next: index < chapterIds.length - 1 ? chapterIds[index + 1] : null,
  );
}

/// The indices to precache after [current], up to [ahead] pages and never past
/// the end of the chapter.
List<int> preloadIndices(int current, int total, {int ahead = 3}) {
  final indices = <int>[];
  for (var i = current + 1; i <= current + ahead && i < total; i++) {
    indices.add(i);
  }
  return indices;
}

/// Maps a continuous-scroll offset to the page it is showing, using the scroll
/// fraction as an approximation (comic pages have varying heights).
int currentPageFromScroll(double pixels, double maxScrollExtent, int total) {
  if (total <= 1 || maxScrollExtent <= 0) return 0;
  final fraction = (pixels / maxScrollExtent).clamp(0.0, 1.0);
  return (fraction * (total - 1)).round();
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/comic/reader_nav_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Analyze**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`

- [ ] **Step 6: Commit and push**

```bash
git add lib/core/comic/reader_nav.dart test/core/comic/reader_nav_test.dart
git commit -m "feat(comic): add the reader navigation maths"
git push
```

---

### Task 3: `ComicReaderPage` (continuous vertical) + wiring

**Files:**
- Create: `lib/modules/comic/comic_reader_page.dart`
- Modify: `lib/modules/comic/comic_detail_page.dart` (chapter buttons + 继续阅读)
- Modify: `lib/modules/comic/comic_home.dart` (history row)

**Interfaces:**
- Consumes: `comicEpProvider` (`FutureProvider.family<ComicEp, (String, String, String)>`), `comicDetailProvider` (`FutureProvider.family<ComicDetails, (String, String)>`), `comicImageProvider` (`Provider<ComicImageProvider>`), `comicHistoryProvider`, `ComicImageProvider.resolve(sourceKey, comicId, chapterId, url)`, `ChapterNav`/`chapterNav`/`preloadIndices`/`currentPageFromScroll` (Task 2), `WindowControls`, `smoothRoute`.
- Produces: `class ComicReaderPage extends ConsumerStatefulWidget { final String sourceKey; final String comicId; final String chapterId; final int initialPage; }` (continuous mode only at this task; Task 4 adds page flip).

- [ ] **Step 1: Create `lib/modules/comic/comic_reader_page.dart`**

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/comic/comic_history.dart';
import '../../core/comic/comic_image.dart';
import '../../core/comic/models.dart';
import '../../core/comic/reader_nav.dart';
import '../../core/widgets/window_controls.dart';
import 'comic_providers.dart';

const _muted = Color(0xFF8E8E93);

class ComicReaderPage extends ConsumerStatefulWidget {
  final String sourceKey;
  final String comicId;
  final String chapterId;
  final int initialPage;

  const ComicReaderPage({
    super.key,
    required this.sourceKey,
    required this.comicId,
    required this.chapterId,
    this.initialPage = 0,
  });

  @override
  ConsumerState<ComicReaderPage> createState() => _ComicReaderPageState();
}

class _ComicReaderPageState extends ConsumerState<ComicReaderPage> {
  late String _chapterId;
  late int _page;
  bool _chromeVisible = true;
  bool _switchingChapter = false;
  bool _initialJumpDone = false;
  Timer? _chromeTimer;
  Timer? _historyTimer;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _chapterId = widget.chapterId;
    _page = widget.initialPage;
    _showChrome();
  }

  @override
  void dispose() {
    _chromeTimer?.cancel();
    _historyTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final epAsync = ref.watch(
        comicEpProvider((widget.sourceKey, widget.comicId, _chapterId)));
    final details =
        ref.watch(comicDetailProvider((widget.sourceKey, widget.comicId)))
            .valueOrNull;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: epAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: Colors.white54)),
              error: (_, __) => _chapterError(),
              data: (ep) => _continuous(ep, details),
            ),
          ),
          if (_chromeVisible) _topBar(details),
          if (_chromeVisible) _bottomBar(epAsync.valueOrNull, details),
        ],
      ),
    );
  }

  Widget _continuous(ComicEp ep, ComicDetails? details) {
    final images = ep.images;
    if (images.isEmpty) {
      return const Center(
          child: Text('本章暂无图片', style: TextStyle(color: Colors.white70)));
    }
    if (!_initialJumpDone) {
      _initialJumpDone = true;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _jumpToInitial(images.length));
    }
    final nav = _nav(details);
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is! ScrollUpdateNotification &&
            notification is! ScrollEndNotification) {
          return false;
        }
        final metrics = notification.metrics;
        final page = currentPageFromScroll(
            metrics.pixels, metrics.maxScrollExtent, images.length);
        _onPageChanged(page, images.length);
        if (metrics.maxScrollExtent > 0 &&
            metrics.pixels >= metrics.maxScrollExtent - 8 &&
            nav.next != null) {
          _goToChapter(nav.next!);
        } else if (metrics.pixels <= 8 &&
            _page == 0 &&
            nav.previous != null) {
          _goToChapter(nav.previous!);
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        itemCount: images.length,
        itemBuilder: (context, i) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleChrome,
          child: _ReaderImage(
            key: ValueKey('$_chapterId-$i'),
            sourceKey: widget.sourceKey,
            comicId: widget.comicId,
            chapterId: _chapterId,
            url: images[i],
          ),
        ),
      ),
    );
  }

  void _jumpToInitial(int total) {
    if (!mounted || !_scrollController.hasClients) return;
    if (_page <= 0 || total <= 1) return;
    final max = _scrollController.position.maxScrollExtent;
    final target = (_page / (total - 1)) * max;
    _scrollController.jumpTo(target.clamp(0.0, max));
  }

  Widget _topBar(ComicDetails? details) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: DragToMoveArea(
        child: Container(
          height: 48,
          padding: const EdgeInsets.only(left: 4),
          decoration: const BoxDecoration(
            color: Color(0xFFFFFFFF),
            border: Border(
                bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
                splashRadius: 20,
              ),
              Expanded(
                child: Text(
                  details?.title ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C1C1E)),
                ),
              ),
              const WindowControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(ComicEp? ep, ComicDetails? details) {
    final total = ep?.images.length ?? 0;
    final chapterTitle = details?.chapters[_chapterId] ?? '';
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: const BoxDecoration(
          color: Color(0xFFFFFFFF),
          border:
              Border(top: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
        ),
        child: Row(
          children: [
            TextButton.icon(
              onPressed: () => _openChapterList(details),
              icon: const Icon(Icons.list_rounded, size: 18),
              label: const Text('目录'),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                chapterTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: _muted),
              ),
            ),
            const Spacer(),
            Text(
              '${total == 0 ? 0 : _page + 1} / $total',
              style: const TextStyle(fontSize: 13, color: _muted),
            ),
          ],
        ),
      ),
    );
  }

  void _openChapterList(ComicDetails? details) {
    final chapters = details?.chapters.entries.toList() ?? const [];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFFFFFFFF),
      builder: (ctx) => ListView.builder(
        itemCount: chapters.length,
        itemBuilder: (_, i) {
          final entry = chapters[i];
          return ListTile(
            title: Text(entry.value),
            selected: entry.key == _chapterId,
            selectedColor: const Color(0xFF007AFF),
            onTap: () {
              Navigator.pop(ctx);
              _goToChapter(entry.key);
            },
          );
        },
      ),
    );
  }

  void _toggleChrome() {
    _chromeTimer?.cancel();
    setState(() => _chromeVisible = !_chromeVisible);
    if (_chromeVisible) _showChrome();
  }

  void _showChrome() {
    _chromeTimer?.cancel();
    if (!_chromeVisible) setState(() => _chromeVisible = true);
    _chromeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _chromeVisible = false);
    });
  }

  ChapterNav _nav(ComicDetails? details) {
    final ids = details?.chapters.keys.toList() ?? const <String>[];
    return chapterNav(ids, _chapterId);
  }

  void _goToChapter(String chapterId) {
    if (_switchingChapter || chapterId == _chapterId) return;
    _switchingChapter = true;
    setState(() {
      _chapterId = chapterId;
      _page = 0;
    });
    _recordHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
      _switchingChapter = false;
    });
  }

  void _onPageChanged(int page, int total) {
    if (page == _page) return;
    setState(() => _page = page);
    _historyTimer?.cancel();
    _historyTimer = Timer(const Duration(seconds: 1), _recordHistory);
    _preload(page, total);
  }

  void _recordHistory() {
    final details =
        ref.read(comicDetailProvider((widget.sourceKey, widget.comicId)))
            .valueOrNull;
    final chapterTitle = details?.chapters[_chapterId] ?? _chapterId;
    ref.read(comicHistoryProvider.notifier).record(ComicHistoryEntry(
          sourceKey: widget.sourceKey,
          comicId: widget.comicId,
          title: details?.title ?? '',
          cover: details?.cover,
          chapterId: _chapterId,
          chapterTitle: chapterTitle,
          page: _page,
          readAt: DateTime.now(),
        ));
  }

  Future<void> _preload(int page, int total) async {
    final images = ref
        .read(comicEpProvider(
            (widget.sourceKey, widget.comicId, _chapterId)))
        .valueOrNull
        ?.images;
    if (images == null) return;
    final imageProvider = ref.read(comicImageProvider);
    for (final index in preloadIndices(page, total)) {
      try {
        final provider = await imageProvider.resolve(
            widget.sourceKey, widget.comicId, _chapterId, images[index]);
        if (!mounted) return;
        await precacheImage(provider, context);
      } catch (_) {
        // A preload failure must not disturb reading.
      }
    }
    final details =
        ref.read(comicDetailProvider((widget.sourceKey, widget.comicId)))
            .valueOrNull;
    final nav = _nav(details);
    if (nav.next == null) return;
    try {
      final nextEp = await ref
          .read(comicEpProvider(
              (widget.sourceKey, widget.comicId, nav.next!)))
          .future;
      if (nextEp.images.isEmpty || !mounted) return;
      final provider = await imageProvider.resolve(
          widget.sourceKey, widget.comicId, nav.next!, nextEp.images.first);
      if (mounted) await precacheImage(provider, context);
    } catch (_) {
      // A preload failure must not disturb reading.
    }
  }

  Widget _chapterError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.white54, size: 40),
          const SizedBox(height: 12),
          const Text('章节加载失败', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => ref.invalidate(comicEpProvider(
                (widget.sourceKey, widget.comicId, _chapterId))),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

class _ReaderImage extends ConsumerStatefulWidget {
  final String sourceKey;
  final String comicId;
  final String chapterId;
  final String url;

  const _ReaderImage({
    super.key,
    required this.sourceKey,
    required this.comicId,
    required this.chapterId,
    required this.url,
  });

  @override
  ConsumerState<_ReaderImage> createState() => _ReaderImageState();
}

class _ReaderImageState extends ConsumerState<_ReaderImage> {
  late Future<ImageProvider> _future;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _ReaderImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.chapterId != widget.chapterId) {
      _resolve();
    }
  }

  void _resolve() {
    _future = ref.read(comicImageProvider).resolve(
        widget.sourceKey, widget.comicId, widget.chapterId, widget.url);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ImageProvider>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _retry();
        if (!snapshot.hasData) return _loading();
        return Image(
          image: snapshot.data!,
          fit: BoxFit.contain,
          width: double.infinity,
          errorBuilder: (_, __, ___) => _retry(),
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : _loading(),
        );
      },
    );
  }

  Widget _loading() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: CircularProgressIndicator(color: Colors.white38)),
    );
  }

  Widget _retry() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined,
                color: Colors.white54, size: 36),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(_resolve),
              child: const Text('重试', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Wire the detail page to the reader**

In `lib/modules/comic/comic_detail_page.dart`:

Add imports:

```dart
import '../../core/widgets/smooth_route.dart';
import 'comic_reader_page.dart';
```

In `_content`, replace the 继续阅读 sliver so the entry is available:

```dart
  Widget _content(ComicDetails details) {
    final history = _historyEntry();
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _infoCard(details)),
        SliverToBoxAdapter(child: _chapterSection(details)),
        if (history != null)
          SliverToBoxAdapter(child: _continueReading(history)),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
```

In `_chapterSection`, pass the chapter id as well as the title:

```dart
                  for (final chapter in chapters)
                    _chapterButton(chapter.key, chapter.value),
```

Replace `_chapterButton` with:

```dart
  Widget _chapterButton(String id, String title) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openReader(id),
        borderRadius: BorderRadius.circular(10),
        hoverColor: const Color(0x1F007AFF),
        child: Container(
          width: 104,
          height: 44,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0x0F007AFF),
            border: Border.all(color: const Color(0x4D007AFF)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: _accent),
          ),
        ),
      ),
    );
  }
```

Replace `_continueReading` with a version that resumes at the recorded chapter and page:

```dart
  Widget _continueReading(ComicHistoryEntry entry) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            backgroundColor: _accent,
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => _openReader(entry.chapterId, entry.page),
          icon: const Icon(Icons.menu_book_rounded, size: 18),
          label: const Text('继续阅读',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
```

Replace `_showReaderPlaceholder` with `_openReader`:

```dart
  void _openReader(String chapterId, [int page = 0]) {
    Navigator.push(
      context,
      smoothRoute(ComicReaderPage(
        sourceKey: widget.sourceKey,
        comicId: widget.comicId,
        chapterId: chapterId,
        initialPage: page,
      )),
    );
  }
```

- [ ] **Step 3: Wire the home history row to the reader**

In `lib/modules/comic/comic_home.dart`:

Add the import:

```dart
import 'comic_reader_page.dart';
```

Replace the `_historyRow` `onTap` (currently pushing `ComicDetailPage`) with a reader push:

```dart
    onTap: () => Navigator.push(
      context,
      smoothRoute(ComicReaderPage(
        sourceKey: entry.sourceKey,
        comicId: entry.comicId,
        chapterId: entry.chapterId,
        initialPage: entry.page,
      )),
    ),
```

- [ ] **Step 4: Analyze and build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug` → built.

- [ ] **Step 5: Commit and push**

```bash
git add lib/modules/comic/comic_reader_page.dart lib/modules/comic/comic_detail_page.dart lib/modules/comic/comic_home.dart
git commit -m "feat(comic): add the continuous reader and wire it up"
git push
```

---

### Task 4: Horizontal page-flip mode + zoom

**Files:**
- Modify: `lib/modules/comic/comic_reader_page.dart`

**Interfaces:**
- Consumes: `comicReaderSettingsProvider`/`ComicReaderMode` (Task 1), `chapterNav` (Task 2).
- Produces: no new public API — adds the page-flip mode, the mode toggle, and double-tap zoom to the existing `ComicReaderPage`.

- [ ] **Step 1: Add the settings import and the page controller**

In `lib/modules/comic/comic_reader_page.dart`, add:

```dart
import '../../core/comic/comic_reader_settings.dart';
```

In `_ComicReaderPageState`, add the page controller field and dispose it. The field list gains:

```dart
  final _scrollController = ScrollController();
  final _pageController = PageController();
```

and `dispose` gains:

```dart
    _pageController.dispose();
```

- [ ] **Step 2: Choose the mode in `build`**

Replace the `build` body with:

```dart
  @override
  Widget build(BuildContext context) {
    final epAsync = ref.watch(
        comicEpProvider((widget.sourceKey, widget.comicId, _chapterId)));
    final details =
        ref.watch(comicDetailProvider((widget.sourceKey, widget.comicId)))
            .valueOrNull;
    final settings = ref.watch(comicReaderSettingsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: epAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: Colors.white54)),
              error: (_, __) => _chapterError(),
              data: (ep) => settings.mode == ComicReaderMode.pageHorizontal
                  ? _horizontal(ep, details)
                  : _continuous(ep, details),
            ),
          ),
          if (_chromeVisible) _topBar(details),
          if (_chromeVisible) _bottomBar(epAsync.valueOrNull, details, settings),
        ],
      ),
    );
  }
```

- [ ] **Step 3: Make `_jumpToInitial` mode-aware**

Replace `_jumpToInitial` with:

```dart
  void _jumpToInitial(int total) {
    if (!mounted) return;
    if (ref.read(comicReaderSettingsProvider).mode ==
        ComicReaderMode.pageHorizontal) {
      if (_pageController.hasClients) _pageController.jumpToPage(_page);
      return;
    }
    if (!_scrollController.hasClients || _page <= 0 || total <= 1) return;
    final max = _scrollController.position.maxScrollExtent;
    final target = (_page / (total - 1)) * max;
    _scrollController.jumpTo(target.clamp(0.0, max));
  }
```

- [ ] **Step 4: Add `_horizontal` and `_ZoomablePage`**

Add `_horizontal` to `_ComicReaderPageState` (after `_continuous`):

```dart
  Widget _horizontal(ComicEp ep, ComicDetails? details) {
    final images = ep.images;
    if (images.isEmpty) {
      return const Center(
          child: Text('本章暂无图片', style: TextStyle(color: Colors.white70)));
    }
    final nav = _nav(details);
    final hasNext = nav.next != null;
    return NotificationListener<OverscrollNotification>(
      onNotification: (notification) {
        if (notification.overscroll < 0 &&
            _page == 0 &&
            nav.previous != null) {
          _goToChapter(nav.previous!);
        }
        return false;
      },
      child: PageView.builder(
        controller: _pageController,
        itemCount: images.length + (hasNext ? 1 : 0),
        onPageChanged: (index) {
          if (index >= images.length) {
            if (hasNext) _goToChapter(nav.next!);
            return;
          }
          _onPageChanged(index, images.length);
        },
        itemBuilder: (context, index) {
          if (index >= images.length) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.white38));
          }
          return _ZoomablePage(
            onTap: _toggleChrome,
            child: _ReaderImage(
              key: ValueKey('$_chapterId-$index'),
              sourceKey: widget.sourceKey,
              comicId: widget.comicId,
              chapterId: _chapterId,
              url: images[index],
            ),
          );
        },
      ),
    );
  }
```

Add the `_ZoomablePage` widget at the end of the file (after `_ReaderImageState`):

```dart
class _ZoomablePage extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _ZoomablePage({required this.child, required this.onTap});

  @override
  State<_ZoomablePage> createState() => _ZoomablePageState();
}

class _ZoomablePageState extends State<_ZoomablePage> {
  final _controller = TransformationController();
  bool _zoomed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    setState(() {
      _zoomed = !_zoomed;
      _controller.value =
          _zoomed ? (Matrix4.identity()..scale(2.5)) : Matrix4.identity();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _controller,
        minScale: 1,
        maxScale: 4,
        child: widget.child,
      ),
    );
  }
}
```

- [ ] **Step 5: Add the mode toggle to the bottom bar and `_toggleMode`**

Replace `_bottomBar` with:

```dart
  Widget _bottomBar(
      ComicEp? ep, ComicDetails? details, ComicReaderSettings settings) {
    final total = ep?.images.length ?? 0;
    final chapterTitle = details?.chapters[_chapterId] ?? '';
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: const BoxDecoration(
          color: Color(0xFFFFFFFF),
          border:
              Border(top: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
        ),
        child: Row(
          children: [
            TextButton.icon(
              onPressed: () => _openChapterList(details),
              icon: const Icon(Icons.list_rounded, size: 18),
              label: const Text('目录'),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                chapterTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: _muted),
              ),
            ),
            const Spacer(),
            Text(
              '${total == 0 ? 0 : _page + 1} / $total',
              style: const TextStyle(fontSize: 13, color: _muted),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: settings.mode == ComicReaderMode.continuousVertical
                  ? '翻页模式'
                  : '连续模式',
              onPressed: _toggleMode,
              icon: Icon(
                settings.mode == ComicReaderMode.continuousVertical
                    ? Icons.swap_horiz_rounded
                    : Icons.swap_vert_rounded,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
```

Add `_toggleMode` to `_ComicReaderPageState` (after `_goToChapter`):

```dart
  void _toggleMode() {
    final current = ref.read(comicReaderSettingsProvider).mode;
    final next = current == ComicReaderMode.continuousVertical
        ? ComicReaderMode.pageHorizontal
        : ComicReaderMode.continuousVertical;
    ref.read(comicReaderSettingsProvider.notifier).setMode(next);
    _initialJumpDone = true;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (next == ComicReaderMode.pageHorizontal) {
        if (_pageController.hasClients) _pageController.jumpToPage(_page);
        return;
      }
      final total = ref
              .read(comicEpProvider(
                  (widget.sourceKey, widget.comicId, _chapterId)))
              .valueOrNull
              ?.images
              .length ??
          0;
      if (_scrollController.hasClients && total > 1) {
        final max = _scrollController.position.maxScrollExtent;
        _scrollController.jumpTo((_page / (total - 1) * max).clamp(0.0, max));
      }
    });
  }
```

- [ ] **Step 6: Also reset the page controller on chapter change**

In `_goToChapter`, extend the post-frame callback so both controllers reset:

```dart
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
      if (_pageController.hasClients) _pageController.jumpToPage(0);
      _switchingChapter = false;
    });
```

- [ ] **Step 7: Analyze and build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug` → built.

- [ ] **Step 8: Commit and push**

```bash
git add lib/modules/comic/comic_reader_page.dart
git commit -m "feat(comic): add the page-flip reader mode and zoom"
git push
```

---

## Self-Review

- **Spec coverage (§7):** loads `loadEp` and resolves via `onImageLoad` → `_ReaderImage`/`ComicImageProvider` (Task 3); modes → Task 3 continuous + Task 4 horizontal; zoom per page (min 1, max 4, double-tap 1.0/2.5) → Task 4 `_ZoomablePage` (page mode only — `InteractiveViewer` around each image in continuous mode would fight vertical scrolling, so continuous mode is plain scroll; noted as the one deliberate simplification); preload next 3 + next chapter's first image → `preloadIndices` + `_preload` (Task 3); cross-chapter (scroll past end / overscroll back, swipe past last page) → `_continuous`/`_horizontal` (Tasks 3–4); auto-hiding chrome + centre tap → `_toggleChrome`/`_showChrome` (Task 3); history on chapter change + throttled page change → `_recordHistory` (Task 3); image retry + chapter error retry → `_ReaderImage._retry`/`_chapterError` (Task 3). Reader settings provider (architecture table) → Task 1.
- **Placeholders:** none — every step shows the actual code.
- **Type consistency:** `ComicReaderMode`/`ComicReaderSettings`/`ComicReaderSettingsManager`/`comicReaderSettingsProvider`; `ChapterNav`/`chapterNav`/`preloadIndices`/`currentPageFromScroll`; `ComicReaderPage({sourceKey, comicId, chapterId, initialPage})` — used consistently across Tasks 1–4 and the wiring in Task 3. `comicEpProvider` family key is the 3-record `(sourceKey, comicId, chapterId)` and `comicDetailProvider` the 2-record `(sourceKey, comicId)`, matching C2a.
- **Out of scope:** right-to-left flip, gap trimming, double-spread, downloads, danmaku, comments, network favorites, backend sync — none appear in any task.
