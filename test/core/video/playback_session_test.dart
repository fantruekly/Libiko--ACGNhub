import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/video/playback_session.dart';
import 'package:libiko/core/video/headless_browser.dart';
import 'package:libiko/core/video/video_source.dart';

void main() {
  test('resolved empty headers never restore a rejected Referer', () {
    const episode = VideoEpisode(
        id: '1',
        title: '1',
        index: 0,
        playUrl: 'https://page/',
        referer: 'https://blocked/',
        userAgent: 'UA');
    expect(
        playbackHeaders(
            const MediaCandidate('https://cdn/', headersResolved: true),
            episode),
        isEmpty);
    expect(playbackHeaders(const MediaCandidate('https://cdn/'), episode),
        {'User-Agent': 'UA', 'Referer': 'https://blocked/'});
  });
  testWidgets('startup timeout includes time before open completes',
      (tester) async {
    var timedOut = 0;
    final session = PlaybackSession(onTimeout: () => timedOut++, onSlow: () {});
    session.begin();
    await tester.pump(const Duration(seconds: 15));
    expect(timedOut, 1);
    session.dispose();
  });
  testWidgets('progress resets stall deadline, seeking does not mark started',
      (tester) async {
    var timedOut = 0;
    final session = PlaybackSession(onTimeout: () => timedOut++, onSlow: () {});
    session.begin();
    session.seek(const Duration(minutes: 5));
    expect(session.started, false);
    expect(session.progress(const Duration(minutes: 5, seconds: 1)), true);
    await tester.pump(const Duration(seconds: 19));
    session.progress(const Duration(minutes: 5, seconds: 2));
    await tester.pump(const Duration(seconds: 19));
    expect(timedOut, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(timedOut, 1);
    session.dispose();
  });
  testWidgets('pausing suspends timeout and switching rejects old events',
      (tester) async {
    var timedOut = 0;
    final session = PlaybackSession(onTimeout: () => timedOut++, onSlow: () {});
    final old = session.begin();
    session.pause(true);
    await tester.pump(const Duration(minutes: 1));
    expect(timedOut, 0);
    session.begin();
    expect(session.accepts(old), false);
    session.dispose();
    await tester.pump(const Duration(minutes: 1));
    expect(timedOut, 0);
  });
}
