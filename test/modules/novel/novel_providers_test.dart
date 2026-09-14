import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/novel/models.dart';
import 'package:acgnhub/modules/novel/novel_providers.dart';

void main() {
  test('flattenHome merges sections and dedupes by id', () {
    const home = NovelHome(sections: [
      NovelSection(title: 'a', items: [Novel(id: '1', title: 'A'), Novel(id: '2', title: 'B')]),
      NovelSection(title: 'b', items: [Novel(id: '2', title: 'B'), Novel(id: '3', title: 'C')]),
    ]);
    final flat = flattenHome(home);
    expect(flat.map((n) => n.id), ['1', '2', '3']);
  });
}
