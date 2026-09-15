# Task 1 Report: `ChipBar` widget

## Status
DONE

## What I implemented
Created the reusable sliding-highlight `ChipBar` widget exactly as specified in the brief:

- `lib/core/widgets/chip_bar.dart` — a `StatelessWidget` that:
  - Takes `labels`, `selectedIndex`, `onSelected`, and an optional `padding`
    (default `EdgeInsets.symmetric(horizontal: 16)`).
  - Renders a horizontally scrollable row of label chips.
  - Measures each label with a `TextPainter` (chip width = text width + `2 * 15` padding).
  - Animates a single accent pill (`Color(0xFF007AFF)`, radius 16, height 36) behind
    the selected chip using `AnimatedPositioned` (220ms, `Curves.easeInOutCubic`).
  - Fades the selected label to white via `AnimatedDefaultTextStyle`; unselected
    labels use `Color(0xFF5A5A5F)`; both `fontSize: 15`, `FontWeight.w500`.
  - Row height 48, chip gap 10.
  - Guards against empty `labels` and clamps `selectedIndex` into range.
  - Enables mouse/trackpad drag scrolling via `ScrollConfiguration`.
- `test/core/widgets/chip_bar_test.dart` — the three widget tests from the brief
  (renders all labels; tap reports index; highlight slides on selection change).

No page wiring (Tasks 2 & 3), no `pubspec.yaml` change, no new dependencies,
no code comments (consistent with existing widget style). The widget being unused
by app code after this task is expected.

## What I tested and results
- Focused test: `flutter test test/core/widgets/chip_bar_test.dart` → 3/3 pass.
- Static analysis: `flutter analyze lib test` → `No issues found! (ran in 4.2s)`.
- Full suite: `flutter test` → `+268 ~1: All tests passed!`
  (the `~1` is the pre-existing `js_engine_smoke_test.dart` skip for the
  unavailable `flutter_qjs` native DLL, unrelated to this change).

## TDD evidence

### RED (before implementation)
Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/widgets/chip_bar_test.dart
```
Output (excerpt):
```
00:00 +0 -1: loading D:/ACGNhub/test/core/widgets/chip_bar_test.dart [E]
  Failed to load "D:/ACGNhub/test/core/widgets/chip_bar_test.dart":
  Compilation failed ... Error when reading 'lib/core/widgets/chip_bar.dart':
  系统找不到指定的文件。
  import 'package:acgnhub/core/widgets/chip_bar.dart';
  test/core/widgets/chip_bar_test.dart:9:15: Error: Method not found: 'ChipBar'.
00:00 +0 -1: Some tests failed.
```
Why the failure was expected: the test imports and instantiates `ChipBar`, but
`lib/core/widgets/chip_bar.dart` had not been created yet, so the test could not
compile. This confirms the test genuinely exercises the new widget rather than
passing vacuously.

### GREEN (after implementation)
Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/widgets/chip_bar_test.dart
```
Output (excerpt):
```
00:00 +0: renders all labels
00:00 +1: tapping a chip reports its index
00:00 +2: highlight slides to the newly selected chip
00:00 +3: All tests passed!
```

## Files changed
- `lib/core/widgets/chip_bar.dart` (new, 115 lines)
- `test/core/widgets/chip_bar_test.dart` (new, 47 lines)

Commit: `12cb247 feat(ui): add sliding-highlight ChipBar`
Pushed: `66415c5..12cb247  dev -> dev`

## Self-review findings
- Implementation and test match the brief verbatim; no deviations.
- `selectedIndex.clamp(0, labels.length - 1)` returns `int` (Dart's `int.clamp`
  override), so list indexing is type-safe; `flutter analyze` confirms.
- Test hygiene: the slide test relies on the same element tree (same widget
  structure/keys) being reused across `pumpWidget` calls so `AnimatedPositioned`
  animates rather than jumping — this is intentional and the test verifies
  `start < mid < end`.
- No dead code, no unused params, no commented-out code.
- `.superpowers/sdd/task-1-brief.md` shows as locally modified by the harness and
  was deliberately left out of the commit (brief step 6 lists only the two files).

## Issues or concerns
None. The widget is intentionally not wired into any page yet (Tasks 2/3).
