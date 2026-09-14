### Task 8: 详情页/阅读器加窗口控制按钮

> 用户反馈：进入轻小说详情页后右上角最小化/最大化/关闭按钮消失。根因：详情页与阅读器是 push 的全屏路由，盖住了 shell 标题栏里的 `WindowControls`。

**Files:**
- Modify: `lib/modules/novel/novel_detail_page.dart`
- Modify: `lib/modules/novel/novel_reader_page.dart`

**Interfaces:**
- Consumes: `WindowControls`（`lib/core/widgets/window_controls.dart`，已存在）。

- [ ] **Step 1: 详情页 AppBar 加 actions**

`novel_detail_page.dart`：加 `import '../../core/widgets/window_controls.dart';`；`AppBar` 增加 `actions`：

```dart
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: const [WindowControls()],
      ),
```

- [ ] **Step 2: 阅读器顶栏加窗口按钮**

`novel_reader_page.dart`：加 `import '../../core/widgets/window_controls.dart';`；`_topBar` 的 `Row` 末尾（标题之后）加 `const WindowControls()`：

```dart
            Expanded(
              child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: palette.fg)),
            ),
            const WindowControls(),
```

- [ ] **Step 3: 全量校验 + 提交**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → 全部通过

```bash
git add lib/modules/novel/novel_detail_page.dart lib/modules/novel/novel_reader_page.dart
git commit -m "fix(novel): show window controls on detail and reader pages"
git push
```

---

## Self-Review

**Spec coverage:**
- `parseChapter`/`nextPageHref`/`fetchChapterPages` → Task 1。
- `LinovelibSource.chapter`（同章分页拼接、50 页上限）→ Task 1/2。
- 阅读设置（模型/manager/provider、默认值与 clamp、三主题）→ Task 3。
- `novelChapterProvider`/`flattenChapters` → Task 4。
- `NovelReaderPage`（正文、顶/底栏、目录、设置、三态、切章回顶）+ 详情页接线 → Task 5。
- 测试（解析 fixture、设置模型、阅读器 widget）→ Task 1/3/5。

**Placeholder scan:** 无 TBD/TODO；每个代码步骤含完整代码。

**Type consistency:** `NovelChapter`（已有）在 Task 1/2/4/5 一致；`parseChapter`/`nextPageHref`/`fetchChapterPages`（Task 1）在 Task 2 使用；`NovelReaderSettings`/`NovelReaderTheme`/`novelReaderSettingsProvider`（Task 3）在 Task 5 使用；`novelChapterProvider`/`flattenChapters`（Task 4）在 Task 5 使用；`NovelChapterRef` 来自 `models.dart`。