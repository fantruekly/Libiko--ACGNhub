import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/novel/linovelib_source.dart';

const _mobileHtml = '''
<ol class="book-ol book-ol-normal">
  <li class="book-li"><a href="/novel/22.html" class="book-layout">
    <div class="book-cover"><img src="x.svg" data-src="https://www.bilinovel.com/files/article/image/0/22/22s.jpg" class="lazyload" alt="加速世界"></div>
    <div class="book-cell">
      <div class="book-title-x"><h4 class="book-title">加速世界</h4></div>
      <p class="book-desc">简介</p>
      <div class="book-meta">
        <div class="book-meta-l"><span class="book-author"><svg class="icon icon-human"><title>作者</title><use xlink:href="#icon-human"></use></svg>川原砾</span></div>
        <div class="book-meta-r"><span class="tag-small-group"><em class="tag-small yellow">校园 科幻</em><em class="tag-small red">连载</em></span></div>
      </div>
    </div>
  </a></li>
</ol>
<div class="pagelink" id="pagelink"><a href="/wenku/dengekibunko/1.html" class="first">1</a><strong>1</strong><a href="/wenku/dengekibunko/2.html">2</a><a href="/wenku/dengekibunko/21.html" class="last">21</a></div>
''';

void main() {
  test('parseMobileBookList reads mobile book cards', () {
    final items = parseMobileBookList(_mobileHtml);
    expect(items, hasLength(1));
    final n = items.single;
    expect(n.id, '22');
    expect(n.title, '加速世界');
    expect(n.coverUrl, 'https://www.bilinovel.com/files/article/image/0/22/22s.jpg');
    expect(n.author, '川原砾');
    expect(n.tags, ['校园', '科幻']);
  });

  test('mobileHasNextPage uses the last page link', () {
    expect(mobileHasNextPage(_mobileHtml, 1), isTrue);
    expect(mobileHasNextPage(_mobileHtml, 20), isTrue);
    expect(mobileHasNextPage(_mobileHtml, 21), isFalse);
  });
}
