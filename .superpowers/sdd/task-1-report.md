# Task 1 Report: 侧栏文字与线条动效

## What I implemented
- Unified the sidebar label style in `lib/shell/app_sidebar.dart` `_SidebarItem`:
  - `fontSize: 13`, `height: 1.4`, `FontWeight.w600` (selected) / `FontWeight.w500` (unselected), no `letterSpacing`, no `fontFamily`.
  - Used a plain `Text(style: TextStyle(color: ...))` so the color merges with the ambient `DefaultTextStyle` (per the brief, deliberately NOT `AnimatedDefaultTextStyle`, which would drop the app font).
- Replaced the static `Border(left: 3px accent)` selected indicator with an animated line:
  - `TweenAnimationBuilder<double>` (0↔1, 200ms, `Curves.easeInOutCubic`).
  - `Positioned(left: 0, top: 0, bottom: 0)` + `Opacity(key: ValueKey('sidebar-line'), opacity: t)` + `Transform.scale(scaleY: t, alignment: Alignment.center)` wrapping a `Container(width: 3, color: Color(0xFF007AFF))`.
  - The same `t` lerps icon and text colors between the idle greys (`0.35` / `0.45` alpha) and the accent blue via `Color.lerp`.
- Added `test/shell/app_sidebar_test.dart` with the exact test from the brief.

## What I tested and results
- Focused: `flutter test test/shell/app_sidebar_test.dart` → `+1: All tests passed!`
- Full: `flutter test` → `+273 ~1: All tests passed!` (1 pre-existing skip: `js_engine_smoke_test.dart`, native lib not loadable under `flutter test`).
- Static: `flutter analyze lib test` → `No issues found! (ran in 2.0s)`.

## TDD evidence
### RED
Command: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/shell/app_sidebar_test.dart`
Output (excerpt):
```
Expected: <13>
  Actual: <11.0>
...
The test description was:
  sidebar labels are 13px and the selected line animates
00:00 +0 -1: Some tests failed.
```
Why expected: the old implementation used `fontSize: 11` and had no `Opacity` keyed `sidebar-line`; the test asserts 13px first, so it fails on that assertion (and would also fail the `lineOpacity()` list, which returned `[]` instead of five entries).

### GREEN
Command: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/shell/app_sidebar_test.dart`
Output:
```
00:00 +1: All tests passed!
```

## Files changed
- `lib/shell/app_sidebar.dart` (modified)
- `test/shell/app_sidebar_test.dart` (new)
- Commit `0d0c529` — `feat(shell): unify sidebar label size; animate the selected line`
- Pushed to `origin/dev` (`c6a1079..0d0c529`).

## Self-review findings
- Implementation is byte-for-byte the brief's "after" code; the only additions are the test file and no comments (consistent with existing style).
- `TweenAnimationBuilder`'s `begin`/`end` are both set to the target each build; `begin` only matters on first mount, and the element's state animates from its current value to the new `end` on rebuild — this is what drives the 0↔1 transition. Matches the brief.
- YAGNI: no extra widgets/params/dependencies; `pubspec.yaml` untouched.
- Test hygiene: single focused widget test, `pumpAndSettle` before assertions, exact expected opacity vectors for the initial and post-tap selection.

## Issues or concerns
- None. The `test/shell/` directory was newly created (did not previously exist).
