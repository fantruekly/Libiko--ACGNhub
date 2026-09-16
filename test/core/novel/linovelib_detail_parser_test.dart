import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/novel/linovelib_source.dart';

const _detailHtml = '''
<html><head>
<meta property="og:novel:author" content="이만두" />
<meta property="og:novel:tags" content="病娇 后宫 恋爱 " />
<meta property="og:novel:status" content="连载" />
</head><body>
<div class="book-html-box">
  <div class="book-main">
    <div class="book-detail clearfix">
      <div class="book-img fl"><img src="https://www.linovelib.com/files/article/image/5/5340/5340s.jpg" alt="x"></div>
      <div class="book-info">
        <h1 class="book-name">不相容的異種族妻子們</h1>
        <div class="book-dec">一夫多妻制已經遭到廢除。我們不必再勉強彼此共同生活了……</div>
      </div>
    </div>
  </div>
</div>
</body></html>
''';

const _catalogHtml = '''
<div class="volume-list" id="volume-list">
  <div class="volume clearfix">
    <div class="volume-info"><h2 class="v-line"><a href="/novel/5340/vol_333606.html">不相容的異種族妻子們 插圖</a></h2></div>
    <ul class="chapter-list clearfix">
      <li class="col-4"><a href="/novel/5340/333607.html">封面</a></li>
      <li class="col-4"><a href="/novel/5340/333608.html">粉絲同人圖</a></li>
    </ul>
  </div>
  <div class="volume clearfix">
    <div class="volume-info"><h2 class="v-line"><a href="/novel/5340/vol_333597.html">不相容的異種族妻子們 正文</a></h2></div>
    <ul class="chapter-list clearfix">
      <li class="col-4"><a href="/novel/5340/334356.html">第60話 規則（2）</a></li>
    </ul>
  </div>
</div>
''';

void main() {
  test('chapterIdFromHref takes the second number', () {
    expect(chapterIdFromHref('/novel/5340/333607.html'), '333607');
    expect(chapterIdFromHref('https://www.linovelib.com/novel/5340/334356.html'), '334356');
    expect(chapterIdFromHref('/novel/5340.html'), isNull);
    expect(chapterIdFromHref(null), isNull);
  });

  test('parseNovelDetailHeader parses header fields', () {
    final novel = parseNovelDetailHeader(_detailHtml, '5340');
    expect(novel.id, '5340');
    expect(novel.title, '不相容的異種族妻子們');
    expect(novel.author, '이만두');
    expect(novel.coverUrl,
        'https://www.linovelib.com/files/article/image/5/5340/5340s.jpg');
    expect(novel.tags, ['病娇', '后宫', '恋爱']);
    expect(novel.summary, contains('一夫多妻制'));
    expect(novel.extra['status'], '连载');
  });

  test('parseNovelDetailHeader prefers data-original cover and meta summary',
      () {
    const html = '''
<meta property="og:novel:author" content="A" />
<meta name="description" content="META简介" />
<div class="book-img"><img src="x.svg" data-original="https://x/real.jpg"></div>
<h1 class="book-name">书名</h1>''';
    final novel = parseNovelDetailHeader(html, '1');
    expect(novel.coverUrl, 'https://x/real.jpg');
    expect(novel.summary, 'META简介');
  });

  test('parseCatalog parses volumes and chapters', () {
    final volumes = parseCatalog(_catalogHtml, '5340');
    expect(volumes, hasLength(2));
    expect(volumes.first.title, '不相容的異種族妻子們 插圖');
    expect(volumes.first.chapters.map((c) => c.id), ['333607', '333608']);
    expect(volumes.first.chapters.first.title, '封面');
    expect(volumes.last.chapters.single.id, '334356');
    expect(volumes.last.url, 'https://www.linovelib.com/novel/5340/vol_333597.html');
  });
}
