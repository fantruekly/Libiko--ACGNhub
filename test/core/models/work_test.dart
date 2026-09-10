import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/models/work.dart';

void main() {
  group('Work', () {
    test('fromJson and toJson roundtrip', () {
      final json = {
        'id': 'test_1',
        'sourceId': 'src_1',
        'sourceName': 'TestSource',
        'type': 'anime',
        'title': 'Test Anime',
        'coverUrl': 'https://example.com/cover.jpg',
        'summary': 'A test anime',
        'tags': ['action', 'comedy'],
        'author': 'Test Author',
        'extra': {'year': 2024},
      };
      final work = Work.fromJson(json);
      expect(work.toJson(), json);
    });

    test('default values', () {
      final work = Work(
        id: '1',
        sourceId: 's1',
        sourceName: 'S',
        type: WorkType.anime,
        title: 'T',
      );
      expect(work.tags, isEmpty);
      expect(work.extra, isEmpty);
      expect(work.coverUrl, isNull);
    });

    test('Work exposes anime metadata getters from extra', () {
      const work = Work(
        id: 'anilist_1',
        sourceId: 'anilist',
        sourceName: 'AniList',
        type: WorkType.anime,
        title: 'Test',
        extra: {'anilistId': 1, 'malId': 2, 'bannerUrl': 'https://x/b.jpg'},
      );
      expect(work.anilistId, 1);
      expect(work.malId, 2);
      expect(work.bannerUrl, 'https://x/b.jpg');
    });
  });
}