import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/account/sync_service.dart';
import '../../core/models/work.dart';
import '../../core/platform.dart';
import '../../core/services/watch_history.dart';
import '../../core/storage/database.dart';
import '../../core/video/cancellation.dart';
import '../../core/video/headless_browser.dart';
import '../../core/video/playback_error.dart';
import '../../core/video/stream_resolver.dart';
import '../../core/video/video_source.dart';
import 'player_controls.dart';
import 'player_gestures.dart';

class VideoPlayerPage extends ConsumerStatefulWidget {
  final Work work;
  final List<VideoEpisode> episodes;
  final int initialIndex;
  final MediaCandidate? initialResolved;
  final String sourceName;

  const VideoPlayerPage({
    super.key,
    required this.work,
    required this.episodes,
    required this.initialIndex,
    this.initialResolved,
    this.sourceName = '',
  });

  @override
  ConsumerState<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends ConsumerState<VideoPlayerPage>
    with WidgetsBindingObserver, WindowListener {
  late final Player _player;
  late final VideoController _controller;
  final List<StreamSubscription<dynamic>> _subs = [];
  String? _error;
  int _currentIndex = 0;
  bool _panelOpen = false;
  bool _resolving = false;
  bool _usedInitialUrl = false;
  int _gen = 0;
  static const int _maxAutoRetries = 2;
  int _autoRetries = 0;
  bool _autoRetryPending = false;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _buffering = false;
  double _rate = 1.0;
  double _volume = 100;
  bool _muted = false;
  bool _controlsVisible = true;
  bool _fullscreen = false;
  double _doubleTapX = 0;
  Timer? _hideTimer;
  String? _seekFeedback;
  Timer? _seekFeedbackTimer;
  Duration? _dragSeekTarget;
  Duration _dragSeekStart = Duration.zero;
  int _dragSeekPx = 0;
  final _resolveCancel = CancellationToken();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (isDesktop) windowManager.addListener(this);
    _player = Player();
    _volume = double.tryParse(
            AppDatabase().getString('anime_player_volume') ?? '') ??
        100;
    _muted = AppDatabase().getString('anime_player_muted') == '1';
    _player.setVolume(_muted ? 0 : _volume);
    _controller = VideoController(_player);
    _subs.add(_player.stream.error.listen((e) {
      debugPrint('[Player] error: $e');
      if (!mounted) return;
      if (!_autoRetryPending && _autoRetries < _maxAutoRetries) {
        _autoRetries++;
        _autoRetryPending = true;
        debugPrint('[Player] auto-retry $_autoRetries/$_maxAutoRetries');
        Future<void>.delayed(const Duration(milliseconds: 1000), () {
          if (!mounted) return;
          _autoRetryPending = false;
          setState(() => _error = null);
          _playIndex(_currentIndex);
        });
        return;
      }
      setState(() => _error = e);
    }));
    _subs.add(_player.stream.position.listen((p) {
      if (mounted) setState(() => _position = p);
    }));
    _subs.add(_player.stream.duration.listen((d) {
      if (mounted) setState(() => _duration = d);
    }));
    _subs.add(_player.stream.playing.listen((p) {
      if (!mounted) return;
      setState(() => _playing = p);
      if (p) {
        _autoRetries = 0;
        _scheduleHide();
      } else {
        _hideTimer?.cancel();
        if (!_controlsVisible) setState(() => _controlsVisible = true);
      }
    }));
    _subs.add(_player.stream.buffering.listen((b) {
      if (mounted) setState(() => _buffering = b);
    }));
    _subs.add(_player.stream.rate.listen((r) {
      if (mounted) setState(() => _rate = r);
    }));
    if (widget.episodes.isEmpty) return;
    _currentIndex = widget.initialIndex.clamp(0, widget.episodes.length - 1);
    _playIndex(_currentIndex);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (isDesktop) windowManager.removeListener(this);
    _hideTimer?.cancel();
    _seekFeedbackTimer?.cancel();
    _resolveCancel.cancel();
    for (final sub in _subs) {
      sub.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _playIndex(int i) async {
    if (_resolving) return;
    if (i < 0 || i >= widget.episodes.length) return;
    final gen = ++_gen;
    final previous = _currentIndex;
    if (i != previous) _autoRetries = 0;
    final episode = widget.episodes[i];
    final work = widget.work;
    final history = ref.read(watchHistoryProvider.notifier);
    setState(() {
      _resolving = true;
      _error = null;
      _currentIndex = i;
    });
    final useInitial = !_usedInitialUrl &&
        i == widget.initialIndex &&
        widget.initialResolved != null;
    if (useInitial) _usedInitialUrl = true;
    final result = useInitial
        ? ResolveResult.success(widget.initialResolved!)
        : await StreamResolver().resolve(episode.playUrl,
            userAgent: episode.userAgent,
            referer: episode.referer,
            legacy: episode.useLegacyParser,
            cancel: _resolveCancel);
    if (!mounted || gen != _gen) return;
    final stream = result.candidate;
    if (stream == null) {
      setState(() {
        _resolving = false;
        _currentIndex = previous;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(resolveFailureMessage(widget.sourceName, result.failure)),
        action: SnackBarAction(
          label: '重试',
          onPressed: () => _playIndex(i),
        ),
      ));
      return;
    }
    setState(() => _resolving = false);
    final headers = <String, String>{
      if (episode.userAgent != null) 'User-Agent': episode.userAgent!,
      if (episode.referer != null) 'Referer': episode.referer!,
      ...stream.headers,
    };
    await _player.open(Media(
      stream.url,
      httpHeaders: headers.isEmpty ? null : headers,
    ));
    if (gen == _gen) await history.record(work, episode);
    ref.read(syncProvider).schedule();
    _showControls();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!_playing) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _showControls() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  void _togglePlay() {
    _player.playOrPause();
    _showControls();
  }

  void _nextEpisode() {
    if (_currentIndex + 1 >= widget.episodes.length) return;
    _playIndex(_currentIndex + 1);
  }

  void _seekRelative(int seconds) {
    final target = seekTarget(_position, seconds, _duration);
    _player.seek(target);
    setState(() {
      _position = target;
      _seekFeedback = seconds > 0 ? '+$seconds 秒' : '$seconds 秒';
    });
    _seekFeedbackTimer?.cancel();
    _seekFeedbackTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _seekFeedback = null);
    });
  }

  void _handleDoubleTap(TapZone zone) {
    switch (zone) {
      case TapZone.left:
        _seekRelative(-15);
      case TapZone.right:
        _seekRelative(15);
      case TapZone.center:
        _togglePlay();
    }
  }

  void _onDragSeekStart(DragStartDetails details) {
    if (_duration.inMilliseconds <= 0) return;
    _dragSeekStart = _position;
    _dragSeekPx = 0;
    _dragSeekTarget = _position;
    _showControls();
    setState(() {});
  }

  void _onDragSeekUpdate(DragUpdateDetails details) {
    if (_dragSeekTarget == null || _duration.inMilliseconds <= 0) return;
    final width = MediaQuery.of(context).size.width;
    if (width <= 0) return;
    _dragSeekPx += details.delta.dx.round();
    final deltaMs = (_dragSeekPx / width) * _duration.inMilliseconds;
    final targetMs = (_dragSeekStart.inMilliseconds + deltaMs)
        .clamp(0, _duration.inMilliseconds)
        .round();
    setState(() => _dragSeekTarget = Duration(milliseconds: targetMs));
  }

  void _onDragSeekEnd(DragEndDetails details) {
    final target = _dragSeekTarget;
    if (target != null) {
      _player.seek(target);
      setState(() => _position = target);
    }
    setState(() => _dragSeekTarget = null);
    _scheduleHide();
  }

  void _onDragSeekCancel() {
    if (_dragSeekTarget == null) return;
    setState(() => _dragSeekTarget = null);
  }

  void _startBoost() {
    _player.setRate(2.0);
    _showControls();
  }

  void _endBoost() {
    _player.setRate(1.0);
  }

  void _persistVolumeState() {
    unawaited(AppDatabase().setString('anime_player_volume', _volume.toString()));
    unawaited(
        AppDatabase().setString('anime_player_muted', _muted ? '1' : '0'));
  }

  void _setVolume(double value) {
    final v = value.clamp(0.0, 100.0).toDouble();
    setState(() {
      _volume = v;
      if (v > 0) _muted = false;
    });
    _player.setVolume(_muted ? 0 : _volume);
    _persistVolumeState();
    _showControls();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _player.setVolume(_muted ? 0 : _volume);
    _persistVolumeState();
    _showControls();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _endBoost();
  }

  @override
  void onWindowEnterFullScreen() {
    if (mounted) setState(() => _fullscreen = true);
  }

  @override
  void onWindowLeaveFullScreen() {
    if (mounted) setState(() => _fullscreen = false);
  }

  Future<void> _handleBack() async {
    if (_panelOpen) {
      setState(() => _panelOpen = false);
      return;
    }
    if (_fullscreen) {
      await _toggleFullscreen();
      return;
    }
    Navigator.of(context).maybePop();
  }

  Future<void> _toggleFullscreen() async {
    if (isDesktop) {
      final next = !await windowManager.isFullScreen();
      await windowManager.setFullScreen(next);
      final actual = await windowManager.isFullScreen();
      if (mounted) setState(() => _fullscreen = actual);
      return;
    }
    if (_fullscreen) {
      await SystemChrome.setPreferredOrientations(
          const [DeviceOrientation.portraitUp]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    if (mounted) setState(() => _fullscreen = !_fullscreen);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_fullscreen && !_panelOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(child: _gestureArea()),
            if (_seekFeedback != null) _seekFeedbackOverlay(),
            if (_dragSeekTarget != null) _dragSeekOverlay(),
            if (_rate != 1.0) _speedBadge(),
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.sourceName.isEmpty
                            ? '播放失败：${playbackErrorLabel(_error!)}'
                            : '来源 ${widget.sourceName} · 播放失败：${playbackErrorLabel(_error!)}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      TextButton(
                        onPressed: () {
                          if (_resolving) return;
                          _autoRetries = 0;
                          setState(() => _error = null);
                          _playIndex(_currentIndex);
                        },
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ),
            if (_panelOpen) _episodePanel(),
          ],
        ),
      ),
    );
  }

  Widget _gestureArea() {
    return Listener(
      onPointerUp: (_) => _endBoost(),
      onPointerCancel: (_) => _endBoost(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        onDoubleTapDown: (details) => _doubleTapX = details.localPosition.dx,
        onDoubleTap: () {
          final width = MediaQuery.of(context).size.width;
          _handleDoubleTap(tapZoneFor(_doubleTapX, width));
        },
        onLongPressStart: (_) => _startBoost(),
        onLongPressEnd: (_) => _endBoost(),
        onLongPressCancel: () => _endBoost(),
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: _onDragSeekStart,
                onHorizontalDragUpdate: _onDragSeekUpdate,
                onHorizontalDragEnd: _onDragSeekEnd,
                onHorizontalDragCancel: _onDragSeekCancel,
                child: _video(),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: AnimatedOpacity(
                  opacity: _controlsVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: PlayerControlsOverlay(
                    title: widget.work.title,
                    position: _position,
                    duration: _duration,
                    playing: _playing,
                    buffering: _buffering,
                    fullscreen: _fullscreen,
                    onBack: _handleBack,
                    onTogglePlay: _togglePlay,
                    onSeek: (target) {
                      _player.seek(target);
                      setState(() => _position = target);
                      _showControls();
                    },
                    onToggleFullscreen: _toggleFullscreen,
                    onToggleEpisodes: () {
                      setState(() => _panelOpen = !_panelOpen);
                      _showControls();
                    },
                    onNextEpisode: _nextEpisode,
                    hasNext: _currentIndex + 1 < widget.episodes.length,
                    volume: _volume,
                    muted: _muted,
                    onVolumeChanged: _setVolume,
                    onToggleMute: _toggleMute,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _video() => Video(
        controller: _controller,
        controls: null,
        fit: BoxFit.contain,
        fill: Colors.black,
      );

  Widget _seekFeedbackOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _seekFeedback!,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dragSeekOverlay() {
    final target = _dragSeekTarget!;
    final delta = target - _dragSeekStart;
    final sign = delta > Duration.zero
        ? '+'
        : (delta < Duration.zero ? '-' : '');
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatDuration(target),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '$sign${delta.inSeconds.abs()} 秒',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _speedBadge() {
    return Positioned(
      top: 60,
      right: 16,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${_rate.toStringAsFixed(1)}x',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _episodePanel() {
    return Positioned(
      top: 0,
      bottom: 0,
      right: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
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
                        const Text('选集',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white70, size: 20),
                          tooltip: '关闭',
                          onPressed: () => setState(() => _panelOpen = false),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0x33007AFF)
                                      : Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selected
                                        ? const Color(0x99007AFF)
                                        : Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Text(
                                  ep.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: selected
                                        ? const Color(0xFF4DA3FF)
                                        : Colors.white,
                                    fontSize: 13,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
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
