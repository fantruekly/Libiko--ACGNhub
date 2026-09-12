# Task 6 Report: Import-rule button

## Status: DONE

## What was implemented
Added the ability to import a Kazumi rule JSON from the detail page's 播放资源 header.

1. Added the `file_selector` dependency via `flutter pub add file_selector` (resolved to `file_selector 1.1.0` with `file_selector_windows 0.9.3+5`). No version was hardcoded.
2. Added imports to `lib/modules/anime/anime_detail_page.dart`:
   - `package:file_selector/file_selector.dart`
   - `../../core/video/rule_store.dart`
3. Added `_importRule()` to `_AnimeDetailPageState` verbatim from the brief: opens an `openFile` picker restricted to `XTypeGroup(label: 'Kazumi 规则', extensions: ['json'])`, returns early on cancel, calls `ref.read(ruleStoreProvider).importJson(await file.readAsString())`, invalidates `videoSourcesProvider`, shows a success snackbar, and re-runs `_searchAllSources()`. `FormatException` is caught and surfaced as a `规则无效：…` snackbar.
4. Inserted the import `IconButton` (`tooltip: '导入规则'`, `Icons.file_download_outlined`, `iconSize: 18`, `visualDensity: VisualDensity.compact`) immediately before the existing refresh `IconButton` in the `_playSection` header `Row`.

## What was verified and results
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib
Analyzing lib...
No issues found! (ran in 2.0s)
```
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug
...
√ Built build\windows\x64\runner\Debug\acgnhub.exe
```
(The build emitted only the pre-existing CMake dev warning for `webview_windows`; unrelated to this change.)

## Files changed
- `pubspec.yaml` (added `file_selector`)
- `pubspec.lock` (new transitive deps)
- `lib/modules/anime/anime_detail_page.dart` (imports, `_importRule`, header button)

## Commit
- `c58d72c` feat(anime): import Kazumi rule JSON from the resource section

Only the three files named in the brief were staged; other pre-existing working-tree changes (`.superpowers/sdd/*`, untracked `docs/superpowers/*`) were left untouched.

## Self-review findings
- Code matches the brief verbatim, including the `e.message` use on `FormatException` and the `mounted` guards.
- Interfaces confirmed present: `ruleStoreProvider` and `RuleStore.importJson` (`lib/core/video/rule_store.dart:64,89`), `videoSourcesProvider` (`lib/core/video/video_sources.dart:17`).
- Button style matches the surrounding refresh button exactly (`iconSize: 18`, `visualDensity: VisualDensity.compact`).
- YAGNI: no extra abstraction, no new tests (per brief), no comments added.

## Concerns
- `openFile`/`file_selector` has no Windows integration test here; the picker itself is manual-tested in Task 7. The import persistence path (`RuleStore.importJson`) was already covered by Task 4.
