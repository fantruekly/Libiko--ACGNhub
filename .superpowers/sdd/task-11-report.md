# Task 11 Report: 探索页卡片去掉作者（统一封面高度）

## What I implemented
- Removed the author `Text` line from `NovelCard` in `lib/modules/novel/novel_home.dart`. The card now renders only the cover and the title (fixed 38px title box), so all cards have identical heights and therefore uniform cover sizes across the explore/home grid.
- Updated `test/modules/novel/novel_card_test.dart`: the first widget test previously asserted both the title (`安达与岛村`) and the author (`入间人间`). It now asserts the title is present and the author is absent (`findsNothing`). Test name changed to `NovelCard shows title but not author`.

## What I tested and results
- `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found! (ran in 2.1s)`
- `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → `+211 ~1: All tests passed!` (1 pre-existing skipped qjs smoke test, unrelated).

## Files changed
- `lib/modules/novel/novel_home.dart` (-7 lines: author block removed)
- `test/modules/novel/novel_card_test.dart` (assertion adapted)

## Self-review findings
- `_muted` color constant is still used by `_chip` and `_pager`, so no unused-symbol warning after removing the author text. Analyzer confirms clean.
- The card's `Column` now has exactly cover + 6px gap + fixed-height title, matching the intended uniform layout.
- No new dependencies added; no `fontFamily` introduced.
- Only the two files named in the brief were staged/committed; the many other pre-existing working-tree modifications (line-ending churn in `.superpowers/` and `docs/`) were left untouched.

## Concerns
- None functional. The other dirty files in the working tree are unrelated and were deliberately not staged.
