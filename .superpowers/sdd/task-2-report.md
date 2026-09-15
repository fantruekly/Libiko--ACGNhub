# Task 2 Report: 板块切换交叉淡入淡出 (cross-fade module switching)

## What I implemented

Replaced the instant `IndexedStack` module switcher in `lib/shell/main_shell.dart`
with a `Stack(fit: StackFit.expand)` where every page is wrapped in
`IgnorePointer(ignoring: i != _currentIndex)` + `AnimatedOpacity(key: ValueKey('module-page-$i'), opacity: i == _currentIndex ? 1.0 : 0.0, duration: 250ms, curve: Curves.easeInOut)`.

All four pages remain in the widget tree at all times (mounted), so scroll
positions and tab state are preserved across switches; only opacity changes and
hidden pages ignore pointer events. This matches the brief's Step 3 snippet
verbatim.

Added `test/shell/main_shell_test.dart` per the brief's Step 1.

## Files changed

- `lib/shell/main_shell.dart` — `IndexedStack` → `Stack` + per-page `IgnorePointer`/`AnimatedOpacity`.
- `test/shell/main_shell_test.dart` — new widget test.

## TDD evidence

### RED

Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/shell/main_shell_test.dart
```
Output (before implementation, with the brief's test):
```
00:00 +0: switching modules cross-fades while keeping every page mounted
The following StateError was thrown running a test:
Bad state: No element
#1  WidgetController.widget (package:flutter_test/src/controller.dart:804:30)
#2  main.<anonymous closure>.pageOpacity (file:///D:/ACGNhub/test/shell/main_shell_test.dart:20:18)
...
00:00 +0 -1: Some tests failed.
```
Expected failure: the old `IndexedStack` renders no widgets keyed
`ValueKey('module-page-$i')`, so `find.byKey(...)` found nothing and
`tester.widget<AnimatedOpacity>` threw `Bad state: No element`. This is exactly
the failure the brief predicted in Step 2.

### GREEN

After implementing, the opacity assertions passed but the test failed on a
**pre-existing** issue unrelated to this change:

```
Pending timers:
Timer (duration: 0:00:00.000000, periodic: false), created:
#7  DioMixin.fetch (package:dio/src/dio_mixin.dart:529:30)
#10 BangumiProvider.feed (package:acgnhub/core/metadata/bangumi_provider.dart:55:28)
...
#11 LinovelibSource.home (package:acgnhub/core/novel/linovelib_source.dart:453:24)
...
A Timer is still pending even after the widget tree was disposed.
```

Root cause: `MainShell` mounts all four pages, and `AnimeHomePage` /
`NovelHomePage` kick off zero-duration dio requests on build. `tester.pump()`
(no duration) never advances the fake clock, so those timers stay pending when
the tree is disposed. The existing `test/widget_test.dart` mounts the same
`MainShell` and only passes because it pumps with a duration
(`await tester.pump(const Duration(milliseconds: 100));`).

**Deviation from the brief (1 line):** the brief's test used a bare
`await tester.pump();`. I changed it to
`await tester.pump(const Duration(milliseconds: 100));` to drain those
pre-existing timers. This is a test-hygiene fix only; it does not change what
the test asserts (the `AnimatedOpacity.opacity` target values for all four
pages). I did not change any production code to accommodate it, because the
timers are unrelated to the `IndexedStack` → `Stack` swap.

GREEN command and output:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/shell/main_shell_test.dart
00:00 +0: switching modules cross-fades while keeping every page mounted
00:00 +1: All tests passed!
```

### Static analysis

```
$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test
No issues found! (ran in 2.0s)
```

### Full suite

```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test
00:10 +274 ~1: All tests passed!
```

(274 passed, 1 skipped, 0 failed.)

## Commit

- `b9f79f8` feat(shell): cross-fade module switching
- Pushed to `origin/dev` (`0d0c529..b9f79f8  dev -> dev`).

## Self-review findings

- Production change is byte-for-byte the brief's Step 3 snippet; no comments,
  no new dependencies, no `pubspec.yaml` change.
- Every page is still built and mounted (`_pages` list is iterated
  unconditionally), so the scroll/tab-preservation requirement holds.
- `IgnorePointer` correctly blocks interaction with the faded-out pages; the
  active page remains interactive.
- `Stack(fit: StackFit.expand)` gives all pages the full content area, matching
  `IndexedStack` sizing behavior.
- Test hygiene: only the two allowed files were modified. The single-line pump
  change is the only deviation and is justified above.
- YAGNI: no `TickerMode`, no slide/scale transitions, nothing beyond the brief.

## Issues / concerns

1. **Test deviation (minor, documented):** one line of the brief's test was
   adjusted (pump duration) so the suite is green. The underlying pending-timer
   issue is pre-existing and affects any test that mounts `MainShell` without
   advancing the clock. A future improvement could be overriding
   `metadataServiceProvider` / novel providers in the shell test, but that is
   out of scope for this task.
2. `flutter build windows --debug` (listed in the plan's post-task verification
   section, not in this task's steps) was not run to keep the task scoped; the
   change is a pure widget-tree swap and `flutter analyze` + full tests are green.

---

# Task 2 Test-Strength Fix Report (follow-up review)

## What changed

The final review found the two new tests only asserted end/target state, so they
would still pass if the animations were removed. Both test files now assert
mid-flight animation values and the animation configuration.

### `test/shell/app_sidebar_test.dart`

Replaced the `fontSize`-only style check with full selected/idle `TextStyle`
assertions (`fontSize: 13`, selected `FontWeight.w600`, `height: 1.4`, null
`letterSpacing`/`fontFamily`, idle `FontWeight.w500`). The tap on `漫画` now pumps
a bare frame plus 100 ms (mid-flight of the line fade) and asserts the outgoing
line opacity is strictly between 0 and 1 and the incoming line opacity is
strictly between 0 and 1, then `pumpAndSettle()` and asserts the final target.

### `test/shell/main_shell_test.dart`

Added `import 'package:acgnhub/shell/app_sidebar.dart';` and scoped the module
tap to `find.byType(AppSidebar)`. Renamed `pageOpacity` to `targetOpacity` and
added `renderedOpacity(i)`, which reads the live value of the `FadeTransition`
built inside each `AnimatedOpacity` (via `find.descendant(...).first`). The test
now asserts every `AnimatedOpacity` has `duration == 250ms` and
`curve == Curves.easeInOut`, then taps `漫画`, pumps to the halfway point, and
asserts the rendered opacity of the outgoing page is strictly between 0 and 1 and
the incoming page is strictly between 0 and 1, then asserts the final targets.

### Deviation (documented, test-only)

The instructed `await tester.pumpAndSettle()` at the end of the `MainShell` test
does **not** work in this codebase: `AnimeHomePage`/`ComicHomePage`/
`NovelHomePage` render `ShimmerLoader` while their providers load, and
`ShimmerLoader` (`lib/core/widgets/shimmer_loader.dart:30`) runs an
`AnimationController..repeat()` that never settles, so `pumpAndSettle` times out.
I replaced it with a bounded `await tester.pump(const Duration(milliseconds: 300))`
and additionally asserted the *rendered* opacities reach `0.0` and `1.0` after the
250 ms animation completes. This is test-only, keeps (and slightly strengthens)
the end-state assertion, and required no production change. No other production
code was touched and no dependencies were added.

## Verification (exact commands + results)

```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/shell/app_sidebar_test.dart test/shell/main_shell_test.dart
00:00 +0: loading D:/ACGNhub/test/shell/app_sidebar_test.dart
00:00 +0: ... sidebar labels are 13px and the selected line animates
00:00 +1: ... switching modules cross-fades while keeping every page mounted
00:00 +2: All tests passed!
```

```
$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test
Analyzing 2 items...
No issues found! (ran in 1.7s)
```

```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test
00:10 +274 ~1: All tests passed!
```

(274 passed, 1 pre-existing skip, 0 failed.)

## Files changed

- `test/shell/app_sidebar_test.dart`
- `test/shell/main_shell_test.dart`

## Commit

- `a1ece38` test(shell): assert mid-flight animation values
- Pushed to `origin/dev` (`b9f79f8..a1ece38  dev -> dev`).
