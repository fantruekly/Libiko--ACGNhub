import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/novel/linovelib_source.dart';

void main() {
  test('rankPath builds the ranking url', () {
    expect(LinovelibSource.rankPath('monthvote', 1), '/top/monthvote/1.html');
    expect(LinovelibSource.rankPath('allvisit', 1), '/top/allvisit/1.html');
    expect(LinovelibSource.rankPath('allvisit', 2), '/top/allvisit/2.html');
  });

  test('bunkoPath builds the bunko url', () {
    expect(LinovelibSource.bunkoPath('dengekibunko', 2), '/wenku/dengekibunko/2.html');
  });

  test('source identity', () {
    final s = LinovelibSource();
    expect(s.id, 'linovelib');
    expect(s.name, '哔哩轻小说');
    expect(s.baseUrl, linovelibBaseUrl);
  });

  test('detail/catalog paths', () {
    expect(LinovelibSource.detailPath('5340'), '/novel/5340.html');
    expect(LinovelibSource.catalogPath('5340'), '/novel/5340/catalog');
  });

  test('chapterPath builds the chapter url', () {
    expect(LinovelibSource.chapterPath('5340', '334356'), '/novel/5340/334356.html');
  });
}
