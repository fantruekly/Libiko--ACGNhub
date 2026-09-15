# 副选择栏滑动高亮过渡 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 给轻小说页和漫画页的所有副选择栏（源 / 分区 / 选项 / 分卷）加入滑动高亮过渡：未选中 chip 变纯文字，一个蓝色药丸在 chip 之间平滑滑动。

**Architecture:** 新增共享组件 `ChipBar`（`SizedBox(48)` → 横向滚动 → `Stack`：`AnimatedPositioned` 画药丸 + `Row` 放可点文字 chip）。两个页面的 chip 行改为调用 `ChipBar`；行切换靠 `ValueKey(labels.join('|'))` 重建（跳变），仅选中项变化时播放滑动动画。替换完成后删除不再使用的 `PillChip`。

**Tech Stack:** Flutter/Dart 3.6、Material 3、`AnimatedPositioned` / `AnimatedDefaultTextStyle`。

## Global Constraints

- 运行环境：Flutter 在 `C:\flutter\bin`；命令前缀 `$env:Path = "C:\flutter\bin;$env:Path";`；工作目录 `D:\ACGNhub`。
- 每个任务结束必须：`flutter analyze lib test` 无问题 + `flutter test` 全绿。
- 每个任务结束提交并推送：`git add <精确文件>` → `git commit` → `git push origin dev`。
- 不新增依赖；不改 `pubspec.yaml`。
- 不加代码注释（与现有风格一致者除外）。中文 UI 文案。
- 视觉常量：行高 48、药丸高 36 / 圆角 16 / 颜色 `Color(0xFF007AFF)`、chip 左右 padding 15、chip 间距 10、文字 `fontSize 15 / FontWeight.w500`、选中文字白色、未选中 `Color(0xFF5A5A5F)`、动画 220ms / `Curves.easeInOutCubic`。

---

### Task 1: `ChipBar` 组件

**Files:**
- Create: `lib/core/widgets/chip_bar.dart`
- Test: `test/core/widgets/chip_bar_test.dart`

**Interfaces:**
- Consumes: 无（仅 Flutter）。
- Produces:
  ```dart
  class ChipBar extends StatelessWidget {
    final List<String> labels;
    final int selectedIndex;
    final ValueChanged<int> onSelected;
    final EdgeInsetsGeometry padding;
    const ChipBar({
      super.key,
      required this.labels,
      required this.selectedIndex,
      required this.onSelected,
      this.padding = const EdgeInsets.symmetric(horizontal: 16),
    });
  }
  ```

- [ ] **Step 1: 写失败测试**

创建 `test/core/widgets/chip_bar_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/widgets/chip_bar.dart';

const _pillKey = ValueKey('chip-bar-pill');

Widget _app(int index, {ValueChanged<int>? onSelected}) => MaterialApp(
      home: Scaffold(
        body: ChipBar(
          labels: const ['推荐', '排行', '分类'],
          selectedIndex: index,
          onSelected: onSelected ?? (_) {},
        ),
      ),
    );

void main() {
  testWidgets('renders all labels', (tester) async {
    await tester.pumpWidget(_app(0));
    expect(find.text('推荐'), findsOneWidget);
    expect(find.text('排行'), findsOneWidget);
    expect(find.text('分类'), findsOneWidget);
  });

  testWidgets('tapping a chip reports its index', (tester) async {
    int? tapped;
    await tester.pumpWidget(_app(0, onSelected: (i) => tapped = i));
    await tester.tap(find.text('分类'));
    expect(tapped, 2);
  });

  testWidgets('highlight slides to the newly selected chip', (tester) async {
    await tester.pumpWidget(_app(0));
    await tester.pumpAndSettle();
    final start = tester.getTopLeft(find.byKey(_pillKey)).dx;

    await tester.pumpWidget(_app(2));
    await tester.pump(const Duration(milliseconds: 40));
    final mid = tester.getTopLeft(find.byKey(_pillKey)).dx;

    await tester.pumpAndSettle();
    final end = tester.getTopLeft(find.byKey(_pillKey)).dx;

    expect(start, lessThan(mid));
    expect(mid, lessThan(end));
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/widgets/chip_bar_test.dart`
Expected: 编译失败（`chip_bar.dart` 不存在）。

- [ ] **Step 3: 实现 `ChipBar`**

创建 `lib/core/widgets/chip_bar.dart`：

```dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class ChipBar extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final EdgeInsetsGeometry padding;

  const ChipBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  static const _accent = Color(0xFF007AFF);
  static const _muted = Color(0xFF5A5A5F);
  static const _hPad = 15.0;
  static const _gap = 10.0;
  static const _duration = Duration(milliseconds: 220);

  static TextStyle _style(bool selected) => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: selected ? Colors.white : _muted,
      );

  double _widthOf(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: _style(false)),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = (painter.width + _hPad * 2).ceilToDouble();
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    final index = selectedIndex.clamp(0, labels.length - 1);
    final widths = [for (final label in labels) _widthOf(context, label)];
    final lefts = <double>[];
    var x = 0.0;
    for (final width in widths) {
      lefts.add(x);
      x += width + _gap;
    }
    return SizedBox(
      height: 48,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: const {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
          },
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: padding,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              AnimatedPositioned(
                duration: _duration,
                curve: Curves.easeInOutCubic,
                left: lefts[index],
                top: 6,
                width: widths[index],
                height: 36,
                child: const DecoratedBox(
                  key: ValueKey('chip-bar-pill'),
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: _gap),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onSelected(i),
                        child: SizedBox(
                          width: widths[i],
                          height: 48,
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: _duration,
                              style: _style(i == index),
                              child: Text(labels[i],
                                  maxLines: 1, softWrap: false),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/widgets/chip_bar_test.dart`
Expected: 全部通过。

- [ ] **Step 5: 静态检查与全量测试**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: 全绿。

- [ ] **Step 6: 提交**

```bash
git add lib/core/widgets/chip_bar.dart test/core/widgets/chip_bar_test.dart
git commit -m "feat(ui): add sliding-highlight ChipBar"
git push origin dev
```

---

### Task 2: 轻小说页副选择栏接入 `ChipBar`

**Files:**
- Modify: `lib/modules/novel/novel_home.dart`
- Test: `test/modules/novel/novel_home_test.dart`（如存在则跑；否则以 `flutter test` 全量覆盖）

**Interfaces:**
- Consumes: `ChipBar`（Task 1）。
- Produces: 无新公共接口；`_ExploreTab` 的 `_sourceChips` / `_sectionChips` / `_optionChips` 改为返回 `ChipBar`。

- [ ] **Step 1: 换 import**

在 `lib/modules/novel/novel_home.dart` 顶部，把：

```dart
import '../../core/widgets/pill_chip.dart';
```

替换为：

```dart
import '../../core/widgets/chip_bar.dart';
```

- [ ] **Step 2: 替换 `_sourceChips`**

把：

```dart
  Widget _sourceChips(List<NovelSource> sources) {
    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (final s in sources)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _chip(s.name, s.id == _sourceId, () => setState(() {
                  _sourceId = s.id;
                  _groupIndex = -1;
                  _optionIndex = 0;
                  _page = 1;
                })),
              ),
          ],
        ),
      ),
    );
  }
```

替换为：

```dart
  Widget _sourceChips(List<NovelSource> sources) {
    final labels = [for (final s in sources) s.name];
    final index = sources.indexWhere((s) => s.id == _sourceId);
    return ChipBar(
      key: ValueKey('novel-source-${labels.join('|')}'),
      labels: labels,
      selectedIndex: index < 0 ? 0 : index,
      onSelected: (i) => setState(() {
        _sourceId = sources[i].id;
        _groupIndex = -1;
        _optionIndex = 0;
        _page = 1;
      }),
    );
  }
```

- [ ] **Step 3: 替换 `_sectionChips`**

把：

```dart
  Widget _sectionChips(List<NovelBrowseGroup> groups) {
    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _chip('推荐', _groupIndex < 0, () => setState(() {
                _groupIndex = -1;
                _page = 1;
              })),
            ),
            for (var i = 0; i < groups.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _chip(groups[i].label, _groupIndex == i, () => setState(() {
                  _groupIndex = i;
                  _optionIndex = 0;
                  _page = 1;
                })),
              ),
          ],
        ),
      ),
    );
  }
```

替换为：

```dart
  Widget _sectionChips(List<NovelBrowseGroup> groups) {
    final labels = ['推荐', for (final g in groups) g.label];
    return ChipBar(
      key: ValueKey('novel-section-${labels.join('|')}'),
      labels: labels,
      selectedIndex: _groupIndex + 1,
      onSelected: (i) => setState(() {
        _groupIndex = i - 1;
        _optionIndex = 0;
        _page = 1;
      }),
    );
  }
```

- [ ] **Step 4: 替换 `_optionChips`**

把：

```dart
  Widget _optionChips(NovelBrowseGroup group) {
    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (var i = 0; i < group.options.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _chip(group.options[i].label, _optionIndex == i, () => setState(() {
                  _optionIndex = i;
                  _page = 1;
                })),
              ),
          ],
        ),
      ),
    );
  }
```

替换为：

```dart
  Widget _optionChips(NovelBrowseGroup group) {
    final labels = [for (final o in group.options) o.label];
    return ChipBar(
      key: ValueKey('novel-option-${labels.join('|')}'),
      labels: labels,
      selectedIndex: _optionIndex,
      onSelected: (i) => setState(() {
        _optionIndex = i;
        _page = 1;
      }),
    );
  }
```

- [ ] **Step 5: 删除 `_chip` 辅助方法**

把：

```dart
  Widget _chip(String label, bool selected, VoidCallback onTap) =>
      PillChip(label: label, selected: selected, onTap: onTap);
```

整段删除。

- [ ] **Step 6: 运行静态检查与全量测试**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: 全绿。

- [ ] **Step 7: 提交**

```bash
git add lib/modules/novel/novel_home.dart
git commit -m "feat(novel): sliding-highlight secondary chip bar"
git push origin dev
```

---

### Task 3: 漫画页副选择栏接入 `ChipBar` 并删除 `PillChip`

**Files:**
- Modify: `lib/modules/comic/comic_home.dart`
- Delete: `lib/core/widgets/pill_chip.dart`

**Interfaces:**
- Consumes: `ChipBar`（Task 1）。
- Produces: 无新公共接口；`_DiscoverTab` 的源 / 分区 / 分卷 chips 改为 `ChipBar`；`PillChip` 被删除。

- [ ] **Step 1: 换 import**

在 `lib/modules/comic/comic_home.dart` 顶部，把：

```dart
import '../../core/widgets/pill_chip.dart';
```

替换为：

```dart
import '../../core/widgets/chip_bar.dart';
```

- [ ] **Step 2: 源选择栏改为 `ChipBar`**

把 `_sourceHeader` 中的：

```dart
          Expanded(
            child: _horizontalScroll(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
              child: Row(
                children: [
                  for (final source in sources)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child:
                          _sourceChip(source, source.key == selected.key),
                    ),
                ],
              ),
            ),
          ),
```

替换为：

```dart
          Expanded(
            child: ChipBar(
              key: ValueKey(
                  'comic-source-${[for (final s in sources) s.name].join('|')}'),
              labels: [for (final source in sources) source.name],
              selectedIndex: sources.indexOf(selected),
              onSelected: (i) {
                final source = sources[i];
                setState(() {
                  _selectedKey = source.key;
                  _selectedSection = 0;
                  _selectedPart = 0;
                  _page = 1;
                });
              },
            ),
          ),
```

- [ ] **Step 3: 删除 `_chip` 与 `_sourceChip`**

把：

```dart
  Widget _chip(String label, bool selected, VoidCallback onTap) =>
      PillChip(label: label, selected: selected, onTap: onTap);

  Widget _sourceChip(ComicSource source, bool selected) {
    return _chip(source.name, selected, () {
      setState(() {
        _selectedKey = source.key;
        _selectedSection = 0;
        _selectedPart = 0;
        _page = 1;
      });
    });
  }
```

整段删除。

- [ ] **Step 4: 分区选择栏改为 `ChipBar`**

把：

```dart
  Widget _sectionChips(ComicSource source, int section) {
    if (source.sections.length <= 1) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: _horizontalScroll(
        padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
        child: Row(
          children: [
            for (var i = 0; i < source.sections.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _chip(
                  source.sections[i].title.isEmpty
                      ? '分区 ${i + 1}'
                      : source.sections[i].title,
                  i == section,
                  () => setState(() {
                    _selectedSection = i;
                    _selectedPart = 0;
                    _page = 1;
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
```

替换为：

```dart
  Widget _sectionChips(ComicSource source, int section) {
    if (source.sections.length <= 1) return const SizedBox.shrink();
    final labels = [
      for (var i = 0; i < source.sections.length; i++)
        source.sections[i].title.isEmpty
            ? '分区 ${i + 1}'
            : source.sections[i].title,
    ];
    return ChipBar(
      key: ValueKey('comic-section-${source.key}-${labels.join('|')}'),
      labels: labels,
      selectedIndex: section,
      onSelected: (i) => setState(() {
        _selectedSection = i;
        _selectedPart = 0;
        _page = 1;
      }),
    );
  }
```

- [ ] **Step 5: 分卷选择栏改为 `ChipBar`**

把：

```dart
  Widget _partChips(List<ComicPart> parts, int selected) {
    return SizedBox(
      height: 48,
      child: _horizontalScroll(
        padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
        child: Row(
          children: [
            for (var i = 0; i < parts.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _chip(
                  parts[i].title.isEmpty ? '分区 ${i + 1}' : parts[i].title,
                  i == selected,
                  () => setState(() {
                    _selectedPart = i;
                    _page = 1;
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
```

替换为：

```dart
  Widget _partChips(List<ComicPart> parts, int selected) {
    final labels = [
      for (var i = 0; i < parts.length; i++)
        parts[i].title.isEmpty ? '分区 ${i + 1}' : parts[i].title,
    ];
    return ChipBar(
      key: ValueKey('comic-part-${labels.join('|')}'),
      labels: labels,
      selectedIndex: selected,
      onSelected: (i) => setState(() {
        _selectedPart = i;
        _page = 1;
      }),
    );
  }
```

- [ ] **Step 6: 删除不再使用的 `_horizontalScroll` 与 `gestures` import**

三处 chip 行都换成 `ChipBar` 后，`_horizontalScroll` 已无调用者，且 `PointerDeviceKind` 仅它使用。把：

```dart
  Widget _horizontalScroll(
      {required EdgeInsets padding, required Widget child}) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: const {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        child: child,
      ),
    );
  }
```

整段删除；并把顶部：

```dart
import 'package:flutter/gestures.dart';
```

整行删除。

- [ ] **Step 7: 删除 `PillChip`**

删除文件 `lib/core/widgets/pill_chip.dart`。

- [ ] **Step 8: 静态检查与全量测试**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: 全绿。

- [ ] **Step 9: 提交**

```bash
git add lib/modules/comic/comic_home.dart lib/core/widgets/pill_chip.dart
git commit -m "feat(comic): sliding-highlight secondary chip bar; drop PillChip"
git push origin dev
```

---

## 验证（任务全部完成后）

1. `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` 全绿。
2. `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug` 成功。
3. 启动应用：
   - 漫画页「发现」：点击不同源 / 分区 / 分卷，蓝色高亮药丸滑动到新位置，未选中项为灰色纯文字；切换源时第二行标签变化，药丸直接跳变不横跨。
   - 轻小说页「探索」：源 / 推荐-排行-分类 / 选项同理。
   - 顶部 `TabStrip` 行为不变。

## 已知取舍

- 仅 chip 选中态做过渡，内容区仍用骨架屏（不做淡入/滑动）。
- 选中项不自动滚动入视。
- 行切换（标签列表变化）为跳变，不做跨行滑动动画。
