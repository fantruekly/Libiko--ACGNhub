import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/game/nekogal_source.dart';

const _listHtml = '''
<div class="posts-row ajaxpager">
  <posts class="posts-item list ajax-item flex">
    <div class="item-thumbnail"><a href="/archives/6661"><img src="/thumbnail.svg" data-src="https://pan.nekogal.top/f/x/cover.jpg" class="lazyload"></a></div>
    <h2 class="item-heading"><a href="/archives/6661">【PC游戏/机翻】制服女友3</a></h2>
    <div class="item-excerpt muted-color">游戏简介文本。</div>
    <div class="item-tags"><a href="/archives/tag/adv" class="but"># ADV</a></div>
    <item class="meta-author"><span title="2026-09-14 20:56:06">20小时前</span></item>
    <div class="meta-right"><item class="meta-comm">1</item><item class="meta-view">451</item><item class="meta-like">8</item></div>
  </posts>
  <posts class="posts-item list ajax-item">
    <h2 class="item-heading"><a href="/archives/category/pcgame">没有详情链接</a></h2>
  </posts>
</div>
<nav class="navigation pagination"><a class="next page-numbers" href="/archives/category/pcgame/page/2">下一页</a></nav>
''';

const _listNoNextHtml = '''
<div class="posts-row ajaxpager">
  <posts class="posts-item list ajax-item">
    <h2 class="item-heading"><a href="/archives/9">最后一页</a></h2>
  </posts>
</div>
<nav class="navigation pagination"><span class="page-numbers current">1</span></nav>
''';

const _detailHtml = '''
<div class="single-head-cover"><div class="graphic single-cover imgbox-container">
  <img class="fit-cover lazyload" src="/thumbnail-lg.svg" data-src="https://pan.nekogal.top/f/x/cover.jpg">
  <h1 class="article-title title-h-left">【PC游戏/机翻】制服女友3</h1>
  <ul class="breadcrumb"><a href="/archives/category/pcgame">PC资源</a></ul>
  <div class="post-metas"><item class="meta-view">451</item><item class="meta-like">8</item></div>
</div></div>
<div class="px12-sm muted-2-color text-ellipsis"><span data-toggle="tooltip" data-placement="bottom" title="2026年09月14日 20:56发布">21小时前发布</span></div>
<article class="article"><div class="article-content"><div class="wp-posts-content">
  <h2>游戏简介</h2>
  <p>第一段简介。</p>
  <p>第二段简介。</p>
  <img src="/lazy.svg" data-src="https://pan.nekogal.top/f/x/1.jpg">
  <img data-src="https://pan.nekogal.top/f/x/1.jpg">
  <img src="data:image/gif;base64,AAAA">
</div></div></article>
<div class="theme-box article-tags">
  <a class="but c-blue" href="/archives/category/pcgame">PC资源</a>
  <a class="but c-yellow" href="/archives/category/pcgame/hhzy">汉化资源</a>
  <a href="/archives/tag/adv" class="but"># ADV</a>
</div>
''';

void main() {
  test('nekogalIdFromHref extracts the numeric id', () {
    expect(nekogalIdFromHref('https://www.nekogal.com/archives/6661'), '6661');
    expect(nekogalIdFromHref('/archives/9'), '9');
    expect(nekogalIdFromHref('/archives/category/pcgame'), isNull);
    expect(nekogalIdFromHref(null), isNull);
  });

  test('parseNekogalCount strips non-digits', () {
    expect(parseNekogalCount('451'), 451);
    expect(parseNekogalCount('1.2K'), 12);
    expect(parseNekogalCount(''), isNull);
  });

  test('nekogalBrowsePath maps options to paths', () {
    expect(nekogalBrowsePath('pcgame', 1), '/archives/category/pcgame');
    expect(nekogalBrowsePath('pcgame', 3), '/archives/category/pcgame/page/3');
    expect(nekogalBrowsePath('hhzy', 1), '/archives/category/pcgame/hhzy');
    expect(nekogalBrowsePath('pegame', 2), '/archives/category/pegame/page/2');
    expect(() => nekogalBrowsePath('nope', 1), throwsArgumentError);
  });

  test('parseNekogalList parses items and skips link-less ones', () {
    final items = parseNekogalList(_listHtml);
    expect(items, hasLength(1));
    expect(items.first.id, '6661');
    expect(items.first.title, '【PC游戏/机翻】制服女友3');
    expect(items.first.coverUrl, 'https://pan.nekogal.top/f/x/cover.jpg');
    expect(items.first.summary, '游戏简介文本。');
    expect(items.first.publishedAt, DateTime.parse('2026-09-14 20:56:06'));
    expect(items.first.views, 451);
    expect(items.first.extra['url'], 'https://www.nekogal.com/archives/6661');
  });

  test('parseNekogalHasNext follows the next link, else the item-count fallback',
      () {
    expect(parseNekogalHasNext(_listHtml, itemCount: 1), isTrue);
    expect(parseNekogalHasNext(_listNoNextHtml, itemCount: 1), isFalse);
    expect(parseNekogalHasNext('<html></html>', itemCount: 12), isTrue);
    expect(parseNekogalHasNext('<html></html>', itemCount: 3), isFalse);
  });

  test('parseNekogalDetail extracts fields', () {
    final detail =
        parseNekogalDetail(_detailHtml, 'https://www.nekogal.com/archives/6661');
    expect(detail.game.id, '6661');
    expect(detail.game.title, '【PC游戏/机翻】制服女友3');
    expect(detail.game.coverUrl, 'https://pan.nekogal.top/f/x/cover.jpg');
    expect(detail.game.category, 'PC资源');
    expect(detail.game.tags, ['ADV']);
    expect(detail.game.views, 451);
    expect(detail.game.publishedAt, DateTime(2026, 9, 14));
    expect(detail.paragraphs, ['第一段简介。', '第二段简介。']);
    expect(detail.screenshots, ['https://pan.nekogal.top/f/x/1.jpg']);
    expect(detail.size, isNull);
    expect(detail.platform, isNull);
    expect(detail.sourceUrl, 'https://www.nekogal.com/archives/6661');
  });
}
