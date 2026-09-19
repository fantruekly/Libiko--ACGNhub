import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/video/title_match.dart';

void main() {
  test('normalizeTitle strips case, spaces and punctuation', () {
    expect(normalizeTitle('无职转生 II ～异世界～'), normalizeTitle('无职转生II异世界'));
    expect(normalizeTitle('  Foo.Bar!  '), 'foobar');
  });

  test('bestMatchIndex picks the closest candidate', () {
    final c = ['无职转生 第二季', '无职转生 第一季', '进击的巨人'];
    expect(bestMatchIndex('无职转生 第二季', c), 0);
    expect(bestMatchIndex('进击的巨人', c), 2);
  });

  test('bestMatchIndex returns -1 for no candidates', () {
    expect(bestMatchIndex('x', const []), -1);
  });
}
