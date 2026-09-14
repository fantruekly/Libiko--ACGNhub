### Task 1: linovelib 搜索

**Files:**
- Modify: `lib/core/novel/linovelib_source.dart`
- Test: `test/core/novel/linovelib_search_parser_test.dart`

**Interfaces:**
- Consumes: 文件内已有的 `_absUrl`、`_textOf`、`novelIdFromHref`、`_dio`、`linovelibBaseUrl`。
- Produces: `List<Novel> parseSearchResults(String html)`；`LinovelibSource.search(String keyword, {int page = 1})`。

- [ ] **Step 1: 写解析器的失败测试**

创建 `test/core/novel/linovelib_search_parser_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/novel/linovelib_source.dart';

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
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_search_parser_test.dart`
Expected: 编译失败（`parseSearchResults` 未定义）。

- [ ] **Step 3: 实现解析器**

编辑 `lib/core/novel/linovelib_source.dart`，在 `parseMobileBookList` 之后新增：

```dart
List<Novel> parseSearchResults(String html) {
  final doc = html_parser.parse(html);
  final out = <Novel>[];
  for (final row in doc.querySelectorAll('div.search-result-list')) {
    final titleA = row.querySelector('h2.tit a');
    final id = novelIdFromHref(titleA?.attributes['href']);
    if (titleA == null || id == null) continue;
    final img = row.querySelector('div.imgbox img');
    final cover =
        _absUrl(img?.attributes['data-original'] ?? img?.attributes['src']);
    final author = _textOf(row.querySelector('div.bookinfo a'));
    final summary = _textOf(row.querySelector('p'));
    out.add(Novel(
      id: id,
      title: _textOf(titleA),
      author: author.isEmpty ? null : author,
      coverUrl: cover.isEmpty ? null : cover,
      summary: summary.isEmpty ? null : summary,
      extra: {'url': '$linovelibBaseUrl/novel/$id.html'},
    ));
  }
  return out;
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_search_parser_test.dart`
Expected: 全部通过。

- [ ] **Step 5: 实现 `search`**

编辑 `lib/core/novel/linovelib_source.dart`，把：

```dart
  @override
  Future<List<Novel>> search(String keyword, {int page = 1}) =>
      throw UnimplementedError();
```

替换为：

```dart
  @override
  Future<List<Novel>> search(String keyword, {int page = 1}) async {
    final k = keyword.trim();
    if (k.isEmpty) return const [];
    final res = await _dio.post<String>(
      '/S6/',
      data: {'searchkey': k},
      options: Options(
        responseType: ResponseType.plain,
        contentType: Headers.formUrlEncodedContentType,
      ),
    );
    final html = res.data;
    if (res.statusCode != 200 || html == null) {
      throw Exception('linovelib 搜索失败：$k (${res.statusCode})');
    }
    return parseSearchResults(html);
  }
```

- [ ] **Step 6: 运行静态检查与全量测试**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: 全绿。

- [ ] **Step 7: 提交**

```bash
git add lib/core/novel/linovelib_source.dart test/core/novel/linovelib_search_parser_test.dart
git commit -m "feat(novel): linovelib search"
git push origin dev
```

---
