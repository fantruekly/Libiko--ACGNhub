import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/modules/anime/anime_rule.dart';
import 'package:libiko/modules/anime/anime_source.dart';
import 'package:libiko/core/models/work.dart';

void main() {
  group('AnimeSource', () {
    final rule = AnimeRule.fromJson({
      'name': 'TestSource',
      'baseUrl': 'https://test.com',
      'search': {
        'url': '/search?keyword={keyword}&page={page}',
        'list': '//div[@class="list"]/div',
        'title': './/h3/text()',
        'cover': './/img/@src',
        'link': './/a/@href',
      },
      'detail': {
        'summary': '//div[@class="desc"]/text()',
        'chapters': '//ul[@class="ep"]/li',
        'chapterTitle': './/a/text()',
        'chapterLink': './/a/@href',
      },
      'video': {
        'playUrl': '//video/source/@src',
      },
    });

    test('source has correct properties', () {
      final source = AnimeSource(rule);
      expect(source.type, WorkType.anime);
      expect(source.name, 'TestSource');
      expect(source.baseUrl, 'https://test.com');
    });

    test('resolveUrl resolves relative paths', () {
      final source = AnimeSource(rule);
      expect(source.resolveUrl('http://example.com/img.jpg'),
          'http://example.com/img.jpg');
      expect(source.resolveUrl('//cdn.com/img.jpg'), 'https://cdn.com/img.jpg');
      expect(source.resolveUrl('/img.jpg'), 'https://test.com/img.jpg');
    });

    test('buildUrl replaces placeholders', () {
      final source = AnimeSource(rule);
      final url = source.buildUrl('/search?keyword={keyword}&page={page}',
          keyword: 'test', page: 2);
      expect(url, '/search?keyword=test&page=2');
    });
  });
}
