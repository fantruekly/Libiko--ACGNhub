import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/comic/explore_result.dart';
import 'package:libiko/core/comic/models.dart';
import 'package:libiko/modules/comic/comic_providers.dart';

List<Comic> _comics(String prefix, int count) =>
    [for (var i = 0; i < count; i++) Comic(id: '$prefix$i', title: '$prefix$i')];

void main() {
  test('aligns a 25/page server section to 48', () async {
    Future<ExplorePage> fetch(int index) async =>
        ExplorePage(comics: _comics('p$index-', 25), maxPage: 3);
    final p1 = await buildAlignedExplorePage(
        page: 1, pageSize: 48, cursorPaged: false, fetch: fetch);
    expect(p1.comics.length, 48);
    expect(p1.hasNext, isTrue);
    expect(p1.maxPage, isNull);
    final p2 = await buildAlignedExplorePage(
        page: 2, pageSize: 48, cursorPaged: false, fetch: fetch);
    expect(p2.comics.length, 27);
    expect(p2.hasNext, isFalse);
  });

  test('an exact multiple has no phantom next page', () async {
    Future<ExplorePage> fetch(int index) async =>
        ExplorePage(comics: _comics('p$index-', 48), maxPage: 2);
    final p1 = await buildAlignedExplorePage(
        page: 1, pageSize: 48, cursorPaged: false, fetch: fetch);
    expect(p1.comics.length, 48);
    expect(p1.hasNext, isTrue);
    final p2 = await buildAlignedExplorePage(
        page: 2, pageSize: 48, cursorPaged: false, fetch: fetch);
    expect(p2.comics.length, 48);
    expect(p2.hasNext, isFalse);
  });

  test('a cursor section chains via next', () async {
    Future<ExplorePage> fetch(int index) async => ExplorePage(
        comics: _comics('c$index-', 25),
        next: index < 3 ? '${index + 1}' : null);
    final p1 = await buildAlignedExplorePage(
        page: 1, pageSize: 48, cursorPaged: true, fetch: fetch);
    expect(p1.comics.length, 48);
    expect(p1.hasNext, isTrue);
    final p2 = await buildAlignedExplorePage(
        page: 2, pageSize: 48, cursorPaged: true, fetch: fetch);
    expect(p2.comics.length, 27);
    expect(p2.hasNext, isFalse);
  });

  test('an empty page stops the accumulation', () async {
    Future<ExplorePage> fetch(int index) async =>
        ExplorePage(comics: index == 1 ? _comics('p', 10) : const []);
    final p1 = await buildAlignedExplorePage(
        page: 1, pageSize: 48, cursorPaged: false, fetch: fetch);
    expect(p1.comics.length, 10);
    expect(p1.hasNext, isFalse);
  });
}
