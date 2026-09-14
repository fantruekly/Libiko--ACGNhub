### Task 1: 章节解析函数

**Files:**
- Modify: `lib/core/novel/linovelib_source.dart`
- Test: `test/core/novel/linovelib_chapter_parser_test.dart`

**Interfaces:**
- Consumes: `models.dart` 的 `NovelChapter { String title; String content; }`（已存在）。
- Produces（`linovelib_source.dart` 顶层函数）：
  - `NovelChapter parseChapter(String html, String fallbackTitle)` — 标题 `#mlfy_main_text h1`（回退 `fallbackTitle`）；正文取 `div#TextContent` 的 `<p>`，按 `\n\n` 连接。
  - `String? nextPageHref(String html, String novelId, String chapterId)` — `div.mlfy_page` 里「下一页」`<a>` 的 href，仅当形如 `/novel/<novelId>/<chapterId>_<n>.html` 时返回，否则 `null`。
  - `Future<NovelChapter> fetchChapterPages({required String novelId, required String chapterId, required Future<String> Function(String path) fetch, int maxPages = 50})` — 抓首页 + 循环拼接同章分页。

- [ ] **Step 1: 写失败测试（含 fixture）**

`test/core/novel/linovelib_chapter_parser_test.dart`:

```dart
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
```

- [ ] **Step 2: 运行确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_chapter_parser_test.dart`
Expected: FAIL（`parseChapter` 未定义）

- [ ] **Step 3: 实现**

在 `linovelib_source.dart` 的 `parseCatalog` 之后追加：

```dart
NovelChapter parseChapter(String html, String fallbackTitle) {
  final doc = html_parser.parse(html);
  final title = _textOf(doc.querySelector('#mlfy_main_text h1'));
  final paragraphs = <String>[];
  final content = doc.querySelector('div#TextContent');
  if (content != null) {
    for (final p in content.querySelectorAll('p')) {
      final t = p.text.trim();
      if (t.isNotEmpty) paragraphs.add(t);
    }
  }
  return NovelChapter(
    title: title.isEmpty ? fallbackTitle : title,
    content: paragraphs.join('\n\n'),
  );
}

String? nextPageHref(String html, String novelId, String chapterId) {
  final doc = html_parser.parse(html);
  final prefix = '/novel/$novelId/${chapterId}_';
  for (final a in doc.querySelectorAll('div.mlfy_page a')) {
    if (a.text.trim() != '下一页') continue;
    final href = a.attributes['href'];
    if (href != null && href.startsWith(prefix) && href.endsWith('.html')) {
      return href;
    }
    return null;
  }
  return null;
}

Future<NovelChapter> fetchChapterPages({
  required String novelId,
  required String chapterId,
  required Future<String> Function(String path) fetch,
  int maxPages = 50,
}) async {
  final firstHtml = await fetch('/novel/$novelId/$chapterId.html');
  final first = parseChapter(firstHtml, '');
  final buffer = <String>[if (first.content.isNotEmpty) first.content];
  var next = nextPageHref(firstHtml, novelId, chapterId);
  var pages = 1;
  while (next != null && pages < maxPages) {
    final html = await fetch(next);
    final page = parseChapter(html, '');
    if (page.content.isNotEmpty) buffer.add(page.content);
    next = nextPageHref(html, novelId, chapterId);
    pages++;
  }
  return NovelChapter(title: first.title, content: buffer.join('\n\n'));
}
```

- [ ] **Step 4: 运行确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_chapter_parser_test.dart`
Expected: PASS（4 tests）

- [ ] **Step 5: 提交**

```bash
git add lib/core/novel/linovelib_source.dart test/core/novel/linovelib_chapter_parser_test.dart
git commit -m "feat(novel): add chapter parsers (paragraphs + same-chapter paging)"
git push
```

---
