# Task 10 Report: 详情页顶栏改用 48px 自定义栏 + 无过渡进入

## What I implemented

1. **无过渡路由** (`lib/core/widgets/smooth_route.dart`)
   新增 `Route<T> noTransitionRoute<T>(Widget page)`：`transitionDuration` 与
   `reverseTransitionDuration` 均为 `Duration.zero`，`pageBuilder` 直接返回页面。
   用于目标页自身顶栏在视觉上延续 shell 标题栏的场景（淡入会显得窗口按钮跳动）。

2. **详情页改用自定义 48px 顶栏** (`lib/modules/novel/novel_detail_page.dart`)
   - 新增 `import 'package:window_manager/window_manager.dart';`。
   - 移除 `Scaffold.appBar`，改为
     `body: Column(children: [_header(), Expanded(child: <原 body 内容>)])`。
   - 新增 `_header()`：`DragToMoveArea` + 48px 高 `Container`（白底、
     0.5px `#E5E5EA` 底边框、左内边距 4），内含返回按钮、标题（fontSize 15,
     w600, `_fg`, 单行省略）与 `const WindowControls()`。
   - 由于 Dart 不支持方法重载，原有内容卡片方法 `_header(Novel novel)` 与新顶栏
     `_header()` 同名冲突。为保持 brief 中 `_header()` 的命名（与
     `comic_detail_page.dart` 结构一致），将原方法重命名为 `_infoCard(Novel novel)`，
     并更新 `_content` 中的调用。

3. **首页卡片无过渡进入详情** (`lib/modules/novel/novel_home.dart`)
   `_grid` 的 `itemBuilder` 中 `smoothRoute(NovelDetailPage(...))` 改为
   `noTransitionRoute(NovelDetailPage(...))`。`smooth_route.dart` 导入仍被需要
   （`noTransitionRoute` 来自同一文件），无未使用导入。

## What I tested and results

- `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
  → **No issues found! (ran in 2.3s)**
- `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
  → **All tests passed!** (`+211 ~1`，1 个为 flutter_qjs native 库在测试环境下的既有 skip，与本任务无关)
  包含 `test/modules/novel/novel_detail_page_test.dart`（渲染 title/author/chapters）通过。
- `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug`
  → **√ Built build\windows\x64\runner\Debug\acgnhub.exe**（仅有 webview_windows 的既有 CMake 警告）

## Files changed

- `lib/core/widgets/smooth_route.dart`
- `lib/modules/novel/novel_detail_page.dart`
- `lib/modules/novel/novel_home.dart`

## Self-review findings

- **方法名冲突（已修复）**：brief 指示新增 `_header()`，但文件已有
  `_header(Novel novel)`。Dart 无重载，直接添加会编译失败。已将原内容卡片方法
  重命名为 `_infoCard`，新顶栏保留 brief 中的 `_header()` 命名，与漫画详情页结构一致。
- 顶栏样式、高度、边框、字号与 brief 及 `comic_detail_page.dart` 对齐；
  未设置任何 `fontFamily`，符合全局约束。
- 未新增任何依赖。
- `noTransitionRoute` 返回的 `PageRouteBuilder` 保留系统返回手势/回退动画为即时，
  返回时同样无过渡，符合“首页按钮继续显示”的体感。

## Concerns

- 无功能性问题。仅记录一处与 brief 的偏差：原 `_header(Novel)` 被重命名为
  `_infoCard(Novel)` 以解决命名冲突（brief 未预见该冲突）。
