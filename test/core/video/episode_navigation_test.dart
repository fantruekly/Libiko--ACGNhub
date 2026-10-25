import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/video/video_source.dart';

VideoEpisode _ep(String title, String line, int index) => VideoEpisode(
    id: '$line/$index',
    title: title,
    index: index,
    playUrl: '$line/$index',
    sourceId: 'source',
    lineId: line,
    episodeKey: episodeKeyFromTitle(title));

void main() {
  test('next episode stays in its source and line, including the line end', () {
    final episodes = [
      _ep('第1集', 'a', 0),
      _ep('第2集', 'a', 1),
      _ep('第1集', 'b', 2),
      _ep('第2集', 'b', 3)
    ];
    expect(nextEpisodeIndex(episodes, 0), 1);
    expect(nextEpisodeIndex(episodes, 1), isNull);
    expect(nextEpisodeIndex(episodes, 2), 3);
    expect(nextEpisodeIndex(episodes, -1), isNull);
    expect(matchingEpisodeIndex(episodes, 1, 'b'), 3);
  });

  test(
      'cross-line mapping uses identity and declines missing or duplicate keys',
      () {
    final episodes = [
      _ep('第2集', 'a', 0),
      _ep('第1集', 'b', 1),
      _ep('第3集', 'b', 2),
      _ep('OVA 2', 'b', 3)
    ];
    expect(matchingEpisodeIndex(episodes, 0, 'b'), isNull);
    final duplicates = [
      _ep('第2集', 'a', 0),
      _ep('02', 'b', 1),
      _ep('第2话', 'b', 2)
    ];
    expect(matchingEpisodeIndex(duplicates, 0, 'b'), isNull);
    expect(episodeKeyFromTitle('第02集'), episodeKeyFromTitle('EP02'));
    expect(episodeKeyFromTitle('OVA 2'), isNot(episodeKeyFromTitle('第2集')));
    expect(episodeKeyFromTitle('第2集 上'), isNot(episodeKeyFromTitle('第2集 下')));
    expect(episodeKeyFromTitle(''), isNull);
  });

  test('legacy episodes remain a single line and cannot blindly switch lines',
      () {
    const episodes = [
      VideoEpisode(id: '1', title: '1', index: 0, playUrl: '1'),
      VideoEpisode(id: '2', title: '2', index: 1, playUrl: '2')
    ];
    expect(nextEpisodeIndex(episodes, 0), 1);
    expect(matchingEpisodeIndex(episodes, 0, 'b'), isNull);
  });
}
