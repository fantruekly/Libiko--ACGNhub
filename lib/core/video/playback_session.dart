import 'dart:async';
import 'headless_browser.dart';
import 'video_source.dart';

/// A resolved empty map means headers were deliberately removed by probing.
Map<String, String> playbackHeaders(
        MediaCandidate candidate, VideoEpisode episode) =>
    candidate.headersResolved
        ? Map.of(candidate.headers)
        : {
            if (episode.userAgent != null) 'User-Agent': episode.userAgent!,
            if (episode.referer != null) 'Referer': episode.referer!,
            ...candidate.headers,
          };

enum PlaybackPhase {
  idle,
  resolving,
  opening,
  playing,
  buffering,
  paused,
  recovering,
  failed,
  completed
}

/// Owns the lifetime of one media open. A seek alone is not playback progress.
class PlaybackSession {
  PlaybackSession(
      {required this.onTimeout,
      required this.onSlow,
      this.startupTimeout = const Duration(seconds: 15),
      this.stallTimeout = const Duration(seconds: 20),
      this.slowDelay = const Duration(seconds: 5)});

  final void Function() onTimeout;
  final void Function() onSlow;
  final Duration startupTimeout, stallTimeout, slowDelay;
  PlaybackPhase phase = PlaybackPhase.idle;
  int _generation = 0;
  bool _disposed = false;
  bool started = false;
  bool _paused = false;
  Duration _lastPosition = Duration.zero;
  Timer? _deadline, _hint;

  int get generation => _generation;
  bool accepts(int generation) => !_disposed && generation == _generation;

  int begin({PlaybackPhase phase = PlaybackPhase.opening}) {
    cancel();
    started = false;
    _paused = false;
    _lastPosition = Duration.zero;
    this.phase = phase;
    _arm(startupTimeout);
    return _generation;
  }

  void _arm(Duration timeout) {
    _deadline?.cancel();
    _hint?.cancel();
    final generation = _generation;
    _hint = Timer(slowDelay, () {
      if (accepts(generation) && !_paused) onSlow();
    });
    _deadline = Timer(timeout, () {
      if (!accepts(generation) || _paused) return;
      _hint?.cancel();
      phase = PlaybackPhase.recovering;
      onTimeout();
    });
  }

  /// Only call with positions emitted by the active player, never UI targets.
  bool progress(Duration position) {
    if (_disposed || _paused || position <= _lastPosition) return false;
    _lastPosition = position;
    final first = !started;
    started = true;
    phase = PlaybackPhase.playing;
    _arm(stallTimeout);
    return first;
  }

  void seek(Duration target) {
    _lastPosition = target;
    if (!_paused) _arm(started ? stallTimeout : startupTimeout);
  }

  void buffering(bool value) {
    if (value && !_paused) phase = PlaybackPhase.buffering;
  }

  void pause(bool value) {
    _paused = value;
    if (value) {
      phase = PlaybackPhase.paused;
      _deadline?.cancel();
      _hint?.cancel();
    } else {
      phase = started ? PlaybackPhase.playing : PlaybackPhase.opening;
      _arm(started ? stallTimeout : startupTimeout);
    }
  }

  void cancel() {
    _generation++;
    _deadline?.cancel();
    _hint?.cancel();
  }

  void finish(PlaybackPhase phase) {
    cancel();
    this.phase = phase;
  }

  void dispose() {
    cancel();
    _disposed = true;
  }
}
