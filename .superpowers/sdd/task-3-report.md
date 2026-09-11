# Task 3 Report: Remove the source label from cards

## Status: DONE

## What changed
Modified `lib/core/widgets/work_card.dart`:
- Removed the `final String? subtitle;` field.
- Removed `this.subtitle` from the constructor; signature is now `WorkCard({super.key, required this.work, this.onTap})`.
- Removed the `final sub = subtitle ?? work.sourceName;` local.
- Removed the conditional `if (sub.isNotEmpty) Text(sub, ...)` widget.
- Kept the `const SizedBox(height: 6)` spacer between the cover and the title (not orphaned — it separates cover from title).
- `Column.children` now ends with the title `Text` (2-line clamp) only.

## Verification
`$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib/core/widgets/work_card.dart`

Result: `No issues found! (ran in 1.4s)`

Also grepped `lib/` for `subtitle`; remaining matches are unrelated:
- `lib/shell/main_shell.dart` (local parameter of an unrelated helper)
- `lib/shell/settings_page.dart` (`ListTile.subtitle`)

## Files changed
- `lib/core/widgets/work_card.dart` (1 insertion, 14 deletions)

## Commit
- `90208e2` style(anime): drop the source label from work cards

## Concerns
- None. `WorkCard` callers (`anime_home.dart`, `anime_search.dart`) do not pass `subtitle`, so no call sites needed updating.
- Unrelated pre-existing working-tree changes (`.superpowers/sdd/*`, `tool/gen_seed.ps1`, untracked docs) were left untouched; only `work_card.dart` was staged, per the brief.
