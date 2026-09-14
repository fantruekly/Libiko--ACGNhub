import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/novel/linovelib_source.dart';

const _bookListHtml = '''
<div class="tab-lists qtbg_color">
  <div class="top-title clearfix"><div class="title fl">强推榜</div></div>
  <div class="lists"><ul>
    <li class="postion-right">
      <div class="imgbox fl"><a href="/novel/2059.html"><img src="x.svg" data-original="https://www.linovelib.com/files/article/image/2/2059/2059s.jpg" alt="安达与岛村"></a></div>
      <a class="title" href="/novel/2059.html" target="_blank" title="">安达与岛村</a>
      <a class="author" href="/authorarticle/入间人间.html" title="入间人间">入间人间</a>
      <a class="cate" href="/wenku/dengekibunko/1.html" title="">[电击文库]</a>
    </li>
    <li><a class="author2" href="/authorarticle/x.html">某人</a><a href="/novel/4649.html" title="玩乐关系">玩乐关系</a></li>
  </ul></div>
</div>
''';

const _rankHtml = '''
<div class="rank_i_lists">
  <div class="borderB_c_dsh rank_i_li rank_i_li1 clearfix">
    <div class="rank_i_num fr">1</div>
    <div class="rank_i_bname fr">
      <a href="/novel/5340.html" class="rank_i_l_a_book">不相容的異種族妻子們</a>
      <a href="/authorarticle/x.html" class="rank_i_l_a_author">이만두</a>
      <a href="/wenku/0/1.html" class="rank_i_l_a_category">[novelpia]</a>
      <div class="rank_i_l_font">115人推荐</div>
    </div>
    <div class="rank_i_bcount fl"><a href="/novel/5340.html"><img data-original="https://www.linovelib.com/files/article/image/5/5340/5340s.jpg"></a></div>
  </div>
</div>
''';

const _nextPageHtml = '<div class="pagination"><a href="/top/monthvote/2.html">下一页</a></div>';

void main() {
  test('novelIdFromHref extracts id', () {
    expect(novelIdFromHref('/novel/2059.html'), '2059');
    expect(novelIdFromHref('https://www.linovelib.com/novel/5340.html'), '5340');
    expect(novelIdFromHref('/wenku/dengekibunko/1.html'), isNull);
    expect(novelIdFromHref(null), isNull);
  });

  test('parseBookList keeps only book entries with a.title', () {
    final items = parseBookList(_bookListHtml);
    expect(items, hasLength(1));
    expect(items.first.id, '2059');
    expect(items.first.title, '安达与岛村');
    expect(items.first.author, '入间人间');
    expect(items.first.coverUrl, 'https://www.linovelib.com/files/article/image/2/2059/2059s.jpg');
    expect(items.first.tags, ['电击文库']);
  });

  test('parseHome returns titled sections', () {
    final sections = parseHome(_bookListHtml);
    expect(sections, hasLength(1));
    expect(sections.first.title, '强推榜');
    expect(sections.first.items.single.title, '安达与岛村');
  });

  test('parseRankRows parses rank rows', () {
    final items = parseRankRows(_rankHtml);
    expect(items, hasLength(1));
    expect(items.first.id, '5340');
    expect(items.first.title, '不相容的異種族妻子們');
    expect(items.first.author, '이만두');
    expect(items.first.coverUrl, 'https://www.linovelib.com/files/article/image/5/5340/5340s.jpg');
    expect(items.first.extra['rank'], 1);
  });

  test('hasNextPage detects the next link', () {
    expect(hasNextPage(_nextPageHtml), isTrue);
    expect(hasNextPage(_bookListHtml), isFalse);
  });
}
