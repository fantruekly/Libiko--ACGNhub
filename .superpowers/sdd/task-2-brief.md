### Task 2: lknovel 搜索

**Files:**
- Modify: `lib/core/novel/lknovel_source.dart`
- Test: `test/core/novel/lknovel_source_test.dart`

**Interfaces:**
- Consumes: `LknovelSource._post`、`lkData`、`parseLkList`；`test/core/novel/lknovel_source_test.dart` 里已有的 `_feedData` fixture。
- Produces: `LknovelSource.search(String keyword, {int page = 1})`。

- [ ] **Step 1: 写失败测试**

在 `test/core/novel/lknovel_source_test.dart` 的 `main()` 末尾（最后一个 `test` 之后）追加：

```dart
  test('search posts to apk-search-result-v1', () async {
    Map<String, dynamic>? seen;
    final source = LknovelSource(poster: (endpoint, body) async {
      expect(endpoint, 'bff/apk-search-result-v1');
      seen = body;
      return {'code': 0, 'data': _feedData};
    });
    final list = await source.search('败犬', page: 2);
    expect(seen!['q'], '败犬');
    expect(seen!['page'], 2);
    expect(list.single.id, '1338');
  });
```

- [ ] **Step 2: 运行测试确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/lknovel_source_test.dart`
Expected: 失败（`search` 抛 `UnimplementedError`）。

- [ ] **Step 3: 实现 `search`**

编辑 `lib/core/novel/lknovel_source.dart`，把：

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
    final json = await _post('bff/apk-search-result-v1', {
      'q': k,
      'page': page,
      'page_size': 20,
      'pageSize': 20,
    });
    return parseLkList(lkData(json));
  }
```

- [ ] **Step 4: 运行测试确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/lknovel_source_test.dart`
Expected: 全部通过。

- [ ] **Step 5: 静态检查与全量测试**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: 全绿。

- [ ] **Step 6: 提交**

```bash
git add lib/core/novel/lknovel_source.dart test/core/novel/lknovel_source_test.dart
git commit -m "feat(novel): lknovel search"
git push origin dev
```

---
