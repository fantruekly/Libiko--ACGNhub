import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/video/headless_browser.dart';
import 'package:libiko/core/video/resolve_result.dart';
import 'package:libiko/core/video/resolved_stream_cache.dart';

ResolveResult _success(String url) =>
    ResolveResult.success([MediaCandidate(url)]);

void main() {
  test('returns a cached success within its TTL', () {
    var now = DateTime(2026);
    final cache = ResolvedStreamCache(clock: () => now);
    cache.put('https://page/a', _success('https://cdn/a.m3u8'));
    expect(cache.get('https://page/a')?.candidate?.url, 'https://cdn/a.m3u8');
    now = now.add(const Duration(minutes: 16));
    expect(cache.get('https://page/a'), isNull);
  });

  test('uses a short negative TTL for failures', () {
    var now = DateTime(2026);
    final cache = ResolvedStreamCache(clock: () => now);
    cache.put('https://page/b', const ResolveResult.failed(ResolveFailure.notFound));
    expect(cache.get('https://page/b'), isNotNull);
    now = now.add(const Duration(seconds: 31));
    expect(cache.get('https://page/b'), isNull);
  });

  test('evicts the least recently used entry past capacity', () {
    final cache = ResolvedStreamCache(capacity: 2);
    cache.put('https://page/1', _success('https://cdn/1.m3u8'));
    cache.put('https://page/2', _success('https://cdn/2.m3u8'));
    cache.get('https://page/1'); // refresh 1
    cache.put('https://page/3', _success('https://cdn/3.m3u8'));
    expect(cache.get('https://page/1'), isNotNull);
    expect(cache.get('https://page/2'), isNull);
    expect(cache.get('https://page/3'), isNotNull);
  });

  test('normalizes the key by dropping the fragment', () {
    final cache = ResolvedStreamCache();
    cache.put('https://page/a#frag', _success('https://cdn/a.m3u8'));
    expect(cache.get('https://page/a'), isNotNull);
  });

  test('invalidate removes an entry', () {
    final cache = ResolvedStreamCache();
    cache.put('https://page/a', _success('https://cdn/a.m3u8'));
    cache.invalidate('https://page/a');
    expect(cache.get('https://page/a'), isNull);
  });
}
