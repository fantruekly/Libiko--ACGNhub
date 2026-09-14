# Task 6 Report: 轻小说首页 UI（`NovelCard` + `NovelHomePage`）并接入 shell

## 实现内容

1. 新建 `lib/modules/novel/novel_home.dart`（按 brief 逐字实现）：
   - `NovelCard`：封面（`CachedNetworkImage`，无封面时按书名 hash 生成占位色块 + 首字）、书名（2 行省略）、作者（1 行省略）。
   - `NovelHomePage`（`ConsumerStatefulWidget`）：
     - 源 chips（来自 `novelSourcesProvider`，默认 `linovelib`）。
     - 分区 chips：推荐 / 排行 / 文库。
     - 排行子 chips（`_rankingOptions` 13 项）、文库子 chips（`_bunkoOptions` 14 项）。
     - 推荐分区走 `novelHomeProvider` + `flattenHome`；排行/文库走 `novelBrowseProvider((sourceId, kind, key, page))`。
     - 加载态 `ShimmerLoader(crossAxisCount: 6)`；错误态 `EmptyState` + 「重试」（`ref.invalidate`）；空数据 `EmptyState('暂无内容')`。
     - 网格 `GridView.builder`（6 列，`childAspectRatio: 0.58`），滚动到底部 400px 内触发下一页。
2. 修改 `lib/shell/main_shell.dart`：
   - 新增 `import '../modules/novel/novel_home.dart';`。
   - `_pages` 第 3 项由 `_buildModulePlaceholder('轻小说', ...)` 改为 `const NovelHomePage()`；游戏占位与其余部分未改动。

## 测试与结果

- 新增 `test/modules/novel/novel_card_test.dart`（brief 逐字）：断言 `NovelCard` 渲染书名与作者。
- `flutter analyze lib test` → `No issues found! (ran in 2.0s)`。
- `flutter test` → `+185 ~1: All tests passed!`（1 个 skip 为既有的 `js_engine_smoke_test` flutter_qjs 原生库在 flutter test 下不可加载，非本任务引入）。
- `flutter build windows --debug` → 成功，产出 `build\windows\x64\runner\Debug\acgnhub.exe`。
- 冒烟启动：`Start-Process` 启动 exe，8 秒后进程仍存活（pid=30672），随后手动结束。**视觉验证未做（无法看到 UI），留给人工。**

## TDD Evidence

### RED
命令：`flutter test test/modules/novel/novel_card_test.dart`
输出（关键）：
```
test/modules/novel/novel_card_test.dart:4:8: Error: Error when reading 'lib/modules/novel/novel_home.dart': 系统找不到指定的文件
import 'package:acgnhub/modules/novel/novel_home.dart';
test/modules/novel/novel_card_test.dart:13:18: Error: Method not found: 'NovelCard'.
00:00 +0 -1: Some tests failed.
```
为何符合预期：实现文件 `novel_home.dart` 尚未创建，`NovelCard` 不存在，编译失败即测试失败——正是「先失败」状态。

### GREEN
命令：`flutter test test/modules/novel/novel_card_test.dart`
输出：
```
00:00 +0: NovelCard shows title and author
00:00 +1: All tests passed!
```

## 变更文件

- 新增 `lib/modules/novel/novel_home.dart`
- 修改 `lib/shell/main_shell.dart`
- 新增 `test/modules/novel/novel_card_test.dart`

## 自审发现

- `novel_home.dart` 与 brief 代码逐字一致，无偏离。
- `main_shell.dart` diff 仅包含 1 行 import + 3 行替换，游戏占位未动。
- `String.characters` 无需额外 import（`material.dart` 间接导出），`flutter analyze` 确认无报错。
- `_page` 在切换源/分区/子选项时重置为 1，逻辑正确。
- 未引入任何新依赖，未设置 `fontFamily`。

## 关注点 / 遗留

- **视觉验证未完成**：本环境无法看到 UI，需人工在「轻小说」标签确认源 chip、网格、排行/文库子 chip 与滚动翻页效果。
- 滚动触底翻页使用 `NotificationListener`，极端快速滚动可能重复触发 `_page++`；此为 brief 指定实现，v1 可接受。
- `.superpowers/sdd/*` 中的 brief/report/progress 变更未纳入本次提交（brief 的 `git add` 仅指定 3 个源码/测试文件）。
