import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/modules/anime/anime_rule.dart';

void main() {
  group('AnimeRule', () {
    final json = {
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
        'tags': '//span[@class="tag"]/text()',
        'chapters': '//ul[@class="ep"]/li',
        'chapterTitle': './/a/text()',
        'chapterLink': './/a/@href',
      },
      'video': {
        'playUrl': '//video/source/@src',
        'resolutions': '//select[@class="res"]/option/@value',
      },
    };

    test('fromJson parses correctly', () {
      final rule = AnimeRule.fromJson(json);
      expect(rule.name, 'TestSource');
      expect(rule.baseUrl, 'https://test.com');
      expect(rule.search.title, './/h3/text()');
      expect(rule.detail.summary, '//div[@class="desc"]/text()');
      expect(rule.video.playUrl, '//video/source/@src');
    });

    test('toJsonString and fromJsonString roundtrip', () {
      final rule = AnimeRule.fromJson(json);
      final rule2 = AnimeRule.fromJsonString(rule.toJsonString());
      expect(rule2.name, rule.name);
      expect(rule2.baseUrl, rule.baseUrl);
    });

    test('optional fields are null when missing', () {
      final minimalJson = {
        'name': 'Minimal',
        'baseUrl': 'https://min.com',
        'search': {
          'url': '/s',
          'list': '//div',
          'title': './/h3/text()',
          'cover': './/img/@src',
          'link': './/a/@href',
        },
        'detail': {
          'summary': '//div/text()',
          'chapters': '//li',
          'chapterTitle': './/a/text()',
          'chapterLink': './/a/@href',
        },
        'video': {
          'playUrl': '//video/@src',
        },
      };
      final rule = AnimeRule.fromJson(minimalJson);
      expect(rule.search.nextPage, isNull);
      expect(rule.detail.tags, isNull);
      expect(rule.video.resolutions, isNull);
    });
  });
}