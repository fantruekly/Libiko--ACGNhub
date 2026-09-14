### Task 2: `LinovelibSource.chapter`

**Files:**
- Modify: `lib/core/novel/linovelib_source.dart`
- Test: `test/core/novel/linovelib_source_test.dart`

**Interfaces:**
- Consumes: Task 1 的 `fetchChapterPages`。
- Produces: `Future<NovelChapter> LinovelibSource.chapter(String novelId, String chapterId)`（替换现有 `UnimplementedError`），内部调用 `fetchChapterPages(fetch: _get)`。

- [ ] **Step 1: 写失败测试（路径助手）**

在 `test/core/novel/linovelib_source_test.dart` 追加：

```dart
  test('chapterPath builds the chapter url', () {
    expect(LinovelibSource.chapterPath('5340', '334356'), '/novel/5340/334356.html');
  });
```

- [ ] **Step 2: 运行确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_source_test.dart`
Expected: FAIL（`chapterPath` 未定义）

- [ ] **Step 3: 实现**

在 `LinovelibSource` 里，把 `chapter` 的 `throw UnimplementedError()` 替换为：

```dart
  static String chapterPath(String novelId, String chapterId) =>
      '/novel/$novelId/$chapterId.html';

  @override
  Future<NovelChapter> chapter(String novelId, String chapterId) =>
      fetchChapterPages(novelId: novelId, chapterId: chapterId, fetch: _get);
```

（`_get` 接收一个 path 字符串，签名与 `fetch` 参数一致。）

- [ ] **Step 4: 运行确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_source_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/core/novel/linovelib_source.dart test/core/novel/linovelib_source_test.dart
git commit -m "feat(novel): implement LinovelibSource.chapter"
git push
```

---
