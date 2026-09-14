import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/novel/linovelib_source.dart';
import 'package:acgnhub/core/novel/models.dart';

void main() {
  test('rankPath builds the ranking url', () {
    expect(LinovelibSource.rankPath('monthvote', 1), '/top/monthvote/1.html');
    expect(LinovelibSource.rankPath('allvisit', 1), '/top.html');
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

  test('allvisit is a single-page ranking', () {
    expect(
        LinovelibSource.isSinglePageRanking(
            const NovelBrowse(NovelBrowseKind.ranking, 'allvisit')),
        isTrue);
    expect(
        LinovelibSource.isSinglePageRanking(
            const NovelBrowse(NovelBrowseKind.ranking, 'monthvote')),
        isFalse);
    expect(
        LinovelibSource.isSinglePageRanking(
            const NovelBrowse(NovelBrowseKind.bunko, 'dengekibunko')),
        isFalse);
  });
}
