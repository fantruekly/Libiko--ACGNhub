import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/video/resolve_line_fallback.dart';
import 'package:libiko/core/video/resolve_result.dart';
import 'package:libiko/core/video/video_source.dart';
import 'package:libiko/core/video/headless_browser.dart';

const episodes = [
  VideoEpisode(
      id: 'a',
      title: '1',
      index: 0,
      playUrl: 'a',
      sourceId: 's',
      lineId: 'A',
      episodeKey: 'episode:1'),
  VideoEpisode(
      id: 'b',
      title: '1',
      index: 1,
      playUrl: 'b',
      sourceId: 's',
      lineId: 'B',
      episodeKey: 'episode:1'),
  VideoEpisode(
      id: 'c',
      title: '2',
      index: 2,
      playUrl: 'c',
      sourceId: 's',
      lineId: 'C',
      episodeKey: 'episode:2'),
];
void main() {
  test('selected line wins; only definite empty result switches exact episode',
      () async {
    final calls = <String>[];
    final result = await resolveLineFallback(episodes, 0, (ep) async {
      calls.add(ep.id);
      return ep.id == 'a'
          ? const ResolveResult.failed(ResolveFailure.notFound)
          : const ResolveResult.success([MediaCandidate('https://cdn/v.mp4')]);
    }, () => false);
    expect(calls, ['a', 'b']);
    expect(result.$1, 1);
    calls.clear();
    await resolveLineFallback(episodes, 1, (ep) async {
      calls.add(ep.id);
      return const ResolveResult.success([MediaCandidate('https://cdn/v.mp4')]);
    }, () => false);
    expect(calls, ['b']);
  });
  test(
      'timeouts, cancelled work and ambiguous episode labels do not auto-switch',
      () async {
    for (final failure in [
      ResolveFailure.timeout,
      ResolveFailure.network,
      ResolveFailure.notFound
    ]) {
      var calls = 0;
      await resolveLineFallback(episodes, 0, (_) async {
        calls++;
        return ResolveResult.failed(failure);
      }, () => failure == ResolveFailure.notFound);
      expect(calls, 1);
    }
    var calls = 0;
    await resolveLineFallback([episodes[0], episodes[0], episodes[1]], 0,
        (_) async {
      calls++;
      return const ResolveResult.failed(ResolveFailure.notFound);
    }, () => false);
    expect(calls, 1);
  });
}
