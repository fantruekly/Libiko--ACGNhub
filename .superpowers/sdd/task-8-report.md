# Task 8 报告：详情页/阅读器加窗口控制按钮

## 实现内容

按 brief 逐字实现，改动最小：

1. **详情页** `lib/modules/novel/novel_detail_page.dart`
   - 新增 `import '../../core/widgets/window_controls.dart';`
   - `AppBar` 增加 `actions: const [WindowControls()],`

2. **阅读器** `lib/modules/novel/novel_reader_page.dart`
   - 新增 `import '../../core/widgets/window_controls.dart';`
   - `_topBar` 的 `Row` 末尾（标题 `Expanded` 之后）加 `const WindowControls(),`

未在其他任何位置添加窗口控件。

## 测试与结果

| 命令 | 结果 |
| --- | --- |
| `flutter analyze lib test` | `No issues found!` |
| `flutter test` | `+211 ~1: All tests passed!`（1 个既有 skip：flutter_qjs native 在 test 下不可加载） |
| `flutter build windows --debug` | `√ Built build\windows\x64\runner\Debug\acgnhub.exe` |

## 变更文件

- `lib/modules/novel/novel_detail_page.dart`（+2）
- `lib/modules/novel/novel_reader_page.dart`（+2）

提交：`cfeaf12 fix(novel): show window controls on detail and reader pages`，已推送 `dev`。

## 自审发现

- 导入按字母序插入，符合现有风格。
- 阅读器顶栏高 56，`WindowControls` 高 48，垂直方向不溢出；3 个按钮各宽 46，与返回键 + 标题 `Expanded` 同排布局正常。
- 详情页 `AppBar` 默认高 56，同样容纳 48 高的控件。
- 无新增依赖；无 `TextStyle` 设置 `fontFamily`。
- `WindowControls` 在 `initState`/`dispose` 成对添加/移除 `windowManager` 监听，路由叠加（详情页在阅读器之下仍挂载）不会泄漏监听。

## 遗留/关注点

- 无功能性遗留。仅提示：`WindowControls` 每次实例化都会 `windowManager.addListener`，详情页与阅读器同时挂载时会有两个监听器，行为正确、随 dispose 释放，属既有设计，未改动。
- 本次仅 `git add` 两个目标文件；工作区中其余 `.superpowers/sdd/*`、`docs/superpowers/plans/*` 的改动未纳入本次提交。
