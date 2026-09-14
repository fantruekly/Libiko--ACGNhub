# Task 13 Report: 人气榜改用带封面的 URL

## 实现内容

1. **`lib/core/novel/linovelib_source.dart`**
   - `rankPath` 改为统一模式：`static String rankPath(String key, int page) => '/top/$key/$page.html';`（去掉 `allvisit → /top.html` 特例）。
   - 删除 `isSinglePageRanking(NovelBrowse)` 方法。
   - `browse` 的 `hasMore` 不再特判单页排行，改为：
     ```dart
     final hasMore = hasPaginationControl(html)
         ? hasNextPage(html)
         : items.length >= 10;
     ```
2. **`test/core/novel/linovelib_source_test.dart`**
   - `rankPath` 断言更新：`allvisit,1 → /top/allvisit/1.html`；新增 `allvisit,2 → /top/allvisit/2.html`。
   - 删除 `isSinglePageRanking` 测试。
   - 顺带移除因此变为未使用的 `models.dart` import（否则 `flutter analyze` 会报 unused_import）。
3. **`docs/superpowers/specs/2026-09-14-novel-module-design.md`**
   - 第 87 行：把「人气榜（`allvisit`，`/top.html`）为**单页**，不显示分页」改为「人气榜（`allvisit`）同其他榜一样用 `/top/allvisit/<page>.html`（该页每行都有封面；旧的 `/top.html` 只有少数行带封面，已弃用）」。
   - 第 114-116 行：同步修正「排行」抓取说明——所有排行（含 `allvisit`）走 `/top/<key>/<page>.html` + `div.rank_d_list`；旧的 `/top.html` + `div.rank_i_li` 标注为已弃用。

## 测试与结果

- `flutter analyze lib test` → `No issues found! (ran in 3.6s)`
- `flutter test` → `+210 ~1: All tests passed!`（1 个 skip 为既有 flutter_qjs 原生库不可加载，与本任务无关）

## TDD Evidence

### RED
命令：
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_source_test.dart
```
输出（关键）：
```
00:00 +0 -1: rankPath builds the ranking url [E]
  Expected: '/top/allvisit/1.html'
    Actual: '/top.html'
     Which: is different.
            Expected: /top/allvisit/ ...
              Actual: /top.html
                          ^
             Differ at offset 4
  test\core\novel\linovelib_source_test.dart 8:5      main.<fn>
00:00 +4 -1: Some tests failed.
```
为什么预期失败：此时测试已更新为期望 `/top/allvisit/1.html`，但源码 `rankPath` 仍是 `key == 'allvisit' ? '/top.html' : ...`，对 `allvisit` 返回 `/top.html`，与期望不符，正是要修复的 bug。

### GREEN
命令：
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_source_test.dart
```
输出（关键）：
```
00:00 +0: rankPath builds the ranking url
00:00 +1: bunkoPath builds the bunko url
00:00 +2: source identity
00:00 +3: detail/catalog paths
00:00 +4: chapterPath builds the chapter url
00:00 +5: All tests passed!
```

## 文件变更

- `lib/core/novel/linovelib_source.dart`
- `test/core/novel/linovelib_source_test.dart`
- `docs/superpowers/specs/2026-09-14-novel-module-design.md`

提交：`9277f9b fix(novel): use cover-rich /top/allvisit/<page>.html for 人气榜`（已 push 到 `dev`）。

## 自审

- `grep isSinglePageRanking` 在 `lib/` 与 `test/` 下均无残留（仅历史 plan 文档 `docs/superpowers/plans/*.md` 保留旧叙述，属历史计划记录，不在本任务改动范围）。
- 确认提交只含 3 个目标文件；工作区其它已存在的未提交改动未被误纳入。
- spec 中旧 `/top.html` 结构说明保留（`parseRankRows` 仍兼容解析 `rank_i_li`），仅标注弃用，避免删除代码路径造成信息丢失。

## 顾虑

- `parseRankRows` 仍保留 `div.rank_i_li` 解析分支（已不再被任何 URL 使用）。本任务范围不含删除该分支，保留可作向后兼容；如需清理可另开任务。
- 网络层行为（真实站点 `/top/allvisit/<page>.html` 每行带封面）未在单测中覆盖，依赖控制器的实测结论；单测仅验证 URL 构造与 `hasMore` 逻辑。
