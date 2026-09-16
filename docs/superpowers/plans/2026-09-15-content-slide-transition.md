# 漫画/轻小说/游戏 内容左右滑动过渡 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 漫画发现页、轻小说探索页、游戏首页在切源/分区/子分类/翻页时，网格左右滑动过渡；底部分页栏固定不动。

**Architecture:** 新增可复用 `SlideSwitcher`（`AnimatedSwitcher` + 方向感知 `SlideTransition`）。三处把**网格区域**（`Expanded` 内）包进 `SlideSwitcher`，分页栏留在外面。`id`/`index` 含源/分区/子分类/页码，页码为最低位。

**Tech Stack:** Flutter (Dart 3.6)（无新增依赖）。

## Global Constraints

- 仅改动：新增 `slide_switcher.dart` 及其测试；接入 `game_home.dart`、`novel_home.dart`、`comic_home.dart`。
- 不改顶部 Tab；不改详情页；不引入拖拽跟手。
- 无新增依赖。不添加代码注释（除非下方给定代码已含）。
- 在 `dev` 分支开发；每个任务结束提交一次。
- 测试命令：`C:\flutter\bin\flutter.bat test <path>`；静态检查：`C:\flutter\bin\flutter.bat analyze`。

---

## Task 1: SlideSwitcher 组件

**Files:**
- Create: `lib/core/widgets/slide_switcher.dart`
- Test: `test/core/widgets/slide_switcher_test.dart`

**Interfaces:**
- Produces: `class SlideSwitcher extends StatefulWidget { SlideSwitcher({Key? key, required Object id, required int index, required Widget child, Duration duration = const Duration(milliseconds: 250)}) }`。

### Step 1: 写测试（先失败）

Create `test/core/widgets/slide_switcher_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/widgets/slide_switcher.dart';

Widget _app(int index) => MaterialApp(
      home: Scaffold(
        body: SlideSwitcher(
          id: index,
          index: index,
          child: SizedBox.expand(child: Text('内容$index')),
        ),
      ),
    );

void main() {
  testWidgets('slides forward from the right when the index increases',
      (tester) async {
    await tester.pumpWidget(_app(0));
    await tester.pumpWidget(_app(1));
    await tester.pump(const Duration(milliseconds: 50));

    final incoming = tester.widget<SlideTransition>(find.ancestor(
      of: find.text('内容1'),
      matching: find.byType(SlideTransition),
    ));
    expect(incoming.position.value.dx, greaterThan(0));

    await tester.pumpAndSettle();
    expect(find.text('内容1'), findsOneWidget);
    expect(find.text('内容0'), findsNothing);
  });

  testWidgets('slides backward from the left when the index decreases',
      (tester) async {
    await tester.pumpWidget(_app(2));
    await tester.pumpWidget(_app(1));
    await tester.pump(const Duration(milliseconds: 50));

    final incoming = tester.widget<SlideTransition>(find.ancestor(
      of: find.text('内容1'),
      matching: find.byType(SlideTransition),
    ));
    expect(incoming.position.value.dx, lessThan(0));

    await tester.pumpAndSettle();
    expect(find.text('内容1'), findsOneWidget);
    expect(find.text('内容2'), findsNothing);
  });

  testWidgets('does not animate when only the child rebuilds', (tester) async {
    await tester.pumpWidget(_app(1));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_app(1));
    await tester.pumpAndSettle();
    expect(find.byType(SlideTransition), findsNothing);
    expect(find.text('内容1'), findsOneWidget);
  });
}
```

Run: `C:\flutter\bin\flutter.bat test test/core/widgets/slide_switcher_test.dart`
Expected: FAIL（找不到 `slide_switcher.dart`）。

### Step 2: 实现

Create `lib/core/widgets/slide_switcher.dart`:

```dart
import 'package:flutter/material.dart';

class SlideSwitcher extends StatefulWidget {
  final Object id;
  final int index;
  final Widget child;
  final Duration duration;

  const SlideSwitcher({
    super.key,
    required this.id,
    required this.index,
    required this.child,
    this.duration = const Duration(milliseconds: 250),
  });

  @override
  State<SlideSwitcher> createState() => _SlideSwitcherState();
}

class _SlideSwitcherState extends State<SlideSwitcher> {
  bool _forward = true;

  @override
  void didUpdateWidget(SlideSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      _forward = widget.index > oldWidget.index;
    } else if (widget.id != oldWidget.id) {
      _forward = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: widget.duration,
      switchInCurve: Curves.easeInOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        fit: StackFit.expand,
        children: [
          ...previousChildren,
          if (currentChild != null) currentChild,
        ],
      ),
      transitionBuilder: (child, animation) {
        final incoming = child.key == ValueKey(widget.id);
        final dir =
            incoming ? (_forward ? 1.0 : -1.0) : (_forward ? -1.0 : 1.0);
        return SlideTransition(
          position: Tween<Offset>(begin: Offset(dir, 0), end: Offset.zero)
              .animate(animation),
          child: child,
        );
      },
      child: KeyedSubtree(key: ValueKey(widget.id), child: widget.child),
    );
  }
}
```

Run: `C:\flutter\bin\flutter.bat test test/core/widgets/slide_switcher_test.dart`
Expected: PASS（3 tests）。

### Step 3: 静态检查 + 提交

Run: `C:\flutter\bin\flutter.bat analyze`
Expected: `No issues found!`

```bash
git add lib/core/widgets/slide_switcher.dart test/core/widgets/slide_switcher_test.dart
git commit -m "feat(ui): add a direction-aware slide switcher"
```

---

## Task 2: 游戏首页接入

**Files:**
- Modify: `lib/modules/game/game_home.dart`
- Test: `test/modules/game/game_home_test.dart`（回归）

### Step 1: 接入

1) import 加入 `import '../../core/widgets/slide_switcher.dart';`

2) 在 `_body`（第 160 行起）中，`final option = ...` 之后加入：

```dart
    final sourceIndex =
        ref.watch(gameSourcesProvider).indexWhere((s) => s.id == _sourceId);
```

3) 把 `data:` 分支（第 173–178 行）替换为：

```dart
      data: (list) => Column(
        children: [
          Expanded(
            child: SlideSwitcher(
              id: (_sourceId, option.key, _page),
              index: sourceIndex * 10000 + _optionIndex * 100 + _page,
              child: _grid(list.items),
            ),
          ),
          _pager(list.hasMore),
        ],
      ),
```

### Step 2: 运行回归

Run:
- `C:\flutter\bin\flutter.bat test test/modules/game/game_home_test.dart`
- `C:\flutter\bin\flutter.bat analyze`
Expected: PASS；analyze 无问题。

### Step 3: 提交

```bash
git add lib/modules/game/game_home.dart
git commit -m "feat(game): slide the grid when switching sections or pages"
```

---

## Task 3: 轻小说探索页接入

**Files:**
- Modify: `lib/modules/novel/novel_home.dart`
- Test: `test/modules/novel/novel_home_tabs_test.dart`、`test/modules/novel/novel_home_pager_test.dart`（回归）

### Step 1: 接入

1) import 加入 `import '../../core/widgets/slide_switcher.dart';`

2) 在 `_ExploreTabState._body`（第 201 行起）顶部加入：

```dart
    final sourceIndex =
        ref.watch(novelSourcesProvider).indexWhere((s) => s.id == _sourceId);
```

3) 「推荐」分支的 `data:`（第 216 行）改为：

```dart
        data: (home) => SlideSwitcher(
          id: (_sourceId, '__home__'),
          index: sourceIndex * 1000000,
          child: _grid(flattenHome(home)),
        ),
```

4) 分组分支的 `data:`（第 238–243 行）替换为：

```dart
      data: (list) => Column(
        children: [
          Expanded(
            child: SlideSwitcher(
              id: (_sourceId, option.key, _page),
              index: sourceIndex * 1000000 +
                  (_groupIndex + 1) * 10000 +
                  _optionIndex * 100 +
                  _page,
              child: _grid(list.items),
            ),
          ),
          _pager(list.hasMore),
        ],
      ),
```

### Step 2: 运行回归

Run:
- `C:\flutter\bin\flutter.bat test test/modules/novel/novel_home_tabs_test.dart`
- `C:\flutter\bin\flutter.bat test test/modules/novel/novel_home_pager_test.dart`
- `C:\flutter\bin\flutter.bat analyze`
Expected: PASS；analyze 无问题。

### Step 3: 提交

```bash
git add lib/modules/novel/novel_home.dart
git commit -m "feat(novel): slide the grid when switching sections or pages"
```

---

## Task 4: 漫画发现页接入

**Files:**
- Modify: `lib/modules/comic/comic_home.dart`
- Test: `test/modules/comic/comic_explore_paging_test.dart`（回归）

### Step 1: 接入

1) import 加入 `import '../../core/widgets/slide_switcher.dart';`

2) 调用点（第 133 行）改为：

```dart
            Expanded(child: _explore(selected, section, part, sources.indexOf(selected))),
```

3) `_explore` 签名（第 209 行）改为：

```dart
  Widget _explore(ComicSource source, int section, int part, int sourceIndex) {
```

4) 把 `_explore` 里的 `Expanded(child: async.when(...))`（第 224–268 行）替换为：

```dart
        Expanded(
          child: SlideSwitcher(
            id: (source.key, section, part, _page),
            index: sourceIndex * 1000000 +
                section * 10000 +
                part * 100 +
                _page,
            child: async.when(
              loading: () => const ShimmerLoader(
                crossAxisCount: 6,
                itemCount: 12,
                padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
              ),
              error: (_, __) => EmptyState(
                icon: Icons.cloud_off_rounded,
                message: '加载失败',
                actionLabel: '重试',
                onAction: () {
                  clearExploreCache(source.key, section);
                  ref.invalidate(comicSourcePageProvider);
                  ref.invalidate(
                      comicExploreAllProvider((source.key, section)));
                  ref.invalidate(comicExploreProvider(
                      (source.key, section, part, _page)));
                },
              ),
              data: (data) {
                if (data.comics.isEmpty) {
                  return const EmptyState(
                      icon: Icons.image_not_supported_rounded, message: '暂无内容');
                }
                return _comicGrid(
                  count: data.comics.length,
                  itemBuilder: (i) => ComicCard(
                    title: data.comics[i].title,
                    cover: data.comics[i].cover,
                    heroTag: 'comic_${source.key}_${data.comics[i].id}',
                    onTap: () => Navigator.push(
                      context,
                      smoothRoute(ComicDetailPage(
                        sourceKey: source.key,
                        comicId: data.comics[i].id,
                        title: data.comics[i].title,
                        cover: data.comics[i].cover,
                      )),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
```

（`_paginationBar` 保持在 `SlideSwitcher` 之外。）

### Step 2: 运行回归

Run:
- `C:\flutter\bin\flutter.bat test test/modules/comic/comic_explore_paging_test.dart`
- `C:\flutter\bin\flutter.bat analyze`
Expected: PASS；analyze 无问题。

### Step 3: 提交

```bash
git add lib/modules/comic/comic_home.dart
git commit -m "feat(comic): slide the grid when switching sections or pages"
```

---

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
