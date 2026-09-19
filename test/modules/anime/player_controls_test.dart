import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/theme/app_theme.dart';
import 'package:libiko/modules/anime/player_controls.dart';

Widget _host({
  bool playing = true,
  bool buffering = false,
  bool fullscreen = false,
  ValueChanged<Duration>? onSeek,
  VoidCallback? onBack,
  VoidCallback? onTogglePlay,
  VoidCallback? onToggleFullscreen,
  VoidCallback? onToggleEpisodes,
  VoidCallback? onNextEpisode,
  bool hasNext = true,
}) {
  return MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(
      body: PlayerControlsOverlay(
        title: '测试标题',
        position: const Duration(seconds: 30),
        duration: const Duration(minutes: 2),
        playing: playing,
        buffering: buffering,
        fullscreen: fullscreen,
        onBack: onBack ?? () {},
        onTogglePlay: onTogglePlay ?? () {},
        onSeek: onSeek ?? (_) {},
        onToggleFullscreen: onToggleFullscreen ?? () {},
        onToggleEpisodes: onToggleEpisodes ?? () {},
        onNextEpisode: onNextEpisode ?? () {},
        hasNext: hasNext,
      ),
    ),
  );
}

void main() {
  testWidgets('shows the title, times and a primary-coloured seek bar',
      (tester) async {
    await tester.pumpWidget(_host());

    expect(find.text('测试标题'), findsOneWidget);
    expect(find.text('00:30'), findsOneWidget);
    expect(find.text('02:00'), findsOneWidget);

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 30000);
    expect(slider.max, 120000);

    final sliderTheme = tester.widget<SliderTheme>(
      find
          .ancestor(of: find.byType(Slider), matching: find.byType(SliderTheme))
          .first,
    );
    expect(sliderTheme.data.activeTrackColor, buildAppTheme().colorScheme.primary);
    expect(sliderTheme.data.thumbColor, buildAppTheme().colorScheme.primary);
  });

  testWidgets('wires back, play, fullscreen and episodes buttons',
      (tester) async {
    var back = 0;
    var play = 0;
    var fullscreen = 0;
    var episodes = 0;
    await tester.pumpWidget(_host(
      onBack: () => back++,
      onTogglePlay: () => play++,
      onToggleFullscreen: () => fullscreen++,
      onToggleEpisodes: () => episodes++,
    ));

    await tester.tap(find.byKey(const ValueKey('player-back')));
    await tester.tap(find.byKey(const ValueKey('player-center-play')));
    await tester.tap(find.byKey(const ValueKey('player-fullscreen')));
    await tester.tap(find.byKey(const ValueKey('player-episodes')));
    await tester.pump();

    expect(back, 1);
    expect(play, 1);
    expect(fullscreen, 1);
    expect(episodes, 1);
  });

  testWidgets('shows a spinner instead of the play icon while buffering',
      (tester) async {
    await tester.pumpWidget(_host(buffering: true));
    expect(find.byKey(const ValueKey('player-center-play')), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the pause icon while playing', (tester) async {
    await tester.pumpWidget(_host(playing: true));
    expect(find.byIcon(Icons.pause_rounded), findsNWidgets(2));
  });

  testWidgets('shows the play icon while paused', (tester) async {
    await tester.pumpWidget(_host(playing: false));
    expect(find.byIcon(Icons.play_arrow_rounded), findsNWidgets(2));
  });

  testWidgets('next button fires and disables without a next episode',
      (tester) async {
    var next = 0;
    await tester.pumpWidget(_host(hasNext: true, onNextEpisode: () => next++));
    await tester.tap(find.byKey(const ValueKey('player-next')));
    await tester.pump();
    expect(next, 1);

    await tester.pumpWidget(_host(hasNext: false));
    final button = tester.widget<IconButton>(
        find.byKey(const ValueKey('player-next')));
    expect(button.onPressed, isNull);
  });
}
