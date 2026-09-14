### Task 4: providers

**Files:**
- Modify: `lib/modules/novel/novel_providers.dart`
- Test: `test/modules/novel/novel_providers_test.dart`

**Interfaces:**
- Consumes: `novelSourceManagerProvider`；`NovelSource.chapter`；`NovelDetail`/`NovelChapterRef`。
- Produces:
  - `final novelChapterProvider = FutureProvider.family<NovelChapter, (String, String, String)>((ref, key) async { ... })`，key = `(sourceId, novelId, chapterId)`；source 不存在抛 `StateError`。
  - `List<NovelChapterRef> flattenChapters(NovelDetail detail)`。

- [ ] **Step 1: 写失败测试**

在 `test/modules/novel/novel_providers_test.dart` 追加：

```dart
  test('flattenChapters flattens volumes in order', () {
    const detail = NovelDetail(
      novel: Novel(id: '1', title: 'T'),
      volumes: [
        NovelVolume(title: 'v1', chapters: [
          NovelChapterRef(id: 'a', title: 'A'),
          NovelChapterRef(id: 'b', title: 'B'),
        ]),
        NovelVolume(title: 'v2', chapters: [
          NovelChapterRef(id: 'c', title: 'C'),
        ]),
      ],
    );
    expect(flattenChapters(detail).map((c) => c.id), ['a', 'b', 'c']);
  });
```

- [ ] **Step 2: 运行确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_providers_test.dart`
Expected: FAIL（`flattenChapters` 未定义）

- [ ] **Step 3: 实现**

在 `novel_providers.dart` 末尾追加：

```dart
/// 按分卷顺序扁平化章节（供阅读器上一/下一章与目录使用）。
List<NovelChapterRef> flattenChapters(NovelDetail detail) =>
    [for (final volume in detail.volumes) ...volume.chapters];

final novelChapterProvider =
    FutureProvider.family<NovelChapter, (String, String, String)>(
        (ref, key) async {
  final (sourceId, novelId, chapterId) = key;
  final source = ref.watch(novelSourceManagerProvider).byId(sourceId);
  if (source == null) throw StateError('novel source $sourceId not found');
  return source.chapter(novelId, chapterId);
});
```

- [ ] **Step 4: 运行确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_providers_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/modules/novel/novel_providers.dart test/modules/novel/novel_providers_test.dart
git commit -m "feat(novel): add novelChapterProvider and flattenChapters"
git push
```

---
