import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../core/models/work.dart';
import '../../core/services/watch_history.dart';
import '../../core/video/stream_resolver.dart';
import '../../core/video/video_source.dart';

class VideoPlayerPage extends ConsumerStatefulWidget {
  final Work work;
  final List<VideoEpisode> episodes;
  final int initialIndex;

  const VideoPlayerPage({
    super.key,
    required this.work,
    required this.episodes,
    required this.initialIndex,
  });

  @override
  ConsumerState<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends ConsumerState<VideoPlayerPage> {
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
    if (widget.episodes.isEmpty) return;
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
    final previous = _currentIndex;
    final episode = widget.episodes[i];
    final work = widget.work;
    final history = ref.read(watchHistoryProvider.notifier);
    setState(() {
      _resolving = true;
      _error = null;
      _currentIndex = i;
    });
    final url = await StreamResolver().resolve(episode.playUrl);
    if (!mounted || gen != _gen) return;
    if (url == null) {
      setState(() {
        _resolving = false;
        _currentIndex = previous;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('无法解析播放地址')));
      return;
    }
    setState(() => _resolving = false);
    await _player.open(Media(url));
    if (gen == _gen) history.record(work, episode);
  }

  MaterialDesktopVideoControlsThemeData _controlsTheme(BuildContext context, {bool showEpisodes = true}) {
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
            widget.work.title,
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
        if (showEpisodes)
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
              fullscreen: _controlsTheme(context, showEpisodes: false),
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
              child: IgnorePointer(
                child: Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  ),
                ),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    child: Row(
                      children: [
                        const Text('选集', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                          tooltip: '关闭',
                          onPressed: () => setState(() => _panelOpen = false),
                        ),
                      ],
                    ),
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
