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

