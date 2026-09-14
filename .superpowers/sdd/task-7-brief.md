### Task 7: 最终审查修复（手动换页 + hasMore + 请求头 + 小项）

> 来自最终整支审查。用户决定：**去掉自动触底加载，改为底部手动「上一页/下一页」换页**；其余 Important/Minor 一并修。

**Files:**
- Modify: `lib/core/novel/linovelib_source.dart`
- Modify: `lib/modules/novel/novel_home.dart`
- Modify: `lib/modules/novel/novel_providers.dart`
- Test: `test/core/novel/linovelib_parser_test.dart`、`test/modules/novel/novel_card_test.dart`

**Interfaces:**
- Produces: `bool hasPaginationControl(String html)`（`div.pagination` 是否存在）；`hasNextPage(String html)` 改为只在 `div.pagination` 内找「下一页」。
- `novelSourcesProvider` 由 `FutureProvider<List<NovelSource>>` 改为 `Provider<List<NovelSource>>`（同步，无 loading 帧）。

- [ ] **Step 1: 写失败测试（hasPaginationControl / hasNextPage）**

在 `test/core/novel/linovelib_parser_test.dart` 末尾追加：

```dart
const _pagerNextHtml =
    '<div class="pagination"><a href="/top/monthvote/2.html">下一页</a></div>';
const _pagerNoNextHtml =
    '<div class="pagination"><a href="/top/monthvote/1.html">上一页</a></div>';
const _pagerLastHtml =
    '<div class="pagination"><span>下一页</span></div>';

void _paginationTests() {
  test('hasPaginationControl detects the container', () {
    expect(hasPaginationControl(_pagerNextHtml), isTrue);
    expect(hasPaginationControl(_bookListHtml), isFalse);
  });

  test('hasNextPage only trusts a next link inside div.pagination', () {
    expect(hasNextPage(_pagerNextHtml), isTrue);
    expect(hasNextPage(_pagerNoNextHtml), isFalse);
    expect(hasNextPage(_pagerLastHtml), isFalse); // <span>, not a link
    expect(hasNextPage(_bookListHtml), isFalse); // no pagination control
  });
}
```

并在 `main()` 末尾（最后一个 `});` 之后、`}` 之前）调用 `_paginationTests();`。

- [ ] **Step 2: 运行确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_parser_test.dart`
Expected: FAIL（`hasPaginationControl` 未定义）

- [ ] **Step 3: 改 `linovelib_source.dart`**

把 `hasNextPage` 替换为：

```dart
bool hasPaginationControl(String html) =>
    html_parser.parse(html).querySelector('div.pagination') != null;

bool hasNextPage(String html) {
  final container = html_parser.parse(html).querySelector('div.pagination');
  if (container == null) return false;
  for (final a in container.querySelectorAll('a')) {
    final t = a.text.trim();
    if (t.contains('下一页') || t.contains('下页')) return true;
  }
  return false;
}
```

`LinovelibSource` 的 headers 补 `Accept`/`Accept-Language`：

```dart
              headers: {
                'User-Agent': linovelibUserAgent,
                'Accept':
                    'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
                'Referer': '$linovelibBaseUrl/',
              },
```

`browse` 的返回改为按 spec 判定 `hasMore`：

```dart
    final items = browse.kind == NovelBrowseKind.ranking
        ? parseRankRows(html)
        : parseBookList(html);
    final hasMore = hasPaginationControl(html)
        ? hasNextPage(html)
        : items.length >= 10;
    return NovelList(items: items, page: page, hasMore: hasMore);
```

`parseRankRows` 补文库标签（与 `_novelFromBookLi` 一致）：

```dart
    final cate = _textOf(row.querySelector('a.rank_i_l_a_category'));
    final tags = <String>[];
    if (cate.isNotEmpty) {
      tags.add(cate.replaceAll('[', '').replaceAll(']', ''));
    }
    out.add(Novel(
      id: id,
      title: _textOf(bookA),
      author: author.isEmpty ? null : author,
      coverUrl: cover.isEmpty ? null : cover,
      tags: tags,
      extra: {
        'url': '$linovelibBaseUrl/novel/$id.html',
        if (rank != null) 'rank': rank,
      },
    ));
```

- [ ] **Step 4: 运行确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_parser_test.dart`
Expected: PASS（原 5 + 新 2）

- [ ] **Step 5: `novel_providers.dart` 把 `novelSourcesProvider` 改同步**

```dart
final novelSourcesProvider =
    Provider<List<NovelSource>>((ref) => ref.watch(novelSourceManagerProvider).sources);
```

- [ ] **Step 6: `novel_home.dart` 去掉自动触底，改手动换页**

- `build()` 里 `final sources = ref.watch(novelSourcesProvider);`（不再是 AsyncValue），`_sourceChips(sources)` 接收 `List<NovelSource>`。
- 删除 `_grid` 的 `onLoadMore` 参数与 `NotificationListener`。
- `_body()` 的 loading 分支改为与网格参数一致：
  `const ShimmerLoader(crossAxisCount: 6, itemCount: 12, aspectRatio: 0.58, padding: EdgeInsets.fromLTRB(16, 8, 16, 24))`
- `_body()` 的排行/文库 `data` 分支：

```dart
      data: (list) => Column(
        children: [
          Expanded(child: _grid(list.items)),
          _pager(list.hasMore),
        ],
      ),
```

- 新增 `_pager`：

```dart
  Widget _pager(bool hasMore) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton(
            onPressed: _page > 1 ? () => setState(() => _page--) : null,
            child: const Text('上一页'),
          ),
          const SizedBox(width: 16),
          Text('第 $_page 页',
              style: const TextStyle(fontSize: 13, color: _muted)),
          const SizedBox(width: 16),
          OutlinedButton(
            onPressed: hasMore ? () => setState(() => _page++) : null,
            child: const Text('下一页'),
          ),
        ],
      ),
    );
  }
```

- `_grid` 签名改为 `Widget _grid(List<Novel> items)`，去掉滚动监听：

```dart
  Widget _grid(List<Novel> items) {
    if (items.isEmpty) {
      return const EmptyState(icon: Icons.menu_book_rounded, message: '暂无内容');
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          mainAxisSpacing: 20,
          crossAxisSpacing: 16,
          childAspectRatio: 0.58),
      itemCount: items.length,
      itemBuilder: (_, i) => NovelCard(novel: items[i]),
    );
  }
```

- [ ] **Step 7: 补 `NovelCard` 占位测试**

在 `test/modules/novel/novel_card_test.dart` 追加：

```dart
  testWidgets('NovelCard shows a placeholder when there is no cover',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 120,
          height: 200,
          child: NovelCard(novel: Novel(id: '1', title: '安达与岛村')),
        ),
      ),
    ));
    expect(find.text('安'), findsOneWidget);
  });
```

- [ ] **Step 8: 全量校验**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: 全部通过

- [ ] **Step 9: 提交**

```bash
git add lib/core/novel/linovelib_source.dart lib/modules/novel/novel_home.dart lib/modules/novel/novel_providers.dart test/core/novel/linovelib_parser_test.dart test/modules/novel/novel_card_test.dart
git commit -m "fix(novel): manual paging, spec-compliant hasMore, browser headers, polish"
git push
```