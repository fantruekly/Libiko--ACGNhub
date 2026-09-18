import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/comic/comic_image.dart';

void main() {
  group('pageCacheKey', () {
    test('composes the source, comic, chapter and url with pipes', () {
      expect(
        pageCacheKey('src', 'c1', 'ch1', 'https://x/1.jpg'),
        'src|c1|ch1|https://x/1.jpg',
      );
    });

    test('changes when any component changes', () {
      final base = pageCacheKey('src', 'c1', 'ch1', 'https://x/1.jpg');
      expect(pageCacheKey('other', 'c1', 'ch1', 'https://x/1.jpg'),
          isNot(base));
      expect(pageCacheKey('src', 'c2', 'ch1', 'https://x/1.jpg'),
          isNot(base));
      expect(pageCacheKey('src', 'c1', 'ch2', 'https://x/1.jpg'),
          isNot(base));
      expect(pageCacheKey('src', 'c1', 'ch1', 'https://x/2.jpg'),
          isNot(base));
    });
  });

  group('trimCache', () {
    test('evicts the oldest entry once the cap is exceeded', () {
      final cache = LinkedHashMap<String, String>.from({
        'a': '1',
        'b': '2',
        'c': '3',
      });
      final evicted = <String>[];

      trimCache(cache, 2, evicted.add);

      expect(cache.keys, ['b', 'c']);
      expect(evicted, ['1']);
    });

    test('drops every entry beyond the cap, oldest first', () {
      final cache = LinkedHashMap<String, String>.from({
        'a': '1',
        'b': '2',
        'c': '3',
        'd': '4',
      });
      final evicted = <String>[];

      trimCache(cache, 1, evicted.add);

      expect(cache.keys, ['d']);
      expect(evicted, ['1', '2', '3']);
    });

    test('leaves a cache at or under the cap untouched', () {
      final cache = LinkedHashMap<String, String>.from({'a': '1'});
      final evicted = <String>[];

      trimCache(cache, 2, evicted.add);

      expect(cache.keys, ['a']);
      expect(evicted, isEmpty);
    });
  });

  group('evictOldest', () {
    test('removes the first inserted entry', () {
      final cache = LinkedHashMap<String, String>.from({
        'a': '1',
        'b': '2',
      });
      final evicted = <String>[];

      evictOldest(cache, evicted.add);

      expect(cache.keys, ['b']);
      expect(evicted, ['1']);
    });

    test('is a no-op on an empty cache', () {
      final cache = LinkedHashMap<String, String>.from({});
      var called = false;

      evictOldest(cache, (_) => called = true);

      expect(called, isFalse);
    });
  });
}
