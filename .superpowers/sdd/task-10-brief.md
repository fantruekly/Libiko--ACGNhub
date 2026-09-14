### Task 10: 详情页顶栏改用 48px 自定义栏 + 无过渡进入

> 用户反馈：详情页右上角按钮要像漫画详情页那样；进入详情页不要过渡（感觉像首页按钮继续显示）。

**Files:**
- Modify: `lib/core/widgets/smooth_route.dart`
- Modify: `lib/modules/novel/novel_detail_page.dart`
- Modify: `lib/modules/novel/novel_home.dart`

**Interfaces:**
- Produces: `Route<T> noTransitionRoute<T>(Widget page)`。

- [ ] **Step 1: 加无过渡路由**

`lib/core/widgets/smooth_route.dart` 末尾加：

```dart
/// An instant route (no transition) used when the destination's own top bar
/// visually continues the shell's title bar (so a fade would look like the
/// window controls jumped).
Route<T> noTransitionRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (_, __, ___) => page,
  );
}
```

- [ ] **Step 2: 详情页改用自定义 48px 顶栏**

`novel_detail_page.dart`：加 `import 'package:window_manager/window_manager.dart';`（若未导入）。把 `Scaffold` 的 `appBar: AppBar(...)` 去掉，改为 `body: Column(children: [_header(), Expanded(child: <原 body 内容>)])`，并加：

```dart
  Widget _header() {
    return DragToMoveArea(
      child: Container(
        height: 48,
        padding: const EdgeInsets.only(left: 4),
        decoration: const BoxDecoration(
          color: Color(0xFFFFFFFF),
          border:
              Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              color: _fg,
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: _fg),
              ),
            ),
            const WindowControls(),
          ],
        ),
      ),
    );
  }
```

（`_fg` 已在该文件定义；`WindowControls` 已导入。）

- [ ] **Step 3: 首页卡片用无过渡路由打开详情**

`novel_home.dart` 的 `_grid` `itemBuilder`：把 `smoothRoute(NovelDetailPage(...))` 改为 `noTransitionRoute(NovelDetailPage(...))`。

- [ ] **Step 4: 全量校验 + 提交**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → 全部通过

```bash
git add lib/core/widgets/smooth_route.dart lib/modules/novel/novel_detail_page.dart lib/modules/novel/novel_home.dart
git commit -m "fix(novel): 48px detail header and instant transition"
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