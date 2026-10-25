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
  test('unrelated and empty titles require manual selection', () {
    expect(bestMatchIndex('进击的巨人', ['海贼王', '完全无关']), -1);
    expect(bestMatchIndex('', ['资源']), -1);
    expect(titleMatchScore('作品', '完全不同作品名称与其他副标题'),
        lessThan(defaultTitleMatchThreshold));
  });

  test('exposes a configurable confidence threshold', () {
    final score = titleMatchScore('abcd', 'abce');
    expect(score, greaterThan(0));
    expect(bestMatchIndex('abcd', ['abce']), -1);
    expect(bestMatchIndex('abcd', ['abce'], minimumScore: score), 0);
  });

  test('season conflicts cannot win through a shared franchise title', () {
    expect(bestMatchIndex('作品2', ['作品1', '作品 第二季']), 1);
    expect(bestMatchIndex('作品', ['作品2']), -1);
    expect(bestMatchIndex('无职转生 第二季', ['无职转生 第一季']), -1);
    expect(bestMatchIndex('无职转生 第二季', ['无职转生']), -1);
    expect(bestMatchIndex('无职转生', ['无职转生 第二季']), -1);
    expect(bestMatchIndex('无职转生 II', ['无职转生 第一季', '无职转生 第二季']), 1);
    expect(
        bestMatchIndex(
            'Example Season 2', ['Example 1st Season', 'Example 2nd Season']),
        1);
  });

  test('movie OVA and recap editions are not silently matched as TV', () {
    expect(bestMatchIndex('作品', ['作品 剧场版', '作品 OVA', '作品 总集篇']), -1);
    expect(bestMatchIndex('作品 剧场版', ['作品 OVA', '作品 剧场版']), 1);
    expect(bestMatchIndex('作品', ['作品', '作品 剧场版'], format: 'MOVIE'), 1);
  });

  test('metadata aliases improve matching without bypassing season conflicts',
      () {
    expect(
        bestMatchIndex('中文标题', ['Japanese Title'], aliases: ['Japanese Title']),
        0);
    expect(
        bestMatchIndex('中文标题 第二季', ['Japanese Title Season 1'],
            aliases: ['Japanese Title']),
        -1);
    expect(
        titleSearchQueries('中文标题', {
          'titleNative': '日本語',
          'titleEnglish': 'English Title',
          'aliases': ['中文标题', '其他别名'],
          'summary': '不能用简介搜索',
        }),
        ['中文标题', '日本語', 'English Title', '其他别名']);
  });
}
