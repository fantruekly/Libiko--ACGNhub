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
}
