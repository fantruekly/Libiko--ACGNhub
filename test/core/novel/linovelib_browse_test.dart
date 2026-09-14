import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/novel/linovelib_source.dart';

void main() {
  test('browseGroups has the two expected groups', () {
    final groups = LinovelibSource().browseGroups;
    expect(groups, hasLength(2));
    expect(groups.map((g) => g.label).toList(), ['排行', '文库']);
  });

  test('ranking group exposes ranking option keys', () {
    final ranking = LinovelibSource()
        .browseGroups
        .firstWhere((g) => g.label == '排行');
    final keys = ranking.options.map((o) => o.key).toList();
    expect(keys, containsAll(['allvisit', 'monthvote', 'newhot']));
  });

  test('bunko group exposes bunko option keys', () {
    final bunko =
        LinovelibSource().browseGroups.firstWhere((g) => g.label == '文库');
    final keys = bunko.options.map((o) => o.key).toList();
    expect(
      keys,
      containsAll(['dengekibunko', 'chineselightnovel', 'other']),
    );
  });

  test('browsePath routes ranking keys to the ranking path', () {
    expect(LinovelibSource.browsePath('allvisit', 1), '/top/allvisit/1.html');
    expect(LinovelibSource.browsePath('allvisit', 2), '/top/allvisit/2.html');
  });

  test('browsePath routes bunko keys to the bunko path', () {
    expect(
      LinovelibSource.browsePath('dengekibunko', 2),
      '/wenku/dengekibunko/2.html',
    );
  });
}
