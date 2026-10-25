import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:libiko/core/services/watch_history.dart';
import 'package:libiko/core/storage/database.dart';
import 'package:libiko/core/models/work.dart';
import 'package:libiko/core/video/headless_browser.dart';
import 'package:libiko/core/video/video_source.dart';
import 'package:libiko/modules/anime/video_player_page.dart';

class _Player extends PlatformPlayer {
  _Player() : super(configuration: const PlayerConfiguration());
  final opened = <Media>[];
  final seeks = <Duration>[];
  final autoplay = <bool>[];
  Completer<void>? openGate;
  Completer<void>? stopGate;
  void emitDuration(Duration value) => durationController.add(value);
  void emitPosition(Duration value) => positionController.add(value);
  void emitPlaying(bool value) => playingController.add(value);
  void emitBuffering(bool value) => bufferingController.add(value);
  void emitCompleted(bool value) => completedController.add(value);
  void emitError(String value) => errorController.add(value);
  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    opened.add(playable as Media);
    autoplay.add(play);
    await openGate?.future;
  }

  @override
  Future<void> stop() async {
    await stopGate?.future;
  }

  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> setRate(double rate) async {
    rateController.add(rate);
  }

  @override
  Future<void> seek(Duration duration) async {
    seeks.add(duration);
  }

  @override
  Future<void> pause() async {
    playingController.add(false);
  }

  @override
  Future<void> playOrPause() async {}
}

const _work = Work(
    id: 'player_test',
    sourceId: 'meta',
    sourceName: 'Meta',
    type: WorkType.anime,
    title: 'Test');
const _episodes = [
  VideoEpisode(
      id: 'a1',
      title: 'A 1',
      index: 0,
      playUrl: 'https://cdn/a1.mp4',
      sourceId: 'test',
      lineId: 'A',
      episodeKey: 'episode:1'),
  VideoEpisode(
      id: 'a2',
      title: 'A 2',
      index: 1,
      playUrl: 'https://cdn/a2.mp4',
      sourceId: 'test',
      lineId: 'A',
      episodeKey: 'episode:2'),
  VideoEpisode(
      id: 'b1',
      title: 'B 1',
      index: 2,
      playUrl: 'https://cdn/b1.mp4',
      sourceId: 'test',
      lineId: 'B',
      episodeKey: 'episode:1'),
];

Future<ProviderContainer> _mount(
  WidgetTester tester,
  _Player player, {
  List<MediaCandidate>? candidates,
  Duration resume = Duration.zero,
  int index = 0,
  Player Function()? factory,
}) async {
  final container = ProviderContainer();
  await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
          home: VideoPlayerPage(
        work: _work,
        episodes: _episodes,
        initialIndex: index,
        initialCandidates: candidates,
        initialPosition: resume,
        playerFactory: factory ?? () => Player(platformPlayer: player),
        videoBuilder: (_) => const ColoredBox(color: Colors.black),
      ))));
  await tester.pump();
  await tester.pump();
  return container;
}

Future<void> _unmount(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  // Sync is debounced separately from the disposed player.
  await tester.pump(const Duration(seconds: 1));
  container.dispose();
}

Future<void> _settleMedia(WidgetTester tester) async {
  // StreamSubscription.cancel may use the SDK's shared completed future,
  // created outside the fake clock zone. Drain its real microtasks as well.
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppDatabase.init();
  });

  testWidgets('opens with authoritative headers and records only real progress',
      (tester) async {
    final player = _Player();
    final container = await _mount(tester, player, candidates: const [
      MediaCandidate('https://cdn/initial.mp4', headersResolved: true),
    ]);
    expect(player.opened.single.httpHeaders, anyOf(isNull, isEmpty));
    expect(container.read(watchHistoryProvider), isEmpty);
    player.emitDuration(const Duration(minutes: 24));
    player.emitPosition(const Duration(seconds: 2));
    await tester.pump();
    await tester.pump();
    expect(container.read(watchHistoryProvider).single.positionMs, 2000);
    await _unmount(tester, container);
  });

  testWidgets(
      'resume seeks after duration, and buffering falls back at saved position',
      (tester) async {
    final player = _Player();
    final container = await _mount(tester, player,
        resume: const Duration(minutes: 3),
        candidates: const [
          MediaCandidate('https://cdn/first.mp4'),
          MediaCandidate('https://cdn/second.mp4')
        ]);
    expect(player.seeks, isEmpty);
    player.emitDuration(const Duration(minutes: 24));
    await tester.pump();
    expect(player.seeks.single, const Duration(minutes: 3));
    player.emitPosition(const Duration(minutes: 3, seconds: 1));
    player.emitPlaying(true);
    await tester.pump();
    player.emitBuffering(true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 20));
    await _settleMedia(tester);
    expect(player.opened.last.uri, 'https://cdn/second.mp4');
    player.emitDuration(const Duration(minutes: 24));
    await tester.pump();
    expect(player.seeks.last, const Duration(minutes: 3, seconds: 1));
    await _unmount(tester, container);
  });

  testWidgets('end of line does not continue into another line',
      (tester) async {
    final player = _Player();
    final container = await _mount(tester, player, index: 1);
    player.emitPosition(const Duration(seconds: 3));
    await tester.pump();
    player.emitCompleted(true);
    await tester.pump();
    expect(player.opened.length, 1);
    expect(container.read(watchHistoryProvider).single.completed, true);
    await _unmount(tester, container);
  });

  testWidgets(
      'an error falls back even while playing and buffering remain true',
      (tester) async {
    final player = _Player();
    final container = await _mount(tester, player, candidates: const [
      MediaCandidate('https://cdn/first.mp4'),
      MediaCandidate('https://cdn/second.mp4')
    ]);
    player.emitPlaying(true);
    player.emitBuffering(true);
    await tester.pump();
    player.emitError('403');
    await tester.pump(const Duration(milliseconds: 100));
    await _settleMedia(tester);
    expect(player.opened.last.uri, 'https://cdn/second.mp4');
    await _unmount(tester, container);
  });

  testWidgets('hung native open is retired before the next candidate opens',
      (tester) async {
    final player = _Player()..openGate = Completer<void>();
    final replacement = _Player();
    var created = 0;
    final container = await _mount(tester, player,
        factory: () =>
            Player(platformPlayer: created++ == 0 ? player : replacement),
        candidates: const [
          MediaCandidate('https://cdn/hang.mp4'),
          MediaCandidate('https://cdn/good.mp4')
        ]);
    await tester.pump(const Duration(seconds: 15));
    await tester.pump();
    await tester.pump();
    expect(replacement.opened.single.uri, 'https://cdn/good.mp4');
    player.openGate!.complete();
    await tester.pump();
    expect(replacement.opened.length, 1);
    await _unmount(tester, container);
  });

  testWidgets(
      'retries current episode once then matches the same episode on another line',
      (tester) async {
    final player = _Player();
    final container = await _mount(tester, player);
    for (var attempt = 0; attempt < 4; attempt++) {
      player.emitError('404');
      await tester.pump();
      await _settleMedia(tester);
      await _settleMedia(tester);
    }
    expect(player.opened.map((media) => media.uri), [
      'https://cdn/a1.mp4',
      'https://cdn/a1.mp4',
      'https://cdn/b1.mp4',
      'https://cdn/b1.mp4',
    ]);
    expect(find.textContaining('播放失败'), findsOneWidget);
    expect(find.text('诊断信息'), findsOneWidget);
    await _unmount(tester, container);
  });

  testWidgets(
      'rapid episode selections do not let a late open replace the latest selection',
      (tester) async {
    final player = _Player()..openGate = Completer<void>();
    final container = await _mount(tester, player);
    await tester.tap(find.byKey(const ValueKey('player-next')));
    await tester.pump(const Duration(milliseconds: 350));
    player.openGate!.complete();
    await _settleMedia(tester);
    await _settleMedia(tester);
    expect(player.opened.last.uri, 'https://cdn/a2.mp4');
    player.emitPosition(const Duration(seconds: 2));
    await tester.pump();
    await tester.pump();
    expect(container.read(watchHistoryProvider).single.episodeKey, 'episode:2');
    await _unmount(tester, container);
  });

  testWidgets('finishing an open after backgrounding preserves pause intent',
      (tester) async {
    final player = _Player()..stopGate = Completer<void>();
    final container = await _mount(tester, player);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    player.stopGate!.complete();
    await _settleMedia(tester);
    await _settleMedia(tester);
    expect(player.autoplay.single, false);
    await tester.pump(const Duration(minutes: 1));
    expect(player.opened.length, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _unmount(tester, container);
  });
}
