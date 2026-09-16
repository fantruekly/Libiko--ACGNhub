### Task 13: 人气榜改用带封面的 URL

> 用户反馈：排行榜「人气榜」很多封面加载不出。根因（实测）：`/top.html` 用 `rank_i_li` 结构，122 行里**只有 6 行带封面**；而 `/top/allvisit/1.html`（同为人气榜）用 `rank_d_list` 结构，**30 行全部带封面**。`rankPath('allvisit')` 目前返回 `/top.html`。

**Files:**
- Modify: `lib/core/novel/linovelib_source.dart`
- Modify: `test/core/novel/linovelib_source_test.dart`
- Modify: `docs/superpowers/specs/2026-09-14-novel-module-design.md`

- [ ] **Step 1: 改测试**

`test/core/novel/linovelib_source_test.dart`：
- `rankPath('allvisit', 1)` 断言改为 `'/top/allvisit/1.html'`；`rankPath('allvisit', 2)` → `'/top/allvisit/2.html'`。
- 删除 `isSinglePageRanking` 的测试（该方法将移除）。

- [ ] **Step 2: 运行确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_source_test.dart`
Expected: FAIL（`allvisit` 仍返回 `/top.html`）

- [ ] **Step 3: 改 `linovelib_source.dart`**

把 `rankPath` 改为统一模式（去掉 `allvisit` 特例）：

```dart
  static String rankPath(String key, int page) => '/top/$key/$page.html';
```

删除 `isSinglePageRanking` 方法，并把 `browse` 的 `hasMore` 改为不再特判：

```dart
    final hasMore = hasPaginationControl(html)
        ? hasNextPage(html)
        : items.length >= 10;
    return NovelList(items: items, page: page, hasMore: hasMore);
```

- [ ] **Step 4: 运行确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_source_test.dart`
Expected: PASS

- [ ] **Step 5: 修 spec 文案**

`docs/superpowers/specs/2026-09-14-novel-module-design.md`：把「人气榜（`allvisit`，`/top.html`）为单页」改为「人气榜同其他榜一样用 `/top/allvisit/<page>.html`（该页每行都有封面；旧的 `/top.html` 只有少数行带封面，已弃用）」。

- [ ] **Step 6: 全量校验 + 提交**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → 全部通过

```bash
git add lib/core/novel/linovelib_source.dart test/core/novel/linovelib_source_test.dart docs/superpowers/specs/2026-09-14-novel-module-design.md
git commit -m "fix(novel): use cover-rich /top/allvisit/<page>.html for 人气榜"
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