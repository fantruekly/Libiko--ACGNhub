import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/novel/linovelib_source.dart';

const _searchHtml = '''
<div class="search-result-list clearfix">
  <div class="imgbox fl se-result-book"><a href="/novel/3676.html"><img src="x.svg" data-original="https://www.linovelib.com/files/article/image/3/3676/3676s.jpg"></a></div>
  <div class="fl se-result-infos">
    <h2 class="tit"><a href="/novel/3676.html">败犬女主太多了</a></h2>
    <div class="bookinfo"><a href="/authorarticle/x.html">雨森</a><em>|</em><a href="/wenku/famitsubunko/1.html">Fami通</a><em>|</em><span>连载</span></div>
    <p>简介文字</p>
  </div>
</div>
''';

void main() {
  test('parseSearchResults reads search result cards', () {
    final items = parseSearchResults(_searchHtml);
    expect(items, hasLength(1));
    final n = items.single;
    expect(n.id, '3676');
    expect(n.title, '败犬女主太多了');
    expect(n.author, '雨森');
    expect(n.coverUrl,
        'https://www.linovelib.com/files/article/image/3/3676/3676s.jpg');
    expect(n.summary, '简介文字');
  });

  test('parseSearchResults returns empty when no results', () {
    expect(parseSearchResults('<div></div>'), isEmpty);
  });

  test('parseSearchResults falls back to img src when data-original missing',
      () {
    final items = parseSearchResults('''
<div class="search-result-list">
  <div class="imgbox"><a href="/novel/1.html"><img src="https://www.linovelib.com/files/a.jpg"></a></div>
  <div class="se-result-infos"><h2 class="tit"><a href="/novel/1.html">书</a></h2></div>
</div>''');
    expect(items.single.coverUrl, 'https://www.linovelib.com/files/a.jpg');
  });
}
