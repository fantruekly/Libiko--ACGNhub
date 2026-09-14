### Task 12: 阅读器插图按视口高度显示（两侧留白）

> 用户反馈：看插图时希望像看漫画一样——插图竖向与页面竖向匹配，两边留白。

**Files:**
- Modify: `lib/modules/novel/novel_reader_page.dart`

- [ ] **Step 1: 插图块改为视口高度的 `BoxFit.contain`**

在 `_content` 的 `NovelImage` 分支，把 `ClipRRect > CachedNetworkImage(fit: BoxFit.contain)` 包在固定高度的 `SizedBox` 里：

```dart
                NovelImage(:final url) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: SizedBox(
                      height: _illustrationHeight(context),
                      width: double.infinity,
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.contain,
                        httpHeaders: novelImageHeaders,
                        placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator()),
                        errorWidget: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_outlined)),
                      ),
                    ),
                  ),
```

并加方法：

```dart
  /// The height of the content viewport (between the 56px top bar and the
  /// 64px bottom bar), so an illustration fills the page vertically with the
  /// sides left blank, like a comic page.
  double _illustrationHeight(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height - 56 - 64 - 24;
    return h.clamp(200, 4000).toDouble();
  }
```

- [ ] **Step 2: 全量校验 + 提交**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → 全部通过

```bash
git add lib/modules/novel/novel_reader_page.dart
git commit -m "fix(novel): size reader illustrations to the viewport height"
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