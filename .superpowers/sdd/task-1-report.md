# Task 1 Report: SlideSwitcher 组件

## What I implemented

Created a reusable, direction-aware slide transition widget plus its widget test.

- `lib/core/widgets/slide_switcher.dart` — `SlideSwitcher` (`StatefulWidget`) with
  `id: Object`, `index: int`, `child: Widget`, `duration: Duration = 250ms`. It wraps
  `AnimatedSwitcher` with a `Stack` layout and a `SlideTransition` transition builder.
  Direction is derived in `didUpdateWidget`: an index increase → incoming from the right
  (`dx = +1`), a decrease → incoming from the left (`dx = -1`); an `id`-only change defaults
  forward. The child is keyed by `ValueKey(widget.id)` so a same-`id` rebuild does not create
  a new switcher entry.
- `test/core/widgets/slide_switcher_test.dart` — 3 `testWidgets` cases: forward direction
  (`dx > 0`), backward direction (`dx < 0`), and no animation on same-`id` rebuild.

Implementation was written exactly as specified in the brief (and identical to the design
spec's component code).

## Test results

```
flutter test test/core/widgets/slide_switcher_test.dart
→ 00:00 +3: All tests passed!

flutter analyze
→ No issues found! (ran in 7.1s)
```

## TDD evidence

**RED** (Step 1, test created before implementation):

```
test/core/widgets/slide_switcher_test.dart:3:8: Error: Error when reading
  'lib/core/widgets/slide_switcher.dart': 系统找不到指定的文件。
test/core/widgets/slide_switcher_test.dart:7:15: Error: Method not found: 'SlideSwitcher'.
00:00 +0 -1: Some tests failed.
```

**Intermediate** (implementation as specified, brief's third assertion unmodified):

```
00:00 +2 -1: Some tests failed.
Expected: no matching candidates
  Actual: _TypeWidgetFinder:<Found 1 widget with type "SlideTransition": ...>
```

**GREEN** (after correcting the third assertion — see Deviations):

```
00:00 +3: All tests passed!
```

The forward/backward assertions genuinely distinguish direction: at 50 ms into the
transition the incoming child's `SlideTransition.position.value.dx` is `> 0` for an index
increase and `< 0` for a decrease.

## Deviations from the brief

The brief's Step 1 test and Step 2 implementation are mutually inconsistent:

- The brief's Step 1 third test asserts `expect(find.byType(SlideTransition), findsNothing)`.
- The brief's Step 2 implementation (and the design spec, `...design.md:85`) wraps the
  current child via `AnimatedSwitcher.transitionBuilder`. Flutter's `AnimatedSwitcher`
  **always** renders `_currentEntry?.transition` through that builder, so exactly one
  `SlideTransition` exists even at rest — `findsNothing` can never hold.

The documented intent (test name "does not animate when only the child rebuilds"; design
spec line 85: `id` 相同而仅内容重建…不触发过渡) is that no animation *runs*, not that the
transition widget is absent. I kept the implementation **verbatim** and corrected only the
third test's assertion to encode that intent:

```dart
await tester.pump();
expect(tester.hasRunningAnimations, isFalse);
final transition = tester.widget<SlideTransition>(find.byType(SlideTransition));
expect(transition.position.value, Offset.zero);
expect(find.text('内容1'), findsOneWidget);
```

The first two tests are byte-for-byte as given in the brief. No other deviation.

## Files changed

- `lib/core/widgets/slide_switcher.dart` (new, 58 lines)
- `test/core/widgets/slide_switcher_test.dart` (new, 64 lines)

Commit: `88529ae feat(ui): add a direction-aware slide switcher` (branch `dev`).

## Self-review

- **Completeness:** widget + test created per brief; the widget exposes the specified
  constructor/interface for Tasks 2–4 (`id`, `index`, `child`, `duration`).
- **Discipline:** only the two files staged and committed; the other dirty
  `.superpowers/sdd/*` files were left untouched; no comments added; no new dependencies.
- **Testing:** RED → GREEN confirmed; the two direction assertions distinguish
  forward/backward; `flutter analyze` clean.

## Concerns

- The brief's third assertion was impossible against the brief's own implementation; I
  corrected the assertion (not the component) and flagged it here. If the reviewer prefers
  a different encoding of "no animation" (e.g. asserting the switcher has no outgoing
  children), the implementation does not need to change.
- `hasRunningAnimations` is false after the same-`id` rebuild, which confirms no new
  animation was started; combined with `position.value == Offset.zero` it captures the
  intended behavior without weakening the check.
