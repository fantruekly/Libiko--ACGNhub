import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/images/cover_ratio_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('returns null for an unknown url', () async {
    expect(await CoverRatioCache().ratioOf('https://x/a.jpg'), isNull);
  });

  test('remembers a ratio and reads it back', () async {
    final cache = CoverRatioCache();
    await cache.remember('https://x/a.jpg', 0.75);
    expect(await cache.ratioOf('https://x/a.jpg'), 0.75);
  });

  test('a second instance reads the persisted value', () async {
    await CoverRatioCache().remember('https://x/a.jpg', 0.5);
    expect(await CoverRatioCache().ratioOf('https://x/a.jpg'), 0.5);
  });

  test('ignores non-positive, NaN and infinite ratios', () async {
    final cache = CoverRatioCache();
    await cache.remember('https://x/a.jpg', 0);
    await cache.remember('https://x/b.jpg', -1);
    await cache.remember('https://x/c.jpg', double.nan);
    await cache.remember('https://x/d.jpg', double.infinity);
    expect(await cache.ratioOf('https://x/a.jpg'), isNull);
    expect(await cache.ratioOf('https://x/b.jpg'), isNull);
    expect(await cache.ratioOf('https://x/c.jpg'), isNull);
    expect(await cache.ratioOf('https://x/d.jpg'), isNull);
  });
}
