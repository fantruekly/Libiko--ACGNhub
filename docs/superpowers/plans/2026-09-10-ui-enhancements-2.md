# UI Enhancements 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Frosted larger detail tags, in-player episode selection, and a hero transition from home cards into the detail page.

**Architecture:** Detail tags become blurred translucent pills. `VideoPlayerPage` takes the episode list + index, resolves each episode on demand, and exposes an episode-list button in the media_kit desktop controls that opens a dark glass side panel. The card cover and the detail cover share a `Hero` tag for a smooth expand transition.

**Tech Stack:** Flutter 3.35, `dart:ui` `BackdropFilter`/`ImageFilter`, `media_kit_video` desktop controls, `Hero`.

## Global Constraints

- Target platform: Windows first; light theme; accent `#007AFF`.
- Tag text `#3A3A3C` (not blue); tags larger + frosted.
- Episode panel: dark translucent glass, white text, accent highlight; matches the player.
- Hero tag: `work_<id>` on both the card cover and the detail cover.
- Commits: only run `git commit` steps if the user explicitly asks; otherwise treat them as checkpoints.

---

### Task 1: Frosted, larger detail tags

**Files:**
- Modify: `lib/modules/anime/anime_detail_page.dart`

**Interfaces:**
- Produces: `_tagsRow` renders frosted pills; no public interface change.

- [ ] **Step 1: Add the `dart:ui` import**

At the top of `lib/modules/anime/anime_detail_page.dart`, add:
```dart
import 'dart:ui';
```

- [ ] **Step 2: Replace `_tagsRow`**

Replace the `_tagsRow` method with:
```dart
  Widget _tagsRow(List<String> tags) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags
              .map((t) => ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 0.5),
                        ),
                        child: Text(
                          t,
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF3A3A3C), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
```

- [ ] **Step 3: Verify**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib`
Expected: `No issues found!`

- [ ] **Step 4: Commit (only if user asked)**

```bash
git add lib/modules/anime/anime_detail_page.dart
git commit -m "feat(ui): larger frosted detail tags with dark text"
```

---

### Task 2: In-player episode selection

**Files:**
- Modify: `lib/modules/anime/video_player_page.dart`
- Modify: `lib/modules/anime/anime_detail_page.dart`

**Interfaces:**
- Consumes: `VideoEpisode` (`lib/core/video/video_source.dart`), `StreamResolver` (`lib/core/video/stream_resolver.dart`).
- Produces: `class VideoPlayerPage extends StatefulWidget { final String title; final List<VideoEpisode> episodes; final int initialIndex; const VideoPlayerPage({super.key, required this.title, required this.episodes, required this.initialIndex}); }`

- [ ] **Step 1: Rewrite `lib/modules/anime/video_player_page.dart`**

```dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../core/video/stream_resolver.dart';
import '../../core/video/video_source.dart';

class VideoPlayerPage extends StatefulWidget {
  final String title;
  final List<VideoEpisode> episodes;
  final int initialIndex;

  const VideoPlayerPage({
    super.key,
    required this.title,
    required this.episodes,
    required this.initialIndex,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late final Player _player;
  late final VideoController _controller;
  String? _error;
  int _currentIndex = 0;
  bool _panelOpen = false;
  bool _resolving = false;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _player.stream.error.listen((e) {
      if (mounted) setState(() => _error = e);
    });
    _currentIndex = widget.initialIndex.clamp(0, widget.episodes.length - 1);
    _playIndex(_currentIndex);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _playIndex(int i) async {
    if (_resolving) return;
    if (i < 0 || i >= widget.episodes.length) return;
    final gen = ++_gen;
    setState(() {
      _resolving = true;
      _error = null;
      _currentIndex = i;
    });
    final url = await StreamResolver().resolve(widget.episodes[i].playUrl);
    if (!mounted || gen != _gen) return;
    setState(() => _resolving = false);
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('无法解析播放地址')));
      return;
    }
    await _player.open(Media(url));
  }

  MaterialDesktopVideoControlsThemeData _controlsTheme(BuildContext context) {
    return MaterialDesktopVideoControlsThemeData(
      controlsHoverDuration: const Duration(seconds: 3),
      topButtonBar: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          tooltip: '返回',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, height: 1.3),
          ),
        ),
        const SizedBox(width: 12),
      ],
      bottomButtonBar: [
        const MaterialDesktopSkipPreviousButton(),
        const MaterialDesktopPlayOrPauseButton(),
        const MaterialDesktopSkipNextButton(),
        const MaterialDesktopVolumeButton(),
        const MaterialDesktopPositionIndicator(),
        const Spacer(),
        MaterialDesktopCustomButton(
          icon: const Icon(Icons.list_rounded),
          onPressed: () => setState(() => _panelOpen = !_panelOpen),
        ),
        const MaterialDesktopFullscreenButton(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: MaterialDesktopVideoControlsTheme(
              normal: _controlsTheme(context),
              fullscreen: _controlsTheme(context),
              child: Video(
                controller: _controller,
                fit: BoxFit.contain,
                fill: Colors.black,
                controls: MaterialDesktopVideoControls,
              ),
            ),
          ),
          if (_resolving)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x99000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          if (_error != null)
            Positioned(
              top: 64,
              left: 0,
              right: 0,
              child: Center(
                child: Text('播放失败：$_error', style: const TextStyle(color: Colors.white70)),
              ),
            ),
          if (_panelOpen) _episodePanel(),
        ],
      ),
    );
  }

  Widget _episodePanel() {
    return Positioned(
      top: 0,
      bottom: 0,
      right: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: 220,
            color: const Color(0xCC000000),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text('选集', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      itemCount: widget.episodes.length,
                      itemBuilder: (context, i) {
                        final ep = widget.episodes[i];
                        final selected = i == _currentIndex;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                setState(() => _panelOpen = false);
                                _playIndex(i);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: selected ? const Color(0x33007AFF) : Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selected ? const Color(0x99007AFF) : Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Text(
                                  ep.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: selected ? const Color(0xFF4DA3FF) : Colors.white,
                                    fontSize: 13,
                                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Update the detail page's `_playEpisode`**

In `lib/modules/anime/anime_detail_page.dart`, replace `_playEpisode` with:
```dart
  void _playEpisode(VideoEpisode ep) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerPage(
          title: _work.title,
          episodes: _videoEpisodes ?? const [],
          initialIndex: ep.index,
        ),
      ),
    );
  }
```
(The player now resolves the stream itself, so the detail page no longer resolves or shows a dialog.)

- [ ] **Step 3: Verify**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib`
Expected: `No issues found!`

- [ ] **Step 4: Commit (only if user asked)**

```bash
git add lib/modules/anime/video_player_page.dart lib/modules/anime/anime_detail_page.dart
git commit -m "feat(video): in-player episode selection panel"
```

---

### Task 3: Home → detail hero transition

**Files:**
- Modify: `lib/core/widgets/work_card.dart`
- Modify: `lib/modules/anime/anime_detail_page.dart`

**Interfaces:**
- Produces: `Hero(tag: 'work_${work.id}', ...)` on the card cover and the detail cover.

- [ ] **Step 1: Wrap the card cover in a `Hero`**

In `lib/core/widgets/work_card.dart`, wrap the cover's `ClipRRect` in a `Hero`:
```dart
          Expanded(
            child: Hero(
              tag: 'work_${work.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: work.coverUrl != null && work.coverUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: work.coverUrl!,
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 200),
                        placeholder: (_, __) => _placeholder(work),
                        errorWidget: (_, __, ___) => _placeholder(work),
                      )
                    : _placeholder(work),
              ),
            ),
          ),
```

- [ ] **Step 2: Wrap the detail cover in a `Hero`**

In `lib/modules/anime/anime_detail_page.dart`, in `_infoSection`, wrap the cover `ClipRRect` in a `Hero` with the same tag:
```dart
            Hero(
              tag: 'work_${w.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 110,
                  height: 154,
                  child: w.coverUrl != null && w.coverUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: w.coverUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _coverPlaceholder(cs),
                        )
                      : _coverPlaceholder(cs),
                ),
              ),
            ),
```

- [ ] **Step 3: Verify**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib`
Expected: `No issues found!`

- [ ] **Step 4: Commit (only if user asked)**

```bash
git add lib/core/widgets/work_card.dart lib/modules/anime/anime_detail_page.dart
git commit -m "feat(ui): hero transition from home card to detail cover"
```

---

### Task 4: Final verification

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
Expected: detail tags are larger/frosted with dark text; the player's episode button opens a scrollable panel and switching episodes plays them; tapping a home card smoothly expands its cover into the detail page.

---

## Self-Review

- **Spec coverage:** frosted tags (§2) → Task 1; episode interface/flow/panel (§3) → Task 2; hero transition (§4) → Task 3; testing (§6) → Task 4. All spec sections covered.
- **Placeholders:** none.
- **Type consistency:** `VideoPlayerPage({title, episodes, initialIndex})`, `VideoEpisode{id,title,index,playUrl}`, `Hero(tag: 'work_<id>')`, `_playIndex(int)`, `_episodePanel()` are consistent across tasks.
