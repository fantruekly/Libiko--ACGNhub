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
