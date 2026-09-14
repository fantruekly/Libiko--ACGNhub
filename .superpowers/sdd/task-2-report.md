# Task 2 Report: `NovelSource` 抽象与 `NovelSourceManager`

## 实现内容

- 新增 `lib/core/novel/novel_source.dart`：
  - `abstract class NovelSource`：`id` / `name` / `baseUrl` getter，`home()`、`browse(NovelBrowse, {page})`、`search`、`detail`、`chapter` 方法签名，与 brief 逐字一致。
  - `class NovelSourceManager`：构造函数接收可选 `sources` 并逐个 `register`；`sources` 返回不可变视图；`register` 对重复 id 抛 `ArgumentError`；`byId` 线性查找，未命中返回 `null`。
- 新增 `test/core/novel/novel_source_test.dart`：`_FakeSource` + 两个测试（暴露已注册源、拒绝重复 id）。

未新增依赖，SDK 约束未改动，仅依赖 Task 1 的 `models.dart`。

## TDD 证据

### RED

命令：`$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/novel_source_test.dart`

输出（关键部分）：
```
test/core/novel/novel_source_test.dart:3:8: Error: Error when reading 'lib/core/novel/novel_source.dart': 系统找不到指定的文件。
test/core/novel/novel_source_test.dart:5:27: Error: Type 'NovelSource' not found.
test/core/novel/novel_source_test.dart:29:15: Error: Method not found: 'NovelSourceManager'.
00:00 +0 -1: Some tests failed.
```
预期失败原因：实现文件尚不存在，编译失败，符合 TDD 的 RED 阶段。

### GREEN

命令：`$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/novel_source_test.dart`

输出：
```
00:00 +0: manager exposes registered sources
00:00 +1: manager rejects duplicate ids
00:00 +2: All tests passed!
```

## 测试与结果

- 聚焦测试：`flutter test test/core/novel/novel_source_test.dart` → 2/2 通过。
- 静态分析：`flutter analyze lib test` → `No issues found!`。
- 全量测试：`flutter test` → `+175 ~1: All tests passed!`（1 个既有 skip：flutter_qjs 原生库在测试环境不可加载）。

## 变更文件

- `lib/core/novel/novel_source.dart`（新增）
- `test/core/novel/novel_source_test.dart`（新增）

## 提交

- `eeaed68 feat(novel): add NovelSource interface and manager`（已 push 到 `dev`）

## 自查发现

- 实现与 brief 逐字一致，签名可被后续 Task 4/5/6 依赖。
- `sources` 使用 `List.unmodifiable` 防止外部篡改，`register` 的重复检查在构造与手动注册路径上均生效。
- 未改动任何无关文件；工作区中 `.superpowers/sdd/*` 的改动未被纳入本次提交。

## 顾虑

- 无。`search` / `detail` / `chapter` 按 brief 仅声明，v1 后续任务实现。
