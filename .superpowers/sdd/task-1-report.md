# Task 1 Report: linovelib 搜索

## Status

DONE

## Summary

为 `LinovelibSource` 增加跨源搜索能力的第一个任务：新增纯解析器 `parseSearchResults(String html)`，并通过 `POST https://www.linovelib.com/S6/`（表单 `searchkey=<kw>`）实现 `LinovelibSource.search(keyword, {page})`。后续任务的 lknovel 搜索、聚合 provider、搜索页均依赖 `search()` 存在。

## Implemented

- `List<Novel> parseSearchResults(String html)`（置于 `parseMobileBookList` 之后）：
  - 遍历 `div.search-result-list`；
  - 从 `h2.tit a` 取标题与 `novelIdFromHref` 解析 id；
  - 封面取 `div.imgbox img` 的 `data-original`（回退 `src`），经 `_absUrl` 绝对化；
  - 作者取 `div.bookinfo a` 首个文本，简介取 `p` 文本；
  - 空作者/封面/简介转为 `null`，`extra['url']` 为 `$linovelibBaseUrl/novel/$id.html`。
- `LinovelibSource.search`：trim 关键词，空则返回 `const []`；`_dio.post<String>('/S6/', data: {'searchkey': k}, options: Options(responseType: ResponseType.plain, contentType: Headers.formUrlEncodedContentType))`；非 200 或 null 抛 `Exception('linovelib 搜索失败：$k (${res.statusCode})')`；否则 `parseSearchResults(html)`。

## TDD Evidence

### RED

Command:
`$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_search_parser_test.dart`

Result (compilation failure — parser undefined):

```
test/core/novel/linovelib_search_parser_test.dart:17:19: Error: Method not found: 'parseSearchResults'.
test/core/novel/linovelib_search_parser_test.dart:29:12: Error: Method not found: 'parseSearchResults'.
00:00 +0 -1: Some tests failed.
```

### GREEN

Command:
`$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_search_parser_test.dart`

Result:

```
00:00 +2: All tests passed!
```

### Analyze

Command:
`$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`

Result:

```
Analyzing 2 items...
No issues found! (ran in 2.3s)
```

### Full suite

Command:
`$env:Path = "C:\flutter\bin;$env:Path"; flutter test`

Result:

```
00:13 +253 ~1: All tests passed!
```

(253 passed, 1 skipped pre-existing.)

## Files Changed

- `lib/core/novel/linovelib_source.dart` — 新增 `parseSearchResults`；`search` 由 `throw UnimplementedError()` 改为 POST `/S6/` 实现。
- `test/core/novel/linovelib_search_parser_test.dart` — 新增解析器测试（2 条）。

## Commits

- `2a0aabe` feat(novel): linovelib search（已 push 至 `origin/dev`）

## Self-Review

- 新增解析器测试通过（含空结果用例）。✔
- `flutter analyze lib test` clean（`No issues found!`）。✔
- `flutter test` 全绿（253 passed, 1 skipped）。✔
- 无新依赖；`pubspec.yaml` 未改动。✔
- 未添加 brief 之外的代码注释。✔
- 仅改动 `lib/core/novel/linovelib_source.dart` 与新增测试文件。✔
- `page` 参数按 brief 签名保留但未使用（brief 代码如此），无 analyze 告警。✔

## Concerns

- `search` 的 `page` 参数被接受但未参与请求；当前 `/S6/` 表单仅提交 `searchkey`。若后续需要分页，需确认站点搜索分页参数（可能为 `page`），并在后续任务补齐。此为 brief 明确指定的实现，未擅自扩展。
- 解析器假设每个结果卡片为独立的 `div.search-result-list`；若站点真实 DOM 为「一个列表容器 + 多个子项」，则需调整选择器。已按 brief 给定 HTML 夹具实现。
