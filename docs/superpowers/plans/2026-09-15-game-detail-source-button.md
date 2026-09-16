# 游戏详情页「在原站打开」按钮 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把游戏详情页的「在原站打开」从顶栏图标移到信息卡封面右侧列、标签下方，并改成与收藏按钮一致的 `FilledButton.icon` 样式。

**Architecture:** 仅改 `lib/modules/game/game_detail_page.dart`：`_header` 去掉按钮与 `detail` 参数；`_infoCard` 右侧列在标签下方加入按钮，点击复用现有 `_openSource`。同步更新详情页测试断言。

**Tech Stack:** Flutter (Dart 3.6)、`url_launcher`（已有，无新增依赖）。

## Global Constraints

- 仅改动游戏详情页与其测试；不改其它页面/布局。
- 无新增依赖。不添加代码注释（除非下方给定代码已含）。
- 在 `dev` 分支开发；完成后提交。
- 测试命令：`C:\flutter\bin\flutter.bat test <path>`；静态检查：`C:\flutter\bin\flutter.bat analyze`。

---

## Task 1: 移动并重设「在原站打开」按钮

**Files:**
- Modify: `lib/modules/game/game_detail_page.dart`
- Test: `test/modules/game/game_detail_page_test.dart`

### Step 1: 更新测试（先失败）

在 `test/modules/game/game_detail_page_test.dart` 中，把第 50 行：

```dart
    expect(find.byTooltip('在原站打开'), findsOneWidget);
```

改为：

```dart
    expect(find.text('在原站打开'), findsOneWidget);
```

Run: `C:\flutter\bin\flutter.bat test test/modules/game/game_detail_page_test.dart`
Expected: FAIL —— 当前「在原站打开」是顶栏 `IconButton`（只有 tooltip、无 `Text`），`find.text` 找不到。

### Step 2: 移除顶栏按钮

`lib/modules/game/game_detail_page.dart`：

1) `build` 中把 `_header(context, async.valueOrNull)` 改为 `_header(context)`。

2) 把 `_header` 的签名 `Widget _header(BuildContext context, GameDetail? detail)` 改为 `Widget _header(BuildContext context)`，并删除其 `Row` 内的这段（第 99–106 行）：

```dart
            IconButton(
              tooltip: '在原站打开',
              icon: const Icon(Icons.open_in_new_rounded, size: 20),
              color: _muted,
              onPressed: detail == null
                  ? null
                  : () => _openSource(detail.sourceUrl),
            ),
```

（`_header` 保留返回 + 标题 + `WindowControls`。）

### Step 3: 在标签下方加入按钮

在 `_infoCard` 的右侧列（`Expanded` → `Column`）中，把 `Wrap(...)` 之后补上间距与按钮，使其变为：

```dart
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (game.category != null && game.category!.isNotEmpty)
                          _tag(game.category!),
                        for (final t in game.tags) _tag(t),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        backgroundColor: const Color(0xFF007AFF),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: detail.sourceUrl.isEmpty
                          ? null
                          : () => _openSource(detail.sourceUrl),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('在原站打开',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
```

`_openSource(String url)` 保持不变。

### Step 4: 运行测试确认通过

Run:
- `C:\flutter\bin\flutter.bat test test/modules/game/game_detail_page_test.dart`
- `C:\flutter\bin\flutter.bat test test/modules/game/game_search_page_test.dart`
- `C:\flutter\bin\flutter.bat analyze`
Expected: 均 PASS；analyze `No issues found!`。

### Step 5: 提交

```bash
git add lib/modules/game/game_detail_page.dart test/modules/game/game_detail_page_test.dart
git commit -m "feat(game): move the open-on-source button beside the cover"
```

---

## 手动验证（合并前，由用户执行）

在 Windows 上运行应用，进入任一游戏详情页：
1. 顶栏不再有「在原站打开」图标。
2. 信息卡封面右侧、标签下方出现蓝色「在原站打开」按钮，样式与收藏按钮一致。
3. 点击用系统浏览器打开源站详情页；加载中按钮为禁用态。

## 自查记录（Self-Review）

- **Spec 覆盖**：顶栏移除 → Step 2；信息卡标签下方按钮 + 样式 → Step 3；测试断言 → Step 1。
- **类型一致性**：`_header` 由 `(BuildContext, GameDetail?)` 改为 `(BuildContext)`，唯一调用点同步；`detail.sourceUrl` 为 `String`；`FilledButton.icon` 的 `icon`/`label` 与收藏按钮一致。
- **占位符**：无 TBD/TODO；给出完整代码与命令。
- **注意**：加载态传入的合成 `GameDetail(sourceUrl: '')` 使按钮 `onPressed` 为 `null`（禁用），与原先顶栏按钮在加载时禁用的行为一致。
