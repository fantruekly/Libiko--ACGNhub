## Task 5: 全量回归

- [ ] **Step 1: 全量测试 + 分析**

Run: `C:\flutter\bin\flutter.bat test`；`C:\flutter\bin\flutter.bat analyze`
Expected: 全部 PASS；analyze `No issues found!`。

- [ ] **Step 2: 提交（如有改动）**

无改动则跳过。

---

## 手动验证（合并前，由用户执行）

在 Windows 上运行应用：
1. 游戏首页：切源/分区、翻页时网格左右滑动；底部分页栏不动。
2. 轻小说探索页：切源/分区/子分类、翻页时网格左右滑动；分页栏不动。
3. 漫画发现页：切源/分区/分部、翻页时网格左右滑动；分页栏不动。
4. 顶部分页栏文字（第 N 页）随翻页更新但不滑动。

## 自查记录（Self-Review）

- **Spec 覆盖**：`SlideSwitcher` → Task 1；三处接入 → Task 2/3/4；回归 → Task 5。
- **类型一致性**：`SlideSwitcher` 的 `id: Object`、`index: int`、`child: Widget`、`duration: Duration`；`_explore` 新增 `int sourceIndex` 参数与调用点一致；`ValueKey(widget.id)` 对任意 `Object` 有效（记录类型可作 key）。
- **占位符**：无 TBD/TODO；每步给出完整代码与命令。
- **注意**：`id` 用记录（record）作为 `Object` key；页码作为 `index` 最低位，保证翻页方向正确。
