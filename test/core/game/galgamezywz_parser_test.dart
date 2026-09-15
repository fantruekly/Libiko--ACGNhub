import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/game/galgamezywz_source.dart';

const _listHtml = '''
<section class="container">
  <div class="posts-warp row">
    <div class="col">
      <article class="post-item item-grid">
        <div class="entry-media ratio ratio-3x2">
          <a class="media-img lazy bg-cover bg-center" href="https://game.galgamezywz.org/game/1207" data-bg="https://game.galgamezywz.org/wp-content/uploads/2025/03/cover.webp"></a>
        </div>
        <div class="entry-wrapper">
          <div class="entry-cat-dot"><a href="https://game.galgamezywz.org/lm/wanjiareping">玩家热评游戏</a></div>
          <h2 class="entry-title"><a href="https://game.galgamezywz.org/game/1207" title="金辉恋曲四重奏">金辉恋曲四重奏</a></h2>
          <div class="entry-desc">这是一段简介。</div>
          <div class="entry-meta">
            <span class="meta-date"><time class="pub-date" datetime="2026-09-11T10:21:10+08:00">4 天前</time></span>
            <span class="meta-likes">1</span>
            <span class="meta-fav">7</span>
            <span class="meta-views">4.3K</span>
            <span class="meta-price">0</span>
          </div>
        </div>
      </article>
    </div>
    <div class="col">
      <article class="post-item item-grid">
        <h2 class="entry-title"><a href="https://game.galgamezywz.org/lm/galgame">没有游戏链接的条目</a></h2>
      </article>
    </div>
  </div>
  <nav class="page-nav mt-4"><ul class="pagination">
    <li class="page-item disabled"><span class="page-link">1/171</span></li>
    <li class="page-item"><a class="page-link page-next" href="https://game.galgamezywz.org/page/2">下一页</a></li>
  </ul></nav>
</section>
''';

const _listNoNextHtml = '''
<section class="container">
  <div class="posts-warp row">
    <div class="col">
      <article class="post-item item-grid">
        <h2 class="entry-title"><a href="https://game.galgamezywz.org/game/9">最后一页</a></h2>
      </article>
    </div>
  </div>
  <nav class="page-nav"><ul class="pagination">
    <li class="page-item disabled"><span class="page-link">171/171</span></li>
  </ul></nav>
</section>
''';

const _detailHtml = '''
<div class="archive-shop">
  <div class="img-box"><img class="lazy" src="https://game.galgamezywz.org/wp-content/uploads/cover.jpg"></div>
  <div class="info-box">
    <ul class="article-meta">
      <li>资源分类: <a href="https://game.galgamezywz.org/lm/wanjiareping">玩家热评游戏</a></li>
      <li>浏览热度: (4.3K)</li>
      <li>发布时间: 2026-09-11</li>
      <li>最近更新: 2026-09-12</li>
      <li>游戏大小: 14.3GB</li>
      <li>游戏平台: PC+安卓直装</li>
    </ul>
  </div>
</div>
<h1 class="post-title">金辉恋曲四重奏</h1>
<div class="entry-tags">
  <a rel="tag" href="https://game.galgamezywz.org/bq/hanhua">汉化</a>
  <a rel="tag" href="https://game.galgamezywz.org/bq/pc">PC</a>
</div>
<article class="post-content">
  <p>第一段简介。</p>
  <p>第二段简介。</p>
  <img src="https://game.galgamezywz.org/wp-content/uploads/1.jpg" class="aligncenter wp-image-1">
  <img src="https://game.galgamezywz.org/wp-content/uploads/1.jpg" class="aligncenter">
  <img src="data:image/gif;base64,AAAA">
</article>
''';

void main() {
  test('gameIdFromHref extracts the numeric id', () {
    expect(gameIdFromHref('https://game.galgamezywz.org/game/1207'), '1207');
    expect(gameIdFromHref('/game/9'), '9');
    expect(gameIdFromHref('https://game.galgamezywz.org/lm/galgame'), isNull);
    expect(gameIdFromHref(null), isNull);
  });

  test('parseCount parses K/M suffixes and raw numbers', () {
    expect(parseCount('4.3K'), 4300);
    expect(parseCount('125.2K'), 125200);
    expect(parseCount('6.2K'), 6200);
    expect(parseCount('664'), 664);
    expect(parseCount('浏览热度: (4.3K)'), 4300);
    expect(parseCount(''), isNull);
  });

  test('galgameZywzBrowsePath maps options to paths', () {
    expect(galgameZywzBrowsePath('latest', 1), '/');
    expect(galgameZywzBrowsePath('latest', 3), '/page/3');
    expect(galgameZywzBrowsePath('galgame', 1), '/lm/galgame');
    expect(galgameZywzBrowsePath('galgame', 2), '/lm/galgame/page/2');
    expect(() => galgameZywzBrowsePath('nope', 1), throwsArgumentError);
  });

  test('parseGameList keeps items with a /game/<id> link and skips others', () {
    final items = parseGameList(_listHtml);
    expect(items, hasLength(1));
    expect(items.first.id, '1207');
    expect(items.first.title, '金辉恋曲四重奏');
    expect(items.first.coverUrl,
        'https://game.galgamezywz.org/wp-content/uploads/2025/03/cover.webp');
    expect(items.first.summary, '这是一段简介。');
    expect(items.first.category, '玩家热评游戏');
    expect(items.first.publishedAt, DateTime.parse('2026-09-11T10:21:10+08:00'));
    expect(items.first.views, 4300);
  });

  test('parseHasNextPage follows the next link, else the item-count fallback',
      () {
    expect(parseHasNextPage(_listHtml, itemCount: 1), isTrue);
    expect(parseHasNextPage(_listNoNextHtml, itemCount: 1), isFalse);
    expect(parseHasNextPage('<html></html>', itemCount: 12), isTrue);
    expect(parseHasNextPage('<html></html>', itemCount: 3), isFalse);
  });

  test('parseGameDetail extracts meta, paragraphs, tags and screenshots', () {
    final detail = parseGameDetail(_detailHtml, '$galgameZywzBaseUrl/game/1207');
    expect(detail.game.id, '1207');
    expect(detail.game.title, '金辉恋曲四重奏');
    expect(detail.game.coverUrl,
        'https://game.galgamezywz.org/wp-content/uploads/cover.jpg');
    expect(detail.game.category, '玩家热评游戏');
    expect(detail.game.tags, ['汉化', 'PC']);
    expect(detail.game.views, 4300);
    expect(detail.game.publishedAt, DateTime.parse('2026-09-11'));
    expect(detail.updatedAt, DateTime.parse('2026-09-12'));
    expect(detail.size, '14.3GB');
    expect(detail.platform, 'PC+安卓直装');
    expect(detail.paragraphs, ['第一段简介。', '第二段简介。']);
    expect(detail.screenshots, [
      'https://game.galgamezywz.org/wp-content/uploads/1.jpg',
    ]);
    expect(detail.sourceUrl, '$galgameZywzBaseUrl/game/1207');
  });
}
