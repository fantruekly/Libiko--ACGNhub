import 'package:flutter/material.dart';

import 'player_gestures.dart';

class PlayerControlsOverlay extends StatefulWidget {
  final String title;
  final Duration position;
  final Duration duration;
  final bool playing;
  final bool buffering;
  final bool fullscreen;
  final VoidCallback onBack;
  final VoidCallback onTogglePlay;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onToggleEpisodes;

  const PlayerControlsOverlay({
    super.key,
    required this.title,
    required this.position,
    required this.duration,
    required this.playing,
    required this.buffering,
    required this.fullscreen,
    required this.onBack,
    required this.onTogglePlay,
    required this.onSeek,
    required this.onToggleFullscreen,
    required this.onToggleEpisodes,
  });

  @override
  State<PlayerControlsOverlay> createState() => _PlayerControlsOverlayState();
}

class _PlayerControlsOverlayState extends State<PlayerControlsOverlay> {
  Duration? _drag;

  double get _maxMs =>
      widget.duration.inMilliseconds <= 0 ? 1.0 : widget.duration.inMilliseconds.toDouble();

  double get _valueMs {
    final current = _drag ?? widget.position;
    return current.inMilliseconds.clamp(0, _maxMs.toInt()).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x99000000), Color(0x00000000), Color(0xCC000000)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _topBar(),
            const Spacer(),
            _centerButton(),
            const Spacer(),
            _bottomBar(cs),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('player-back'),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            tooltip: '返回',
            onPressed: widget.onBack,
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
                  height: 1.3),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _centerButton() {
    if (widget.buffering) {
      return const SizedBox(
        width: 56,
        height: 56,
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
          ),
        ),
      );
    }
    return IconButton(
      key: const ValueKey('player-center-play'),
      iconSize: 56,
      icon: Icon(
        widget.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
        color: Colors.white,
      ),
      onPressed: widget.onTogglePlay,
    );
  }

  Widget _bottomBar(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                formatDuration(_drag ?? widget.position),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: cs.primary,
                    thumbColor: cs.primary,
                    overlayColor: cs.primary.withValues(alpha: 0.2),
                    inactiveTrackColor: Colors.white24,
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: _valueMs,
                    min: 0,
                    max: _maxMs,
                    onChanged: (value) => setState(
                        () => _drag = Duration(milliseconds: value.round())),
                    onChangeEnd: (value) {
                      final target = Duration(milliseconds: value.round());
                      setState(() => _drag = null);
                      widget.onSeek(target);
                    },
                  ),
                ),
              ),
              Text(
                formatDuration(widget.duration),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                key: const ValueKey('player-episodes'),
                icon: const Icon(Icons.list_rounded, color: Colors.white),
                tooltip: '选集',
                onPressed: widget.onToggleEpisodes,
              ),
              const Spacer(),
              IconButton(
                key: const ValueKey('player-fullscreen'),
                icon: Icon(
                  widget.fullscreen
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  color: Colors.white,
                ),
                tooltip: '全屏',
                onPressed: widget.onToggleFullscreen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
