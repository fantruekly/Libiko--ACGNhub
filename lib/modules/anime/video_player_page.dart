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

  MaterialDesktopVideoControlsThemeData _controlsTheme(BuildContext context) {
    return MaterialDesktopVideoControlsThemeData(
      // Auto-hide the top/bottom bars after 3s of inactivity.
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('播放失败：$_error', style: const TextStyle(color: Colors.white70)),
              ),
            )
          : MaterialDesktopVideoControlsTheme(
              normal: _controlsTheme(context),
              fullscreen: _controlsTheme(context),
              child: Video(
                controller: _controller,
                // Letterbox symmetrically: standard anime sizes have no bars;
                // a mismatched aspect ratio yields equal top/bottom bars.
                fit: BoxFit.contain,
                fill: Colors.black,
                controls: MaterialDesktopVideoControls,
              ),
            ),
    );
  }
}
