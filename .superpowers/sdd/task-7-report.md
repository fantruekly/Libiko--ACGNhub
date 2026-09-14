# Task 7 Report: 轻小说模块最终审查修复

## 概述

按最终整支审查结论修复 3 个 Important 问题及若干小项：去掉自动触底加载、改为底部手动「上一页 / 第 N 页 / 下一页」换页；`hasMore` 按 spec 判定；请求头补 `Accept`/`Accept-Language`；`novelSourcesProvider` 改同步；排行行补文库标签；补 `NovelCard` 占位测试。

## 实现内容

### 1. `lib/core/novel/linovelib_source.dart`
- 新增 `bool hasPaginationControl(String html)`：`div.pagination` 是否存在。
- 重写 `hasNextPage(String html)`：只在 `div.pagination` 容器内查找文本含「下一页 / 下页」的 `<a>`；`<span>` 不算。
- `LinovelibSource` 的 Dio 默认 headers 补 `Accept` 与 `Accept-Language`。
- `browse()` 的 `hasMore` 改为：有分页控件时按 `hasNextPage`，否则按 `items.length >= 10`。
- `parseRankRows` 补 `a.rank_i_l_a_category` 文库标签解析（去掉 `[` `]`），与 `_novelFromBookLi` 一致。

### 2. `lib/modules/novel/novel_providers.dart`
- `novelSourcesProvider` 由 `FutureProvider<List<NovelSource>>` 改为同步 `Provider<List<NovelSource>>`（无 loading 帧）。

### 3. `lib/modules/novel/novel_home.dart`
- `build()` 直接 `_sourceChips(sources)`（不再是 AsyncValue）。
- 删除 `_grid` 的 `onLoadMore` 参数与 `NotificationListener` 自动触底逻辑。
- 加载分支统一为 `ShimmerLoader(crossAxisCount: 6, itemCount: 12, aspectRatio: 0.58, padding: EdgeInsets.fromLTRB(16, 8, 16, 24))`。
- 排行/文库 data 分支改为 `Column(Expanded(_grid), _pager(hasMore))`。
- 新增 `_pager`：上一页（`_page > 1` 才可点）/「第 N 页」/ 下一页（`hasMore` 才可点）。
- `_grid` 签名简化为 `Widget _grid(List<Novel> items)`。

### 4. 测试
- `test/core/novel/linovelib_parser_test.dart`：新增 `_paginationTests()`（`hasPaginationControl` + 新的 `hasNextPage` 语义）。
- `test/modules/novel/novel_card_test.dart`：新增无封面占位测试（期望显示标题首字「安」）。

## 测试结果

- `flutter analyze lib test`：`No issues found!`
- `flutter test`：`All tests passed!`（188 passed，1 skipped —— 该 skip 为既有的 `js_engine_smoke_test`，非本任务引入）。

## TDD Evidence

### RED
命令：
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_parser_test.dart
```
输出（节选）：
```
test/core/novel/linovelib_parser_test.dart:88:12: Error: Method not found: 'hasPaginationControl'.
    expect(hasPaginationControl(_pagerNextHtml), isTrue);
           ^^^^^^^^^^^^^^^^^^^^
test/core/novel/linovelib_parser_test.dart:89:12: Error: Method not found: 'hasPaginationControl'.
    expect(hasPaginationControl(_bookListHtml), isFalse);
           ^^^^^^^^^^^^^^^^^^^^
00:00 +0 -1: loading ... [E]
  Failed to load ".../linovelib_parser_test.dart":
  Compilation failed ...: Method not found: 'hasPaginationControl'.
00:00 +0 -1: Some tests failed.
```
预期失败原因：测试先于实现编写，`hasPaginationControl` 尚不存在，编译失败即 RED。

### GREEN
命令：
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_parser_test.dart
```
输出（节选）：
```
00:00 +0: novelIdFromHref extracts id
00:00 +1: parseBookList keeps only book entries with a.title
00:00 +2: parseHome returns titled sections
00:00 +3: parseRankRows parses rank rows
00:00 +4: hasNextPage detects the next link
00:00 +5: hasPaginationControl detects the container
00:00 +6: hasNextPage only trusts a next link inside div.pagination
00:00 +7: All tests passed!
```
原 5 + 新 2 全部通过。

全量：
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test
No issues found! (ran in 2.1s)

$env:Path = "C:\flutter\bin;$env:Path"; flutter test
00:10 +188 ~1: All tests passed!
```

## 变更文件

- `lib/core/novel/linovelib_source.dart`
- `lib/modules/novel/novel_home.dart`
- `lib/modules/novel/novel_providers.dart`
- `test/core/novel/linovelib_parser_test.dart`
- `test/modules/novel/novel_card_test.dart`

## 自查发现

- 未新增任何依赖；未在任何 `TextStyle` 设置 `fontFamily`（`_pager` 仅 fontSize/color）。
- 颜色沿用 accent `0xFF007AFF`、fg `0xFF1C1C1E`、muted `0xFF5A5A5F`。
- `novelSourcesProvider` 改为同步后，唯一使用点 `novel_home.dart` 已同步更新，analyze 无残留错误。
- 分页 `hasMore` 无分页控件时按 `items.length >= 10` 判定，属 brief/spec 规定行为：若某页恰好 ≥10 条但实为末页，会多一次空页翻页。保留 spec 行为，未擅自改动。
- 测试均不发起真实网络请求（解析测试用内联 HTML，Widget 测试用 `Novel` 常量）。

## 关注点

- `hasMore` 的 `items.length >= 10` 启发式在「末页恰好满 10 条且无分页控件」时可能给出一次多余的可翻页提示；这是 brief 明确规定，如需更严格可后续以真实站点结构再校验。
- 未在真实 linovelib 站点做联网冒烟验证（约束禁止测试联网）。
