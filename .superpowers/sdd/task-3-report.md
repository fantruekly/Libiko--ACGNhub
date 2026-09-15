# Task 3 Report: Comic page secondary bars → ChipBar; drop PillChip

## Status
DONE

## What I implemented
Wired `lib/modules/comic/comic_home.dart` (`_DiscoverTabState`) to `ChipBar`, following the brief's steps exactly:

1. **Import swap** — replaced `import '../../core/widgets/pill_chip.dart';` with `import '../../core/widgets/chip_bar.dart';`.
2. **Source selector** (`_sourceHeader`) — `_horizontalScroll` + `_sourceChip` Row → `ChipBar` keyed `ValueKey('comic-source-${names.join('|')}')`, `selectedIndex: sources.indexOf(selected)`, `onSelected` resets key/section/part/page.
3. **Deleted** `_chip` and `_sourceChip` helpers.
4. **Section selector** (`_sectionChips`) — built `labels` (title or `分区 N`), returns `ChipBar` keyed `comic-section-${source.key}-${labels.join('|')}`.
5. **Part selector** (`_partChips`) — built `labels`, returns `ChipBar` keyed `comic-part-${labels.join('|')}`.
6. **Deleted** `_horizontalScroll` and the now-unused `import 'package:flutter/gestures.dart';`.
7. **Deleted** `lib/core/widgets/pill_chip.dart`.

No other code touched. `chip_bar.dart` and the novel page untouched. No new dependencies; `pubspec.yaml` untouched. No code comments added.

## What I tested and results
- `flutter analyze lib test` → **No issues found! (ran in 2.6s)** — confirms no `unused_element` / `unused_import`.
- `flutter test` → **All tests passed!** (+268 passed, ~1 skipped; the skip is the pre-existing flutter_qjs native-library smoke test).
- `flutter build windows --debug` → **√ Built build\windows\x64\runner\Debug\acgnhub.exe** (only the pre-existing webview_windows CMake policy warning).

Manual UI verification (sliding highlight, row-switch jump) was not performed in this headless session; it is covered by the plan's final human verification step.

## Files changed
- Modified: `lib/modules/comic/comic_home.dart`
- Deleted: `lib/core/widgets/pill_chip.dart`

## Commit
- `4276055` feat(comic): sliding-highlight secondary chip bar; drop PillChip (pushed to `origin/dev`)

## Self-review findings
- `selectedIndex: sources.indexOf(selected)` is always valid: `selected` is derived from `sources` via `firstWhere`, and `ChipBar` clamps internally regardless.
- Key design matches Task 1: label-list changes remount (jump), `selectedIndex`-only changes animate.
- `PillChip` had no remaining references (grep confirmed only its own file and `comic_home.dart` before the change) and no test referenced it, so deletion is safe.
- The `chip_bar.dart` import now sits after `empty_state.dart`; `flutter analyze` is clean (no `directives_ordering` lint configured), and the brief specified replacing the import in place, so I left ordering as-is.

## Issues or concerns
- None blocking. Minor design note (inherited from the plan, not introduced here): if two sources/sections produce identical part labels, switching between them reuses the same `ChipBar` key and the pill animates to index 0 instead of jumping. The brief intentionally scopes "jump" to label-list changes only, so this is by design.
- `flutter build windows --debug` succeeded, but the sliding-highlight animation itself has not been visually confirmed in this session.

---

# Fix Report: include parent identity in third-row ChipBar keys

## Status
DONE

## What changed
The third-row (`_partChips` / `_optionChips`) `ChipBar` keys used only the label list, so two different parents (comic source+section, or novel source+group) with identical labels reused the same key and the widget animated instead of jumping. Added parent identity to both keys.

1. `lib/modules/comic/comic_home.dart` (`_DiscoverTabState`)
   - Call site: `_partChips(parts, part)` → `_partChips(selected, section, parts, part)`.
   - `_partChips` signature: `(List<ComicPart> parts, int selected)` → `(ComicSource source, int section, List<ComicPart> parts, int selected)`.
   - Key: `'comic-part-${labels.join('|')}'` → `'comic-part-${source.key}-$section-${labels.join('|')}'`.
2. `lib/modules/novel/novel_home.dart` (`_ExploreTabState`)
   - `_optionChips` key: `'novel-option-${labels.join('|')}'` → `'novel-option-$_sourceId-$_groupIndex-${labels.join('|')}'`.

Only the described parts of the two files were touched. No new dependencies; `pubspec.yaml` untouched. No code comments. Chinese UI copy unchanged.

## Verification
Command: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Result: `No issues found! (ran in 2.0s)`

Command: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Result: `00:12 +268 ~1: All tests passed!` (268 passed, 1 skipped — the pre-existing flutter_qjs native-library smoke test).

## Files changed
- Modified: `lib/modules/comic/comic_home.dart`
- Modified: `lib/modules/novel/novel_home.dart`

## Commit
- `062fa40` fix(ui): include parent identity in third-row ChipBar keys (pushed to `origin/dev`, 2 files changed, 5 insertions(+), 4 deletions(-))

## Issues or concerns
- None blocking.

---

# Fix Report: restore app font in ChipBar; own row identity internally

## Status
DONE

## What changed
1. `lib/core/widgets/chip_bar.dart` — replaced entirely.
   - `AnimatedDefaultTextStyle` now receives `base.merge(_style(...))` where `base = DefaultTextStyle.of(context).style`, so the inherited `NotoSansSC` font is preserved (the previous plain constructor replaced the ambient style and dropped the font).
   - `_widthOf` now takes the merged `TextStyle`, so measured widths match rendered text.
   - Added `curve: Curves.easeInOutCubic` to `AnimatedDefaultTextStyle` to match the pill's `AnimatedPositioned`.
   - Wrapped the `Stack` in `KeyedSubtree(key: ValueKey(Object.hashAll(labels)))`: a label-list change rebuilds the row (jump, no animation) while a `selectedIndex`-only change animates.
2. `lib/modules/comic/comic_home.dart` — removed caller keys now owned by `ChipBar`: `comic-source-*`, `comic-section-*`, `comic-part-*`. Reverted `_partChips` to `(List<ComicPart> parts, int selected)` and its call site to `_partChips(parts, part)` (the `source`/`section` params became unused).
3. `lib/modules/novel/novel_home.dart` — removed caller keys `novel-source-*`, `novel-section-*`, `novel-option-*`.
4. `test/core/widgets/chip_bar_test.dart` — appended the "changing the labels jumps instead of animating" test (4 tests total).

Only the four listed files were touched. No new dependencies; `pubspec.yaml` untouched. No code comments. Chinese UI copy unchanged. `grep` confirms no remaining `ValueKey('comic-` / `ValueKey('novel-` in the two home files, and no method retains an unused parameter.

## Verification
Command: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Result: `No issues found! (ran in 2.1s)`

Command: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/widgets/chip_bar_test.dart`
Result: `00:00 +4: All tests passed!` (4 focused tests green)

Command: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Result: `00:13 +269 ~1: All tests passed!` (269 passed, 1 skipped — the pre-existing flutter_qjs native-library smoke test)

## Files changed
- Modified: `lib/core/widgets/chip_bar.dart`
- Modified: `lib/modules/comic/comic_home.dart`
- Modified: `lib/modules/novel/novel_home.dart`
- Modified: `test/core/widgets/chip_bar_test.dart`

## Commit
- `5f78a59` fix(ui): restore app font in ChipBar; own row identity internally (pushed to `origin/dev`, 4 files changed, 71 insertions(+), 50 deletions(-))

## Issues or concerns
- None blocking.
