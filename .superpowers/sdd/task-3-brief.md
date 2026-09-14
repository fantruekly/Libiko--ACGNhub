### Task 3: lknovel 详情目录与章节正文

给 `LknovelSource` 实现 `detail`（书信息 + 各卷章节，限并发拉取）与 `chapter`（正文 HTML → 文字/插图块）。

**Files:**
- Modify: `lib/core/novel/lknovel_source.dart`
- Test: `test/core/novel/lknovel_source_test.dart`

**Interfaces:**
- Consumes: `parseLkVolumes`、`parseLkVolumeChapters`、`parseLkChapter`、`lkData`、`lkHasMore`、`LknovelSource._post`（Task 2）；`NovelVolume.id`（Task 1）。
- Produces:
  - `LknovelSource.detail(String id)` → `Future<NovelDetail>`（书信息 + 全部卷章节）
  - `LknovelSource.chapter(String novelId, String chapterId)` → `Future<NovelChapter>`

- [ ] **Step 1: 写 `detail`/`chapter` 的失败测试**

在 `test/core/novel/lknovel_source_test.dart` 的 `main()` 末尾（最后一个 `test` 之后）追加：

```dart
  test('detail loads every volume and its chapters', () async {
    final source = LknovelSource(poster: (endpoint, body) async {
      switch (endpoint) {
        case 'new-content-read/get-book-detail':
          return {'code': 0, 'data': _detailData};
        case 'new-content-read/get-volume-chapters':
          final vid = body['volume_id'].toString();
          return {
            'code': 0,
            'data': {
              'volume_id': vid,
              'list': vid == '36754'
                  ? [
                      {'chapter_id': 276838, 'title': '一败目'},
                      {'chapter_id': 276839, 'title': '间章'},
                    ]
                  : [
                      {'chapter_id': 276788, 'title': '特典'},
                    ],
            },
          };
      }
      throw Exception('unexpected endpoint: $endpoint');
    });
    final detail = await source.detail('1338');
    expect(detail.novel.title, '败犬女主太多了！');
    expect(detail.volumes.map((v) => v.title), ['1卷', '1卷特典']);
    expect(detail.volumes.first.chapters.map((c) => c.id), ['276838', '276839']);
    expect(detail.volumes.last.chapters.single.title, '特典');
  });

  test('chapter fetches and parses chapter detail', () async {
    final source = LknovelSource(poster: (endpoint, body) async {
      expect(endpoint, 'new-content-read/get-chapter-detail');
      expect(body['book_id'], '1338');
      expect(body['chapter_id'], '276838');
      return {'code': 0, 'data': _chapterData};
    });
    final chapter = await source.chapter('1338', '276838');
    expect(chapter.title, '一败目 专业青梅竹马');
    expect(chapter.blocks.whereType<NovelText>().length, 2);
    expect(chapter.blocks.whereType<NovelImage>().single.url,
        'https://api.lightnovel.fun/a.jpg');
  });
```

- [ ] **Step 2: 运行测试确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/lknovel_source_test.dart`
Expected: `detail`/`chapter` 抛 `UnimplementedError` → 用例失败。

- [ ] **Step 3: 实现 `detail` 与 `chapter`**

编辑 `lib/core/novel/lknovel_source.dart`，把末尾两个占位方法：

```dart
  @override
  Future<NovelDetail> detail(String id) => throw UnimplementedError();

  @override
  Future<NovelChapter> chapter(String novelId, String chapterId) =>
      throw UnimplementedError();
```

替换为：

```dart
  @override
  Future<NovelDetail> detail(String id) async {
    final json = await _post(
        'new-content-read/get-book-detail', {'book_id': id, 'with_volumes': 1});
    final data = lkData(json);
    final novel = parseLkBook(data);
    final metas = parseLkVolumes(data);
    const batchSize = 6;
    final volumes = <NovelVolume>[];
    for (var i = 0; i < metas.length; i += batchSize) {
      final end = (i + batchSize).clamp(0, metas.length);
      final batch = metas.sublist(i, end);
      final loaded = await Future.wait(batch.map((v) async {
        try {
          final chapters = await _volumeChapters(id, v.id ?? '');
          return NovelVolume(id: v.id, title: v.title, chapters: chapters);
        } catch (_) {
          return NovelVolume(id: v.id, title: v.title, chapters: const []);
        }
      }));
      volumes.addAll(loaded);
    }
    return NovelDetail(novel: novel, volumes: volumes);
  }

  Future<List<NovelChapterRef>> _volumeChapters(
      String bookId, String volumeId) async {
    final out = <NovelChapterRef>[];
    var page = 1;
    while (true) {
      final json = await _post('new-content-read/get-volume-chapters', {
        'book_id': bookId,
        'volume_id': volumeId,
        'page': page,
        'page_size': 50,
        'pageSize': 50,
      });
      final data = lkData(json);
      out.addAll(parseLkVolumeChapters(data));
      if (!lkHasMore(data, page) || page >= 100) break;
      page++;
    }
    return out;
  }

  @override
  Future<NovelChapter> chapter(String novelId, String chapterId) async {
    final json = await _post('new-content-read/get-chapter-detail',
        {'book_id': novelId, 'chapter_id': chapterId});
    return parseLkChapter(lkData(json), '');
  }
```

- [ ] **Step 4: 运行静态检查与测试**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: 全部通过（含新增 `detail`/`chapter` 用例）。

- [ ] **Step 5: 提交**

```bash
git add lib/core/novel/lknovel_source.dart test/core/novel/lknovel_source_test.dart
git commit -m "feat(novel): lknovel detail catalog and chapter reader"
git push origin dev
```

---

## 验证（任务全部完成后）

1. `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` 全绿。
2. 构建并启动应用，切到轻小说模块：
   - 源 chips 出现「哔哩轻小说」「轻之国度」。
   - 选「轻之国度」→「推荐」显示 4 个书单区块（轻小说/原创/同人/最近更新）。
   - 切「排行」→ 综合热度/日热度/日新书/周新书；切「分类」→ 轻小说/原创/同人/最近更新/新书；分页可翻页。
   - 点开一本书 → 详情显示封面/简介/分卷目录；点章节进入阅读器，正文与插图正常，上一/下一章与目录可用。
   - 切回「哔哩轻小说」→ 排行/文库与之前一致（回归）。

## 已知取舍

- lknovel 目录为懒加载接口，`detail` 需按卷并发请求（限并发 6），大型系列书首次进入详情会略慢；单卷失败仅该卷留空。
- 搜索未实现（界面无搜索框）。