### Task 8: 复审修复（人气榜单页 + 小项）

> 来自 Task 7 的复审。`人气榜`（`allvisit` → `/top.html`）是**单页**，但 `rankPath` 忽略 `page`、`hasMore` 又因 `items>=10` 回退恒为 true，导致默认排行 tab 的「下一页」无限循环重复。

**Files:**
- Modify: `lib/core/novel/linovelib_source.dart`
- Modify: `test/core/novel/linovelib_parser_test.dart`
- Modify: `docs/superpowers/specs/2026-09-14-novel-module-design.md`

**Interfaces:**
- Produces: `static bool LinovelibSource.isSinglePageRanking(NovelBrowse browse)` → `browse.kind == NovelBrowseKind.ranking && browse.key == 'allvisit'`。

- [ ] **Step 1: 写失败测试**

在 `test/core/novel/linovelib_source_test.dart` 追加：

```dart
  test('allvisit is a single-page ranking', () {
    expect(
        LinovelibSource.isSinglePageRanking(
            const NovelBrowse(NovelBrowseKind.ranking, 'allvisit')),
        isTrue);
    expect(
        LinovelibSource.isSinglePageRanking(
            const NovelBrowse(NovelBrowseKind.ranking, 'monthvote')),
        isFalse);
    expect(
        LinovelibSource.isSinglePageRanking(
            const NovelBrowse(NovelBrowseKind.bunko, 'dengekibunko')),
        isFalse);
  });
```

（该测试文件若没有 `import 'package:acgnhub/core/novel/models.dart';` 需补上。）

- [ ] **Step 2: 运行确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_source_test.dart`
Expected: FAIL（`isSinglePageRanking` 未定义）

- [ ] **Step 3: 实现 + 应用到 `browse`**

在 `LinovelibSource` 里加：

```dart
  static bool isSinglePageRanking(NovelBrowse browse) =>
      browse.kind == NovelBrowseKind.ranking && browse.key == 'allvisit';
```

`browse` 的 `hasMore` 改为：

```dart
    final hasMore = isSinglePageRanking(browse)
        ? false
        : (hasPaginationControl(html)
            ? hasNextPage(html)
            : items.length >= 10);
    return NovelList(items: items, page: page, hasMore: hasMore);
```

- [ ] **Step 4: 运行确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_source_test.dart`
Expected: PASS（原 3 + 新 1）

- [ ] **Step 5: 补 `parseRankRows` 标签断言**

在 `test/core/novel/linovelib_parser_test.dart` 的 `parseRankRows parses rank rows` 测试里，`expect(items.first.extra['rank'], 1);` 之后加：

```dart
    expect(items.first.tags, ['novelpia']);
```

- [ ] **Step 6: 修正 spec 文案**

在 `docs/superpowers/specs/2026-09-14-novel-module-design.md`：
- 把 `novelSourcesProvider                    // FutureProvider<List<NovelSource>>` 改为 `// Provider<List<NovelSource>>`。
- 在「排行」子 chip 说明后补一句：`人气榜`（`allvisit`，`/top.html`）为**单页**，不显示分页。

- [ ] **Step 7: 全量校验**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: 全部通过

- [ ] **Step 8: 提交**

```bash
git add lib/core/novel/linovelib_source.dart test/core/novel/linovelib_source_test.dart test/core/novel/linovelib_parser_test.dart docs/superpowers/specs/2026-09-14-novel-module-design.md
git commit -m "fix(novel): treat 人气榜 as a single page; test rank tags; sync spec"
git push
```