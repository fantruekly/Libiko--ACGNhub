### Task 6: 最终审查修复（设置状态 / 导航测试 / chapterPath / 小项）

> 来自最终整支审查。

**Files:**
- Modify: `lib/core/novel/novel_reader_settings.dart`
- Modify: `lib/core/novel/linovelib_source.dart`
- Modify: `lib/modules/novel/novel_reader_page.dart`
- Modify: `test/modules/novel/novel_reader_page_test.dart`

- [ ] **Step 1: 设置：先同步更新 state，再持久化（修 lost-update）**

`novel_reader_settings.dart` 的 `_update` 改为：

```dart
  Future<void> _update(NovelReaderSettings next) async {
    state = next;
    await _manager.write(next);
  }
```

- [ ] **Step 2: `fetchChapterPages` 复用 `chapterPath`**

在 `linovelib_source.dart` 的 `fetchChapterPages` 里，把

```dart
  final firstHtml = await fetch('/novel/$novelId/$chapterId.html');
```

改为：

```dart
  final firstHtml = await fetch(LinovelibSource.chapterPath(novelId, chapterId));
```

（`LinovelibSource.chapterPath` 已在 Task 2 定义；顶层函数可前向引用该类。）

- [ ] **Step 3: 阅读器：`_topBar` 去掉未用参数；目录按分卷分组；弹层用阅读配色**

在 `novel_reader_page.dart`：
- `_topBar` 改为 `Widget _topBar(_Palette palette)`，调用处 `_topBar(palette)`。
- `_openCatalog` 改为接收 `NovelDetail` 并按分卷分组；调用处 `_openCatalog(detail)`（`build` 里用 `ref.watch(novelDetailProvider(...)).valueOrNull`，为空则用 `flattenChapters` 的扁平列表降级）：

```dart
  void _openCatalog(NovelDetail? detail) {
    final palette = _Palette.of(ref.read(novelReaderSettingsProvider).theme);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: palette.bg,
      builder: (_) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                surface: palette.bg,
                onSurface: palette.fg,
              ),
        ),
        child: ListView(
          children: [
            if (detail == null || detail.volumes.isEmpty)
              const ListTile(title: Text('暂无目录'))
            else
              for (final v in detail.volumes) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(v.title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: palette.fg.withValues(alpha: 0.7))),
                ),
                for (final c in v.chapters)
                  ListTile(
                    dense: true,
                    title: Text(c.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: c.id == _chapterId
                        ? const Icon(Icons.check_rounded,
                            size: 18, color: _accent)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      if (c.id != _chapterId) _goChapter(c.id);
                    },
                  ),
              ],
          ],
        ),
      ),
    );
  }
```

- `_openSettings` 同样传入 `backgroundColor: palette.bg` 并用上面的 `Theme` 包裹 `_ReaderSettingsSheet`。
- 调用处：`_openCatalog(ref.watch(novelDetailProvider((widget.sourceKey, widget.novelId))).valueOrNull)`。

- [ ] **Step 4: 补「下一章」导航测试**

在 `test/modules/novel/novel_reader_page_test.dart` 追加（该文件已有 `setUp` 的 `AppDatabase.init()`）：

```dart
  testWidgets('tapping 下一章 loads the next chapter', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        novelChapterProvider(('linovelib', '1', 'c1')).overrideWith((ref) async =>
            const NovelChapter(title: '第一章', content: '甲段')),
        novelChapterProvider(('linovelib', '1', 'c2')).overrideWith((ref) async =>
            const NovelChapter(title: '第二章', content: '乙段')),
        novelDetailProvider(('linovelib', '1')).overrideWith((ref) async =>
            const NovelDetail(novel: Novel(id: '1', title: '书'), volumes: [
              NovelVolume(title: '正文', chapters: [
                NovelChapterRef(id: 'c1', title: '第一章'),
                NovelChapterRef(id: 'c2', title: '第二章'),
              ]),
            ])),
      ],
      child: const MaterialApp(
        home: NovelReaderPage(
            sourceKey: 'linovelib',
            novelId: '1',
            chapterId: 'c1',
            title: '书'),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('甲段'), findsOneWidget);
    await tester.tap(find.text('下一章'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('乙段'), findsOneWidget);
  });
```

- [ ] **Step 5: 全量校验**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: 全部通过

- [ ] **Step 6: 提交**

```bash
git add lib/core/novel/novel_reader_settings.dart lib/core/novel/linovelib_source.dart lib/modules/novel/novel_reader_page.dart test/modules/novel/novel_reader_page_test.dart
git commit -m "fix(novel): sync settings state, wire chapterPath, grouped catalog, next-chapter test"
git push
```

---

## Self-Review

**Spec coverage:**
- `parseChapter`/`nextPageHref`/`fetchChapterPages` → Task 1。
- `LinovelibSource.chapter`（同章分页拼接、50 页上限）→ Task 1/2。
- 阅读设置（模型/manager/provider、默认值与 clamp、三主题）→ Task 3。
- `novelChapterProvider`/`flattenChapters` → Task 4。
- `NovelReaderPage`（正文、顶/底栏、目录、设置、三态、切章回顶）+ 详情页接线 → Task 5。
- 测试（解析 fixture、设置模型、阅读器 widget）→ Task 1/3/5。

**Placeholder scan:** 无 TBD/TODO；每个代码步骤含完整代码。

**Type consistency:** `NovelChapter`（已有）在 Task 1/2/4/5 一致；`parseChapter`/`nextPageHref`/`fetchChapterPages`（Task 1）在 Task 2 使用；`NovelReaderSettings`/`NovelReaderTheme`/`novelReaderSettingsProvider`（Task 3）在 Task 5 使用；`novelChapterProvider`/`flattenChapters`（Task 4）在 Task 5 使用；`NovelChapterRef` 来自 `models.dart`。