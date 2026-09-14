# Task 9 Report: 小说图片加 Referer 头（修插图与部分封面）

## 状态
DONE

## 实现内容
- 在 `lib/core/novel/linovelib_source.dart` 顶部常量区新增共享常量：
  ```dart
  const Map<String, String> novelImageHeaders = {
    'Referer': 'https://www.linovelib.com/',
  };
  ```
- 三处小说 `CachedNetworkImage` 均加上 `httpHeaders: novelImageHeaders`，并补上对应 import：
  - `novel_home.dart` 的 `NovelCard` 封面（`memCacheWidth: 400` 之后）
  - `novel_detail_page.dart` 的详情页封面
  - `novel_reader_page.dart` 的章节插图
- 根因：`img3.readpai.com` 图片有防盗链，无 `Referer` 返回 403，带 `Referer: https://www.linovelib.com/` 返回 200；`CachedNetworkImage` 默认不带 Referer。修复后插图与部分封面可正常加载。

## 测试与结果
- `flutter analyze lib test` → `No issues found! (ran in 2.1s)`
- `flutter test` → `+211 ~1: All tests passed!`
  - `~1` 为既有 `js_engine_smoke_test` 在 `flutter test` 下按设计 skip（flutter_qjs 原生库不可加载），与本任务无关。

## 变更文件
- `lib/core/novel/linovelib_source.dart`（新增 `novelImageHeaders` 常量）
- `lib/modules/novel/novel_home.dart`（import + `httpHeaders`）
- `lib/modules/novel/novel_detail_page.dart`（import + `httpHeaders`）
- `lib/modules/novel/novel_reader_page.dart`（import + `httpHeaders`）

## 自查发现
- 逐字核对了 brief 中的常量与三处 `httpHeaders` 写法，与 diff 一致。
- `git diff` 确认仅改动预期 4 个 lib 文件；`git add` 只显式加入这 4 个文件，未混入工作区其他未相关改动（briefs/plans 等）。
- 未新增任何依赖；`environment.sdk >=3.6.0` 不变。
- `novelImageHeaders` 为 `const Map`，可安全用于 `CachedNetworkImage.httpHeaders`（`Map<String,String>?`）。

## 顾虑
- 无。常量作用域为全局，若未来接入非 linovelib 图源，其图片也会带上该 Referer；当前项目仅 linovelib 一个小说源，暂不影响。
