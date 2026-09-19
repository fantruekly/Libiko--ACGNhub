## Task 9: 接入主壳

**Files:**
- Modify: `lib/shell/main_shell.dart`
- Test: 复用 `test/shell/main_shell_test.dart`（回归）

**Interfaces:**
- Consumes: `GameHomePage`（Task 7）。
- Produces: 主壳 index 3 渲染 `GameHomePage`；删除未使用的 `_buildModulePlaceholder`。

- [ ] **Step 1: 修改主壳**

在 `lib/shell/main_shell.dart`：

1. import 区加入（在 `import '../modules/novel/novel_search.dart';` 之后）：

```dart
import '../modules/game/game_home.dart';
```

2. 将 `_pages` 的第 4 项由占位改为 `GameHomePage`：

```dart
  final _pages = <Widget>[
    const AnimeHomePage(),
    const ComicHomePage(),
    const NovelHomePage(),
    const GameHomePage(),
  ];
```

3. 删除整个 `_buildModulePlaceholder(...)` 静态方法（第 39-73 行那一段），因为不再有调用点。

- [ ] **Step 2: 运行回归测试**

Run: `flutter test test/shell/main_shell_test.dart`
Expected: PASS（1 test）。若失败，检查 `_buildModulePlaceholder` 是否已删除、`GameHomePage` 是否 import。

- [ ] **Step 3: 静态检查**

Run: `flutter analyze`
Expected: `No issues found!`（若提示 `_buildModulePlaceholder` 未使用，说明第 3 步未删干净）。

- [ ] **Step 4: 全量测试**

Run: `flutter test`
Expected: 全部 PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/shell/main_shell.dart
git commit -m "feat(shell): mount the game home page"
```

---

## 手动验证（实现完成后、提 PR 前）

在 Windows 上 `flutter run -d windows`，进入「游戏」Tab：

1. 首页默认「最近更新」有封面网格；切换「玩家热评 / 资源推荐 / 好游推荐 / 玩家最爱」分区能加载不同内容。
2. 「下一页」可用并翻到第 2 页；末页时「下一页」禁用。
3. 点任一卡片进入详情页：封面、标题、分类/标签、发布日期/大小/平台、简介段落、截图画廊均正常。
4. 点截图能全屏放大（可缩放、左右滑动）。
5. 点右上「在原站打开」用系统浏览器打开对应 `game.galgamezywz.org/game/<id>` 页面。
6. 断开网络后重进，显示「加载失败 / 重试」。

---

## 自查记录（Self-Review）

- **Spec 覆盖**：模型→Task 1；`GameSource`→Task 2；列表/分页解析→Task 3；详情解析→Task 4；`GalgameZywzSource`→Task 5；providers→Task 6；首页→Task 7；详情页 + url_launcher→Task 8；主壳接入→Task 9。错误处理与测试散落各任务并有回归步骤。
- **类型一致性**：`GameDetail` 字段（`size/platform/updatedAt/paragraphs/screenshots/sourceUrl`）在 Task 1 定义，Task 4 构造、Task 8 消费一致；`parseHasNextPage(html, {required itemCount})` 在 Task 3 定义并被 Task 5 调用；`gameBrowseProvider` 键类型 `(String,String,int)` 在 Task 6/7 一致。
- **占位符**：无 TBD/TODO；每个代码步骤均给出完整代码与命令。
- **偏差说明**：详情页 widget 测试不含截图画廊断言（避免测试环境加载网络图片），画廊数据由 Task 3/4 解析单测覆盖、渲染手动验证。
