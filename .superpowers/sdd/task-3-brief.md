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