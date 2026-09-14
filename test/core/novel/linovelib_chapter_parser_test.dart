import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/novel/linovelib_source.dart';

const _pagedHtml = '''
<div id="mlfy_main_text"><h1>第60話 規則（2）</h1>
<div id="TextContent" class="TextContent"><p>第一段。</p><br><p>第二段。</p><br><p>第三段。</p></div></div>
<div class="mlfy_page"><a href="/novel/5340/334299.html">上一页</a><a href="/novel/5340/catalog">目录</a><a href="/novel/5340/334356_2.html">下一页</a></div>
''';

const _lastPageHtml = '''
<div id="mlfy_main_text"><h1>第60話 規則（2）</h1>
<div id="TextContent"><p>末段。</p></div></div>
<div class="mlfy_page"><a href="/novel/5340/334356_1.html">上一页</a><a href="/novel/5340/334357.html">下一页</a></div>
''';

void main() {
  test('parseChapter reads title and paragraphs', () {
    final ch = parseChapter(_pagedHtml, 'FB');
    expect(ch.title, '第60話 規則（2）');
    expect(ch.content, '第一段。\n\n第二段。\n\n第三段。');
  });

  test('parseChapter falls back to the given title', () {
    final ch = parseChapter('<div id="TextContent"><p>只有正文</p></div>', '备用标题');
    expect(ch.title, '备用标题');
    expect(ch.content, '只有正文');
  });

  test('nextPageHref returns same-chapter page links only', () {
    expect(nextPageHref(_pagedHtml, '5340', '334356'), '/novel/5340/334356_2.html');
    expect(nextPageHref(_lastPageHtml, '5340', '334356'), isNull); // next chapter
    expect(nextPageHref('<div class="mlfy_page"></div>', '5340', '334356'), isNull);
  });

  test('fetchChapterPages concatenates same-chapter pages', () async {
    final pages = {
      '/novel/5340/334356.html': _pagedHtml,
      '/novel/5340/334356_2.html': _lastPageHtml,
    };
    var calls = 0;
    final ch = await fetchChapterPages(
      novelId: '5340',
      chapterId: '334356',
      fetch: (path) async {
        calls++;
        return pages[path]!;
      },
    );
    expect(calls, 2);
    expect(ch.content, '第一段。\n\n第二段。\n\n第三段。\n\n末段。');
  });
}
