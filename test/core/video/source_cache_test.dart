import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/video/source_cache.dart';
import 'package:libiko/core/video/video_source.dart';

void main() {
  test('caches search results within the TTL', () {
    var now = DateTime(2026);
    final cache = SourceCache(clock: () => now);
    cache.putSearch(
      'r:a',
      'kw',
      const [VideoItem(id: '1', title: 't', detailUrl: 'u')],
    );
    expect(cache.search('r:a', 'kw'), hasLength(1));
    now = now.add(const Duration(minutes: 11));
    expect(cache.search('r:a', 'kw'), isNull);
  });

  test('separates search and episode entries by source and key', () {
    final cache = SourceCache();
    const eps = [
      VideoEpisode(id: '1', title: 'e', index: 0, playUrl: 'p'),
    ];
    cache.putEpisodes('r:a', 'url', eps);
    expect(cache.episodes('r:a', 'url'), hasLength(1));
    expect(cache.episodes('r:b', 'url'), isNull);
    expect(cache.search('r:a', 'url'), isNull);
  });

  test('evicts the least recently used past capacity', () {
    final cache = SourceCache(capacity: 2);
    cache.putSearch('s', '1', const <VideoItem>[]);
    cache.putSearch('s', '2', const <VideoItem>[]);
    cache.search('s', '1'); // refresh 1
    cache.putSearch('s', '3', const <VideoItem>[]);
    expect(cache.search('s', '1'), isNotNull);
    expect(cache.search('s', '2'), isNull);
    expect(cache.search('s', '3'), isNotNull);
  });

  test('caches empty results too', () {
    final cache = SourceCache();
    cache.putSearch('s', 'none', const <VideoItem>[]);
    expect(cache.search('s', 'none'), isEmpty);
  });
}
