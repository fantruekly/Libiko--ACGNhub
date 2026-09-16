import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/comic/models.dart';

void main() {
  test('Comic.fromJs maps the source result', () {
    final comic = Comic.fromJs({
      'id': '1',
      'title': 'T',
      'subtitle': 'S',
      'cover': 'c.jpg',
      'tags': ['a', 'b'],
      'description': 'D',
    });
    expect(comic.id, '1');
    expect(comic.title, 'T');
    expect(comic.subtitle, 'S');
    expect(comic.cover, 'c.jpg');
    expect(comic.tags, ['a', 'b']);
    expect(comic.description, 'D');
  });

  test('Comic.fromJs tolerates missing optional fields', () {
    final comic = Comic.fromJs({'id': '1', 'title': 'T'});
    expect(comic.subtitle, isNull);
    expect(comic.tags, isEmpty);
    expect(comic.cover, isNull);
  });

  test('ComicDetails.fromJs maps chapters and recommend', () {
    final details = ComicDetails.fromJs({
      'id': '1',
      'title': 'T',
      'chapters': {'c1': '第1话', 'c2': '第2话'},
      'recommend': ['x', 'y'],
    });
    expect(details.chapters, {'c1': '第1话', 'c2': '第2话'});
    expect(details.recommendIds, ['x', 'y']);
  });

  test('Comic.fromJs flattens a map of tags', () {
    final comic = Comic.fromJs({
      'id': '1',
      'title': 'T',
      'tags': {
        '作者': ['Alice'],
        '标签': ['Action', 'Comedy'],
      },
    });
    expect(comic.tags, ['Alice', 'Action', 'Comedy']);
  });

  test('ComicDetails.fromJs flattens grouped chapters', () {
    final details = ComicDetails.fromJs({
      'id': '1',
      'title': 'T',
      'chapters': {
        '第一卷': {'c1': '第1话', 'c2': '第2话'},
        '第二卷': {'c3': '第3话'},
      },
    });
    expect(details.chapters, {'c1': '第1话', 'c2': '第2话', 'c3': '第3话'});
  });

  test('ComicEp.fromJs maps the image list', () {
    final ep = ComicEp.fromJs({'images': ['u1', 'u2']});
    expect(ep.images, ['u1', 'u2']);
  });

  test('ImageLoadingConfig.fromJs maps headers', () {
    final config = ImageLoadingConfig.fromJs({
      'url': 'u',
      'headers': {'referer': 'r'},
      'method': 'GET',
    });
    expect(config.url, 'u');
    expect(config.headers, {'referer': 'r'});
    expect(config.method, 'GET');
  });
}
