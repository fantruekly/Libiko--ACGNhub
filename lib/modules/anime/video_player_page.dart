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
import '../../core/sources/source_preferences.dart';
import '../../core/storage/database.dart';
import '../../core/video/browser_pool.dart';
import '../../core/video/cancellation.dart';
import '../../core/video/candidate_queue.dart';
import '../../core/video/cross_source_recovery.dart';
import '../../core/video/headless_browser.dart';
import '../../core/video/line_preference.dart';
import '../../core/video/playback_error.dart';
import '../../core/video/playback_diagnostics.dart';
import '../../core/video/playback_session.dart';
import '../../core/video/stream_resolver.dart';
import '../../core/video/video_source.dart';
import 'player_controls.dart';
import 'player_gestures.dart';

class VideoPlayerPage extends ConsumerStatefulWidget {
  final Work work;
  final List<VideoEpisode> episodes;
  final int initialIndex;
  final List<MediaCandidate>? initialCandidates;
  final bool initialVerified;
  final String sourceName;
  final Duration initialPosition;
  final PlaybackRecoveryFinder? findAlternative;
  @visibleForTesting
  final Player Function()? playerFactory;
  @visibleForTesting
  final Widget Function(Player)? videoBuilder;
  @visibleForTesting
  final StreamResolver? resolver;

  const VideoPlayerPage({
    super.key,
    required this.work,
    required this.episodes,
    required this.initialIndex,
    this.initialCandidates,
    this.initialVerified = false,
    this.sourceName = '',
    this.initialPosition = Duration.zero,
    this.findAlternative,
    this.playerFactory,
    this.videoBuilder,
    this.resolver,
  });

  @override
  ConsumerState<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends ConsumerState<VideoPlayerPage>
    with WidgetsBindingObserver, WindowListener {
  late Player _player;
  VideoController? _controller;
  final List<StreamSubscription<dynamic>> _subs = [];
  String? _error;
  String? _pendingError;
  int _currentIndex = 0;
  bool _panelOpen = false;
  bool _resolving = false;
  bool _usedInitialUrl = false;
  int _gen = 0;
  late final StreamResolver _resolver;
  CandidateQueue _candidates = CandidateQueue();
  CancellationToken _prefetchCancel = CancellationToken();
  bool _switchingCandidate = false;
  late final PlaybackSession _session;
  late final WatchHistoryNotifier _history;
  late final SyncService _sync;
  Future<void> _commands = Future.value();
  Timer? _historyTimer;
  bool _started = false;
  bool _reparsed = false;
  bool _recovering = false;
  bool _autoNext = true;
  final Set<String> _attemptedLines = {};
  final Set<String> _attemptedSources = {};
  late List<VideoEpisode> _episodes;
  late String _sourceName;
  Duration _resumeTarget = Duration.zero;
  bool _resumeApplied = false;
  bool _userPaused = false;
  bool _background = false;
  final _diagnostics = PlaybackDiagnostics();
  final _resolveClock = Stopwatch();
  final _openClock = Stopwatch();
  final _linePreferences = LinePreferenceStore();
  LinePlaybackEvidence _lineEvidence = LinePlaybackEvidence();
  bool _lineRecorded = false;

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
  CancellationToken _resolveCancel = CancellationToken();
  String? _bufferingHint;
  bool _prefetchedForGen = false;
  Timer? _prefetchTimer;
  String? _prefetchInFlight;
  bool _playbackOutcomeRecorded = false;
  bool _startupTimingInterrupted = false;
  final _startupClock = Stopwatch();

  @override
  void initState() {
    super.initState();
    _episodes = List.of(widget.episodes);
    _sourceName = widget.sourceName;
    _resolver = widget.resolver ?? StreamResolver();
    WidgetsBinding.instance.addObserver(this);
    if (isDesktop) windowManager.addListener(this);
    _history = ref.read(watchHistoryProvider.notifier);
    _sync = ref.read(syncProvider);
    _autoNext = AppDatabase().getBool('anime_player_auto_next') ?? true;
    _session = PlaybackSession(
      onTimeout: () => unawaited(_recover('播放超时')),
      onSlow: () {
        _trace(_session.started ? '播放停滞' : '加载较慢',
            elapsedMs:
                _session.started ? null : _openClock.elapsedMilliseconds);
        if (mounted) setState(() => _bufferingHint = '源站响应较慢，正在加载…');
      },
    );
    _volume =
        double.tryParse(AppDatabase().getString('anime_player_volume') ?? '') ??
            100;
    _muted = AppDatabase().getString('anime_player_muted') == '1';
    _createPlayer();
    if (_episodes.isEmpty) return;
    _currentIndex = widget.initialIndex.clamp(0, _episodes.length - 1);
    _playIndex(_currentIndex);
  }

  void _createPlayer() {
    _player = widget.playerFactory?.call() ?? Player();
    _player.setVolume(_muted ? 0 : _volume);
    _controller = widget.videoBuilder == null ? VideoController(_player) : null;
    final platform = _player.platform;
    if (platform is NativePlayer) {
      // Bound network stalls so a dead/slow CDN errors instead of hanging.
      unawaited(platform.setProperty('network-timeout', '15'));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (isDesktop) windowManager.removeListener(this);
    _hideTimer?.cancel();
    _seekFeedbackTimer?.cancel();
    _saveHistory();
    _historyTimer?.cancel();
    _session.dispose();
    ++_gen;
    _resolveCancel.cancel();
    _cancelPrefetch(reset: true);
    for (final sub in _subs) {
      sub.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  void _bindPlayer(int generation) {
    bool active() => mounted && _session.accepts(generation);
    _subs.add(_player.stream.error.listen((error) {
      if (!active()) return;
      _pendingError = error;
      if (!_switchingCandidate) unawaited(_recover(error));
    }));
    _subs.add(_player.stream.position.listen((position) {
      if (!active()) return;
      setState(() => _position = position);
      if (!_resumeApplied && _resumeTarget > Duration.zero) return;
      final first = _session.progress(position);
      if (!_lineRecorded &&
          !_userPaused &&
          !_background &&
          !_buffering &&
          _playing &&
          _lineEvidence.progress(position, _openClock.elapsed)) {
        _lineRecorded = true;
        final ep = _episodes[_currentIndex];
        unawaited(_linePreferences.record(widget.work, ep.sourceId, ep.lineId));
      }
      if (_session.phase == PlaybackPhase.playing && _bufferingHint != null) {
        setState(() => _bufferingHint = null);
      }
      if (first) {
        _trace('开始播放',
            elapsedMs: _openClock.elapsedMilliseconds, outcome: '实际进度已推进');
        if (!_playbackOutcomeRecorded) {
          _recordPlaybackOutcome(success: true);
        }
        _started = true;
        _saveHistory();
      }
      if (_started) _schedulePrefetch();
    }));
    _subs.add(_player.stream.videoParams.listen((params) {
      if (active()) {
        _lineEvidence.video = (params.w ?? 0) > 0 && (params.h ?? 0) > 0;
      }
    }));
    _subs.add(_player.stream.duration.listen((duration) {
      if (!active()) return;
      setState(() => _duration = duration);
      if (!_resumeApplied && duration > Duration.zero) {
        _resumeApplied = true;
        final target = _resumeTarget < duration ? _resumeTarget : Duration.zero;
        _resumeTarget = Duration.zero;
        if (target > Duration.zero) {
          _lineEvidence.interrupt();
          _session.seek(target);
          unawaited(_player.seek(target));
        }
      }
    }));
    _subs.add(_player.stream.playing.listen((playing) {
      if (!active()) return;
      setState(() => _playing = playing);
      if (playing) {
        _scheduleHide();
      } else {
        _lineEvidence.interrupt();
        _hideTimer?.cancel();
        setState(() => _controlsVisible = true);
      }
    }));
    _subs.add(_player.stream.buffering.listen((buffering) {
      if (!active()) return;
      setState(() => _buffering = buffering);
      if (buffering) _cancelPrefetch();
      if (buffering) _lineEvidence.interrupt();
      _session.buffering(buffering);
    }));
    _subs.add(_player.stream.rate.listen((rate) {
      if (active()) setState(() => _rate = rate);
    }));
    _subs.add(_player.stream.completed.listen((completed) {
      if (!active() || !completed || !_started) return;
      _session.finish(PlaybackPhase.completed);
      _saveHistory(completed: true);
      if (_autoNext) _nextEpisode();
    }));
  }

  void _saveHistory({bool completed = false}) {
    if (!_started || _episodes.isEmpty) return;
    unawaited(_history
        .record(
          widget.work,
          _episodes[_currentIndex],
          positionMs: _position.inMilliseconds,
          durationMs: _duration.inMilliseconds,
          completed: completed || _session.phase == PlaybackPhase.completed,
        )
        .then((_) => _sync.schedule())
        .catchError((Object error) {
      debugPrint('[Player] history save failed: $error');
    }));
  }

  void _trace(String event,
      {VideoEpisode? episode,
      int? elapsedMs,
      bool? verified,
      int? candidates,
      String? outcome}) {
    episode ??= _episodes.isEmpty ? null : _episodes[_currentIndex];
    _diagnostics.add(event,
        source: episode?.sourceId ?? _sourceName,
        line: episode?.lineId ?? 'default',
        episode: episode?.episodeKey ?? 'index:$_currentIndex',
        elapsedMs: elapsedMs,
        verified: verified,
        candidates: candidates,
        outcome: outcome,
        positionMs: _position.inMilliseconds,
        durationMs: _duration.inMilliseconds);
  }

  void _showDiagnostics() {
    showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('播放诊断'),
              content: SingleChildScrollView(
                  child: SelectableText(_diagnostics.report())),
              actions: [
                TextButton(
                    onPressed: () => Clipboard.setData(
                        ClipboardData(text: _diagnostics.report())),
                    child: const Text('复制')),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('关闭')),
              ],
            ));
  }

  String _lineKey(VideoEpisode episode) =>
      '${episode.sourceId ?? ''}/${episode.lineId ?? ''}';

  Future<void> _cancelSubscriptions() async {
    final subscriptions = List<StreamSubscription<dynamic>>.of(_subs);
    _subs.clear();
    await Future.wait(subscriptions.map((sub) => sub.cancel()));
  }

  Future<void> _playIndex(int i,
      {Duration? resume, bool recovery = false}) async {
    if (i < 0 || i >= _episodes.length) return;
    _saveHistory();
    final gen = ++_gen;
    _resolveCancel.cancel();
    _resolveCancel = CancellationToken();
    _cancelPrefetch(reset: true);
    _session.cancel();
    _historyTimer?.cancel();
    _started = false;
    _switchingCandidate = false;
    _resumeTarget = resume ??
        (i == widget.initialIndex && !_usedInitialUrl
            ? widget.initialPosition
            : Duration.zero);
    _resumeApplied = false;
    if (!recovery) {
      _playbackOutcomeRecorded = false;
      _startupTimingInterrupted = _background;
      _startupClock
        ..reset()
        ..start();
      if (!_background) _userPaused = false;
      _reparsed = false;
      _attemptedLines.clear();
      _attemptedSources.clear();
      _recovering = false;
    }
    final episode = _episodes[i];
    if (episode.sourceId != null) _attemptedSources.add(episode.sourceId!);
    _attemptedLines.add(_lineKey(episode));
    _candidates = CandidateQueue();
    _prefetchedForGen = false;
    setState(() {
      _resolving = true;
      _error = null;
      _pendingError = null;
      _position = Duration.zero;
      _duration = Duration.zero;
      _playing = false;
      _buffering = false;
      _bufferingHint = null;
      _dragSeekTarget = null;
      _currentIndex = i;
    });
    _trace(recovery ? 'resolve: recovery' : 'resolve: selected');
    _resolveClock
      ..reset()
      ..start();
    _session.phase = PlaybackPhase.resolving;
    // Stop the previous episode before resolving so it cannot keep playing
    // underneath the new title, or feed positions into the new session.
    try {
      await _enqueue(() async {
        final oldPlayer = _player;
        await _cancelSubscriptions();
        await oldPlayer.stop();
      });
      if (!mounted || gen != _gen) return;
      final useInitial = !_usedInitialUrl &&
          i == widget.initialIndex &&
          (widget.initialCandidates?.isNotEmpty ?? false);
      final initial = useInitial ? widget.initialCandidates : null;
      _usedInitialUrl = true;
      final result = initial != null
          ? ResolveResult.success(initial, verified: widget.initialVerified)
          : await _resolver.resolve(episode.playUrl,
              userAgent: episode.userAgent,
              referer: episode.referer,
              legacy: episode.useLegacyParser,
              cancel: _resolveCancel);
      if (!mounted || gen != _gen) return;
      setState(() => _resolving = false);
      _resolveClock.stop();
      _trace('解析完成',
          elapsedMs: _resolveClock.elapsedMilliseconds,
          verified: result.verified,
          candidates: result.candidates.length,
          outcome: result.ok ? '已找到候选' : result.failure?.name);
      if (!result.ok) {
        _trace('resolve: ${result.failure?.name ?? "unknown"}');
        unawaited(_recover(resolveFailureMessage(_sourceName, result.failure),
            definitive: result.failure == ResolveFailure.notFound));
        return;
      }
      _candidates = CandidateQueue(result.candidates);
      await _openCandidate(gen);
      if (mounted && gen == _gen) _showControls();
    } catch (error) {
      if (mounted && gen == _gen) _fail(error.toString());
    }
  }

  Future<void> _enqueue(Future<void> Function() command) {
    final next = _commands.then<void>((_) async {
      if (!mounted) return;
      final player = _player;
      await command().timeout(const Duration(seconds: 15), onTimeout: () {
        // Retire the native instance: a late open must never change the new
        // episode on the same player after a command timeout.
        if (mounted && identical(player, _player)) {
          for (final sub in _subs) {
            unawaited(sub.cancel());
          }
          _subs.clear();
          _createPlayer();
          setState(() {});
          unawaited(player.dispose().catchError((Object error) {
            debugPrint('[Player] dispose stalled instance: $error');
          }));
        }
        throw TimeoutException('播放器响应超时');
      });
    });
    _commands = next.catchError((Object error) {
      debugPrint('[Player] $error');
    });
    return next;
  }

  Future<void> _openCandidate(int gen) async {
    final candidate = _candidates.current;
    if (candidate == null || gen != _gen || !mounted) return;
    final episode = _episodes[_currentIndex];
    final headers = playbackHeaders(candidate, episode);
    final generation = _session.begin();
    _lineEvidence = LinePlaybackEvidence();
    _lineRecorded = false;
    final evidence = _lineEvidence;
    final controller = _controller;
    if (controller != null) {
      unawaited(controller.waitUntilFirstFrameRendered.then((_) {
        if (mounted &&
            _session.accepts(generation) &&
            identical(evidence, _lineEvidence)) {
          evidence.frame = true;
        }
      }));
    }
    _openClock
      ..reset()
      ..start();
    if (_userPaused || _background) _session.pause(true);
    _trace('open: candidate');
    _switchingCandidate = true;
    _started = false;
    _pendingError = null;
    setState(() {
      _buffering = true;
      _position = Duration.zero;
      _duration = Duration.zero;
    });
    try {
      await _enqueue(() async {
        final player = _player;
        if (!mounted || gen != _gen || !_session.accepts(generation)) return;
        await _cancelSubscriptions();
        await player.stop();
        if (!mounted ||
            gen != _gen ||
            !_session.accepts(generation) ||
            !identical(player, _player)) {
          return;
        }
        _bindPlayer(generation);
        await player.open(
            Media(candidate.url, httpHeaders: headers.isEmpty ? null : headers),
            play: !_userPaused && !_background);
        if (mounted &&
            identical(player, _player) &&
            _session.accepts(generation) &&
            (_userPaused || _background)) {
          await player.pause();
        }
      });
    } catch (error) {
      if (gen == _gen && _session.accepts(generation)) {
        _pendingError = error.toString();
      }
    } finally {
      if (mounted && gen == _gen && _session.accepts(generation)) {
        _switchingCandidate = false;
        _historyTimer?.cancel();
        _historyTimer =
            Timer.periodic(const Duration(seconds: 10), (_) => _saveHistory());
        final pending = _pendingError;
        if (pending != null) {
          scheduleMicrotask(() => unawaited(_recover(pending)));
        }
      }
    }
  }

  void _recordPlaybackOutcome({required bool success}) {
    if (!mounted || _episodes.isEmpty) return;
    if (!success && (_userPaused || _background)) return;
    _playbackOutcomeRecorded = true;
    _startupClock.stop();
    final id = _episodes[_currentIndex].sourceId;
    if (id == null || id.isEmpty) return;
    ref.read(sourceHealthProvider).recordPlayback(id,
        success: success,
        startup: success && !_startupTimingInterrupted
            ? _startupClock.elapsed
            : null);
  }

  void _fail(String error) {
    if (!_playbackOutcomeRecorded) _recordPlaybackOutcome(success: false);
    _trace('playback: failed');
    _session.finish(PlaybackPhase.failed);
    _historyTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _error = error;
      _resolving = false;
      _buffering = false;
      _bufferingHint = null;
      _controlsVisible = true;
    });
  }

  Future<void> _recover(String error, {bool definitive = false}) async {
    if (!mounted || _recovering || _resolving || _userPaused || _background) {
      return;
    }
    _recovering = true;
    _cancelPrefetch();
    final gen = _gen;
    final resume = _position > Duration.zero ? _position : _resumeTarget;
    _saveHistory();
    _trace('playback: recovering (${playbackErrorLabel(error)})');
    try {
      _session.finish(PlaybackPhase.recovering);
      if (_candidates.advance() != null) {
        _trace('恢复', outcome: '尝试下一候选地址');
        _resumeTarget = resume;
        _resumeApplied = false;
        _launchRecovery(() => _openCandidate(gen));
      } else if (!_reparsed &&
          !definitive &&
          !isDefinitivePlaybackFailure(error)) {
        _trace('恢复', outcome: '刷新当前集地址');
        _reparsed = true;
        _resolver.invalidate(_episodes[_currentIndex].playUrl);
        _launchRecovery(
            () => _playIndex(_currentIndex, resume: resume, recovery: true));
      } else {
        int? alternative;
        for (final episode in _episodes) {
          if (_attemptedLines.contains(_lineKey(episode)) ||
              episode.lineId == null) {
            continue;
          }
          final index = matchingEpisodeIndex(
              _episodes, _currentIndex, episode.lineId!,
              targetSourceId: episode.sourceId);
          if (index != null) {
            alternative = index;
            break;
          }
        }
        if (alternative == null) {
          final switched = await _switchSource(gen, resume);
          if (!switched &&
              mounted &&
              gen == _gen &&
              !_userPaused &&
              !_background) {
            _fail(error);
          }
        } else {
          _reparsed = false;
          _trace('恢复', outcome: '切换同源线路');
          _launchRecovery(
              () => _playIndex(alternative!, resume: resume, recovery: true));
        }
      }
    } finally {
      if (mounted && gen == _gen) {
        _recovering = false;
        _pendingError = null;
      }
    }
  }

  void _launchRecovery(Future<void> Function() action) {
    _recovering = false;
    _pendingError = null;
    unawaited(action());
  }

  Future<bool> _switchSource(int gen, Duration resume) async {
    final finder = widget.findAlternative;
    if (finder == null || _attemptedSources.length >= 3) return false;
    final episode = _episodes[_currentIndex];
    if (episode.episodeKey == null ||
        episode.episodeKey!.isEmpty ||
        _episodes
                .where((e) =>
                    e.sourceId == episode.sourceId &&
                    e.lineId == episode.lineId &&
                    e.episodeKey == episode.episodeKey)
                .length !=
            1) {
      return false;
    }
    final before = Set<String>.of(_attemptedSources);
    final cancel = CancellationToken();
    final parent = _resolveCancel;
    parent.addListener(cancel.cancel);
    setState(() => _resolving = true);
    _trace('recovery: looking for another source');
    try {
      final result = await finder(PlaybackRecoveryRequest(
              episode: episode,
              attemptedSources: Set.unmodifiable(before),
              cancel: cancel))
          .timeout(const Duration(seconds: 25), onTimeout: () {
        cancel.cancel();
        return const PlaybackRecoveryResult();
      });
      if (!mounted ||
          gen != _gen ||
          cancel.isCancelled ||
          _userPaused ||
          _background) {
        return false;
      }
      _attemptedSources.addAll(result.attemptedSources);
      final alternative = result.alternative;
      if (alternative == null ||
          alternative.index < 0 ||
          alternative.index >= alternative.episodes.length) {
        return false;
      }
      final target = alternative.episodes[alternative.index];
      if (target.sourceId == null ||
          before.contains(target.sourceId) ||
          target.episodeKey != episode.episodeKey ||
          alternative.episodes
                  .where((e) =>
                      e.sourceId == target.sourceId &&
                      e.lineId == target.lineId &&
                      e.episodeKey == target.episodeKey)
                  .length !=
              1) {
        return false;
      }
      if (!_playbackOutcomeRecorded) _recordPlaybackOutcome(success: false);
      _started = false;
      _episodes = List.of(alternative.episodes);
      _currentIndex = alternative.index;
      _sourceName = alternative.sourceName;
      _playbackOutcomeRecorded = false;
      _startupTimingInterrupted = false;
      _startupClock
        ..reset()
        ..start();
      _reparsed = false;
      _trace('recovery: matched another source');
      _launchRecovery(
          () => _playIndex(alternative.index, resume: resume, recovery: true));
      return true;
    } catch (_) {
      return false;
    } finally {
      parent.removeListener(cancel.cancel);
      cancel.cancel();
      if (mounted && gen == _gen) setState(() => _resolving = false);
    }
  }

  void _cancelPrefetch({bool reset = false}) {
    if (_prefetchTimer != null || _prefetchInFlight != null) {
      _trace('预解析', outcome: '取消后台任务');
    }
    _prefetchTimer?.cancel();
    _prefetchTimer = null;
    if (reset || _prefetchInFlight != null) _prefetchedForGen = false;
    _prefetchCancel.cancel();
    _prefetchCancel = CancellationToken();
    _prefetchInFlight = null;
  }

  void _schedulePrefetch() {
    if (_prefetchTimer != null ||
        _prefetchedForGen ||
        _resolving ||
        _buffering ||
        _userPaused ||
        _background ||
        !_started) {
      return;
    }
    final next = nextEpisodeIndex(_episodes, _currentIndex);
    if (next == null) return;
    final gen = _gen;
    final initialPosition = _position;
    _prefetchTimer = Timer(const Duration(seconds: 5), () {
      _prefetchTimer = null;
      if (!mounted ||
          gen != _gen ||
          _resolving ||
          _buffering ||
          _userPaused ||
          _background ||
          _position <= initialPosition) {
        return;
      }
      _prefetchedForGen = true;
      _prefetch(_episodes[next]);
    });
  }

  void _prefetch(VideoEpisode episode) {
    if (_resolver.isCached(episode.playUrl)) {
      _trace('预解析', episode: episode, outcome: '命中缓存');
      return;
    }
    if (_prefetchInFlight != null) return;
    final cancel = _prefetchCancel;
    final clock = Stopwatch()..start();
    _prefetchInFlight = episode.playUrl;
    _trace('预解析', episode: episode, outcome: '后台开始');
    unawaited(() async {
      try {
        final result = await _resolver.resolve(episode.playUrl,
            userAgent: episode.userAgent,
            referer: episode.referer,
            legacy: episode.useLegacyParser,
            priority: BrowserPriority.background,
            cancel: cancel);
        if (mounted && !cancel.isCancelled) {
          _trace('预解析',
              episode: episode,
              elapsedMs: clock.elapsedMilliseconds,
              verified: result.verified,
              candidates: result.candidates.length,
              outcome: result.ok ? '已准备下一集' : '未找到可用地址');
        }
      } catch (_) {
        if (mounted && !cancel.isCancelled) {
          _trace('预解析',
              episode: episode,
              elapsedMs: clock.elapsedMilliseconds,
              outcome: '后台任务失败');
        }
        // Optional prefetch must never interrupt current playback.
      } finally {
        if (identical(cancel, _prefetchCancel)) _prefetchInFlight = null;
      }
    }());
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
    _userPaused = _playing || (!_started && !_userPaused);
    if (_userPaused && !_playbackOutcomeRecorded) {
      _startupTimingInterrupted = true;
    }
    if (_userPaused) _cancelPrefetch();
    _session.pause(_userPaused);
    if (_userPaused) _saveHistory();
    _player.playOrPause();
    _showControls();
  }

  void _nextEpisode() {
    final next = nextEpisodeIndex(_episodes, _currentIndex);
    if (next != null) _playIndex(next);
  }

  void _seekRelative(int seconds) {
    _lineEvidence.interrupt();
    final target = seekTarget(_position, seconds, _duration);
    _lineEvidence.interrupt();
    _session.seek(target);
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
      _lineEvidence.interrupt();
      _session.seek(target);
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
    unawaited(
        AppDatabase().setString('anime_player_volume', _volume.toString()));
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
    if (state == AppLifecycleState.paused) {
      _background = true;
      _lineEvidence.interrupt();
      _cancelPrefetch();
      if (!_playbackOutcomeRecorded) _startupTimingInterrupted = true;
      _userPaused = true;
      _endBoost();
      _saveHistory();
      _session.pause(true);
      _player.pause();
    }
    if (state == AppLifecycleState.resumed) _background = false;
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
    _saveHistory();
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
            if ((_resolving || _buffering) && _error == null)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        ),
                        if (_bufferingHint != null) ...[
                          const SizedBox(height: 12),
                          Text(_bufferingHint!,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ],
                      ],
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
                        _sourceName.isEmpty
                            ? '播放失败：$_displayError'
                            : '来源 $_sourceName · 播放失败：$_displayError',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      TextButton(
                        onPressed: () {
                          if (_resolving) return;
                          _pendingError = null;
                          setState(() => _error = null);
                          _resolver
                              .invalidate(_episodes[_currentIndex].playUrl);
                          _playIndex(_currentIndex, resume: _position);
                        },
                        child: const Text('重试'),
                      ),
                      TextButton(
                          onPressed: _showDiagnostics,
                          child: const Text('诊断信息')),
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

  String get _displayError => RegExp(r'[\u4e00-\u9fff]').hasMatch(_error ?? '')
      ? _error!
      : playbackErrorLabel(_error ?? '');

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
                    title:
                        '${widget.work.title} · ${_episodes.isEmpty ? '' : _episodes[_currentIndex].title}',
                    position: _position,
                    duration: _duration,
                    playing: _playing,
                    buffering: _buffering || _resolving,
                    fullscreen: _fullscreen,
                    onBack: _handleBack,
                    onTogglePlay: _togglePlay,
                    onSeek: (target) {
                      _lineEvidence.interrupt();
                      _session.seek(target);
                      _player.seek(target);
                      setState(() => _position = target);
                      _showControls();
                    },
                    onToggleFullscreen: _toggleFullscreen,
                    onToggleEpisodes: () {
                      final opening = !_panelOpen;
                      setState(() => _panelOpen = opening);
                      _showControls();
                    },
                    onNextEpisode: _nextEpisode,
                    hasNext: nextEpisodeIndex(_episodes, _currentIndex) != null,
                    autoNext: _autoNext,
                    onAutoNextChanged: (value) {
                      setState(() => _autoNext = value);
                      unawaited(AppDatabase()
                          .setBool('anime_player_auto_next', value));
                    },
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

  Widget _video() =>
      widget.videoBuilder?.call(_player) ??
      Video(
        key: ObjectKey(_controller),
        controller: _controller!,
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
    final sign =
        delta > Duration.zero ? '+' : (delta < Duration.zero ? '-' : '');
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
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      itemCount: _episodes.length,
                      itemBuilder: (context, i) {
                        final ep = _episodes[i];
                        final selected = i == _currentIndex;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                setState(() => _panelOpen = false);
                                final current = _episodes[_currentIndex];
                                final sameEpisode =
                                    ep.lineId != current.lineId &&
                                        ep.episodeKey != null &&
                                        ep.episodeKey == current.episodeKey;
                                _playIndex(i,
                                    resume: sameEpisode
                                        ? _position
                                        : Duration.zero);
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
