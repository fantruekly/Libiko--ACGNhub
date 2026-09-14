# Task 8 Report: 复审修复（人气榜单页 + 小项）

## 状态

DONE

## 实现内容

### 1. `lib/core/novel/linovelib_source.dart`
- 新增 `static bool isSinglePageRanking(NovelBrowse browse)`：
  `browse.kind == NovelBrowseKind.ranking && browse.key == 'allvisit'`。
- `browse()` 的 `hasMore` 改为优先判定单页排行：
  ```dart
  final hasMore = isSinglePageRanking(browse)
      ? false
      : (hasPaginationControl(html)
          ? hasNextPage(html)
          : items.length >= 10);
  ```
  修复了 `人气榜`（`allvisit` → `/top.html`，单页）因 `rankPath` 忽略 `page` 且 `items.length >= 10` 回退恒为 true，导致默认排行 tab「下一页」无限循环重复的问题。

### 2. `test/core/novel/linovelib_source_test.dart`
- 补 `import 'package:acgnhub/core/novel/models.dart';`。
- 新增测试 `allvisit is a single-page ranking`（ranking+allvisit 为 true；ranking+monthvote、bunko+dengekibunko 为 false）。

### 3. `test/core/novel/linovelib_parser_test.dart`
- 在 `parseRankRows parses rank rows` 里补 `expect(items.first.tags, ['novelpia']);`，覆盖排行行的文库标签解析。

### 4. `docs/superpowers/specs/2026-09-14-novel-module-design.md`
- `novelSourcesProvider` 注释由 `FutureProvider<List<NovelSource>>` 改为 `Provider<List<NovelSource>>`。
- 在「排行」子 chip 说明后补：`其中 人气榜（allvisit，/top.html）为单页，不显示分页。`

## 测试结果

- `flutter analyze lib test`：`No issues found! (ran in 2.1s)`
- `flutter test`：`00:10 +189 ~1: All tests passed!`（189 passed，1 skipped）
  - `~1` 为既有 skip：`test/core/comic/js_engine_smoke_test.dart`（flutter_qjs 原生库在 `flutter test` 下不可加载），非本任务引入。
- 未发起任何真实网络请求（均为纯 Dart 解析/静态方法测试）。

## TDD Evidence

### RED
命令：
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_source_test.dart
```
输出（节选）：
```
test/core/novel/linovelib_source_test.dart:24:25: Error: Member not found: 'LinovelibSource.isSinglePageRanking'.
        LinovelibSource.isSinglePageRanking(
                        ^^^^^^^^^^^^^^^^^^^
test/core/novel/linovelib_source_test.dart:28:25: Error: Member not found: 'LinovelibSource.isSinglePageRanking'.
        LinovelibSource.isSinglePageRanking(
                        ^^^^^^^^^^^^^^^^^^^
test/core/novel/linovelib_source_test.dart:32:25: Error: Member not found: 'LinovelibSource.isSinglePageRanking'.
        LinovelibSource.isSinglePageRanking(
                        ^^^^^^^^^^^^^^^^^^^
00:00 +0 -1: loading D:/ACGNhub/test/core/novel/linovelib_source_test.dart [E]
  Failed to load "D:/ACGNhub/test/core/novel/linovelib_source_test.dart":
  Compilation failed for testPath=D:/ACGNhub/test/core/novel/linovelib_source_test.dart: ...
00:00 +0 -1: Some tests failed.
```
预期失败原因：测试先于实现编写，`isSinglePageRanking` 尚未定义，编译失败即 RED。

### GREEN
命令：
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_source_test.dart
```
输出（节选）：
```
00:00 +0: rankPath builds the ranking url
00:00 +1: bunkoPath builds the bunko url
00:00 +2: source identity
00:00 +3: allvisit is a single-page ranking
00:00 +4: All tests passed!
```
原 3 + 新 1 全部通过。

全量校验：
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test
No issues found! (ran in 2.1s)

$env:Path = "C:\flutter\bin;$env:Path"; flutter test
00:10 +189 ~1: All tests passed!
```

## 变更文件

- `lib/core/novel/linovelib_source.dart`
- `test/core/novel/linovelib_source_test.dart`
- `test/core/novel/linovelib_parser_test.dart`
- `docs/superpowers/specs/2026-09-14-novel-module-design.md`

## 提交

- `git add lib/core/novel/linovelib_source.dart test/core/novel/linovelib_source_test.dart test/core/novel/linovelib_parser_test.dart docs/superpowers/specs/2026-09-14-novel-module-design.md`
- `git commit -m "fix(novel): treat 人气榜 as a single page; test rank tags; sync spec"`
- `git push`
- Commit SHA：见下方回复。

## 自查发现

- `isSinglePageRanking` 用 `browse.key == 'allvisit'` 精确匹配，且同时要求 `kind == ranking`，因此 `bunko` 下同名 key 不会被误判（测试已覆盖）。
- `browse()` 仅在 `hasMore` 判定处使用该守卫，不影响请求路径与解析；`rankPath` 对 `allvisit` 依旧返回 `/top.html`，与单页语义一致。
- 未新增任何依赖；未添加任何代码注释。
- 测试文件新增的 `models.dart` import 是 `NovelBrowse`/`NovelBrowseKind` 所需（`linovelib_source.dart` 只 import 未 export）。
- 仅暂存了 brief 指定的 4 个文件；工作区其余既有未提交改动（`.superpowers/sdd/*`、plan 文档等）保持不动。

## 关注点

- 本次提交的 spec 文档同时包含了 Task 7 遗留的未提交文案改动（手动换页、Accept/Accept-Language 等），因为 Task 7 的提交未包含该文档。这符合 Task 8 brief「修改并提交该 spec 文件」的要求，但会让该 commit 的 spec diff 大于纯 Task 8 文案范围。
- `hasMore` 的 `items.length >= 10` 启发式仍适用于非 `allvisit` 排行与文库；若站点某末页恰好满 10 条且无分页控件，仍可能多提示一次可翻页。这是 spec 规定行为，未擅自改动。
