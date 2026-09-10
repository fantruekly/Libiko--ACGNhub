### Task 13: Create video player page

**Files:**
- Create: `lib/modules/anime/anime_player.dart`

**Interfaces:**
- Consumes: `media_kit`, `media_kit_video`, `media_kit_libs_windows_video`
- Produces: `AnimePlayerPage` widget with video playback controls

- [ ] **Step 1: Write AnimePlayerPage**

Create `lib/modules/anime/anime_player.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class AnimePlayerPage extends StatefulWidget {
  final String chapterTitle;
  final String videoUrl;

  const AnimePlayerPage({
    super.key,
    required this.chapterTitle,
    required this.videoUrl,
  });

  @override
  State<AnimePlayerPage> createState() => _AnimePlayerPageState();
}

class _AnimePlayerPageState extends State<AnimePlayerPage> {
  late final Player _player;
  late final VideoController _controller;
  bool _isReady = false;
  bool _showControls = true;
  double _playbackSpeed = 1.0;
  final List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      await _player.open(Media(widget.videoUrl));
      setState(() => _isReady = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('鎾斁澶辫触: $e')),
        );
      }
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  void _changeSpeed() {
    final currentIndex = _speeds.indexOf(_playbackSpeed);
    final nextIndex = (currentIndex + 1) % _speeds.length;
    setState(() {
      _playbackSpeed = _speeds[nextIndex];
    });
    _player.setRate(_playbackSpeed);
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
        title: Text(widget.chapterTitle),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            Center(
              child: _isReady
                  ? Video(controller: _controller)
                  : const CircularProgressIndicator(color: Colors.white),
            ),
            if (_showControls && _isReady)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.fast_rewind, color: Colors.white),
                        onPressed: () => _player.seek(
                          _player.state.position - const Duration(seconds: 10),
                        ),
                      ),
                      StreamBuilder(
                        stream: _player.stream.playing,
                        builder: (context, snapshot) {
                          final playing = snapshot.data ?? false;
                          return IconButton(
                            icon: Icon(
                              playing ? Icons.pause_circle : Icons.play_circle,
                              color: Colors.white,
                              size: 48,
                            ),
                            onPressed: () => _player.playOrPause(),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.fast_forward, color: Colors.white),
                        onPressed: () => _player.seek(
                          _player.state.position + const Duration(seconds: 10),
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: _changeSpeed,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white54),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${_playbackSpeed}x',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/modules/anime/anime_player.dart
git commit -m "feat(anime): add video player page with playback controls"
```

---


