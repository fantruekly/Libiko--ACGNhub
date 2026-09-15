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
