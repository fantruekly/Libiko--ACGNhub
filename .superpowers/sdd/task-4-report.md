# Task 4 Report: `RuleStore`, source registry, and the bundled 7sefun rule

## Status
DONE

## What I implemented
Followed the brief's TDD order exactly, code verbatim.

1. `test/core/video/rule_store_test.dart` — two tests: `mergeRules` dedupe
   (imported wins) and the bundled 7sefun JSON parsing from disk.
2. `assets/source_rules/7sefun.json` — the bundled Kazumi-compatible 七色番 rule.
3. `pubspec.yaml` — added `- assets/source_rules/` under `flutter: assets:`
   (kept `assets/rules/` and `assets/anime_seed.json`).
4. `lib/core/video/rule_store.dart` — `RuleStore` with `loadAll()`,
   `loadBuiltIn()` (reads `AssetManifest.json`, filters `assets/source_rules/*.json`),
   `loadImported()` (reads `<app support dir>/rules/`), `importJson(rawJson)`
   (parses then persists, throws `FormatException` via `SourceRule` on invalid input),
   `_safeName`, and `@visibleForTesting static mergeRules` (imported wins by name).
   Plus `ruleStoreProvider`.
5. `lib/core/video/video_sources.dart` — `buildSources(rules)` (AgedmSource,
   GimySource, then one `RuleVideoSource` per rule) and `videoSourcesProvider`
   (`FutureProvider` awaiting `loadAll()`).

## What I tested and results
- Focused: `flutter test test/core/video/rule_store_test.dart` → `+2: All tests passed!`
- Analyze: `flutter analyze lib test` → `No issues found! (ran in 2.4s)`
- Full suite: `flutter test` → `+65: All tests passed!`

Per the brief, `loadBuiltIn`/`loadImported`/`importJson` asset+disk paths are not
unit-tested (integration-tested manually); only `mergeRules` and the bundled
JSON parse are unit-tested.

## TDD evidence

### RED
Command: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/video/rule_store_test.dart`

Output (excerpt):
```
test/core/video/rule_store_test.dart:4:8: Error: Error when reading 'lib/core/video/rule_store.dart': 系统找不到指定的文件。
import 'package:acgnhub/core/video/rule_store.dart';
test/core/video/rule_store_test.dart:20:20: Error: Undefined name 'RuleStore'.
    final merged = RuleStore.mergeRules(
00:00 +0 -1: ... Failed to load ... Compilation failed
```
Why expected: the test imports `rule_store.dart` and references `RuleStore`,
neither of which existed yet — a compile failure for the missing feature, not a typo.

### GREEN
Command: same as above, after creating the JSON, pubspec entry, and both lib files.

Output (excerpt):
```
00:00 +0: mergeRules dedupes by name and imported wins
00:00 +1: bundled 7sefun rule parses from disk
00:00 +2: All tests passed!
```

## Files changed
- `assets/source_rules/7sefun.json` (new)
- `lib/core/video/rule_store.dart` (new)
- `lib/core/video/video_sources.dart` (new)
- `test/core/video/rule_store_test.dart` (new)
- `pubspec.yaml` (modified: added asset dir)

## Commit
- `de5a29f` feat(video): add rule store, source registry, and bundled 7sefun rule

## Self-review findings
- Completeness: all brief files and interfaces present; `loadAll`, `loadBuiltIn`,
  `loadImported`, `importJson`, `mergeRules`, `ruleStoreProvider`,
  `buildSources`, `videoSourcesProvider` all match the specified signatures.
- Quality/YAGNI: no extra code beyond the brief; 2-space indentation; no comments
  beyond the brief's doc comments.
- Real behavior: `mergeRules` is exercised with real `SourceRule` objects; the
  bundled rule test parses the real asset file, so a broken JSON or missing
  required field would fail.

## Concerns
- **Weak "imported wins" assertion:** the test's two `b` rules are built by the
  same helper, so their `baseUrl` is identical (`https://b.test/`). The assertion
  `merged.firstWhere(name=='b').baseUrl == 'https://b.test/'` passes whether the
  built-in or the imported copy won, so the test does not actually distinguish the
  two. The dedupe-by-name set assertion is valid; the precedence claim is not truly
  verified. This is the brief's verbatim test — I did not modify it. A stronger test
  would give the imported `b` a distinct field value.
- `loadBuiltIn()` depends on `AssetManifest.json` at runtime, which is not covered
  by any unit test here (per the brief); it is only exercised when the app runs.

## Fix report

### What changed
Edited only `test/core/video/rule_store_test.dart`:
- Added `_ruleWith(String name, String baseUrl)`, which builds a `SourceRule` with
  an explicit `baseUrl`; the existing `_rule(name)` helper was left unchanged.
- Updated the `mergeRules dedupes by name and imported wins` test so the imported
  `b` is built with `_ruleWith('b', 'https://b-imported.test/')` and the assertion
  checks `baseUrl == 'https://b-imported.test/'`. The built-in `b` still has
  `https://b.test/`, so the assertion now distinguishes the two copies and can
  fail if precedence is wrong. No other test and no file under `lib/` was touched.

### Commands run and output
1. `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/video/rule_store_test.dart`
   ```
   00:00 +0: mergeRules dedupes by name and imported wins
   00:00 +1: bundled 7sefun rule parses from disk
   00:00 +2: All tests passed!
   ```
2. `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
   ```
   Analyzing 2 items...
   No issues found! (ran in 1.4s)
   ```
3. `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
   ```
   00:06 +65: All tests passed!
   ```

### Reversed-precedence observation
Temporarily swapped the two list arguments (imported list first, built-in list
second) and re-ran the focused test. It failed as required, proving the assertion
now genuinely detects precedence:

```
00:00 +0: mergeRules dedupes by name and imported wins
00:00 +0 -1: mergeRules dedupes by name and imported wins [E]
  Expected: 'https://b-imported.test/'
    Actual: 'https://b.test/'
00:00 +1 -1: Some tests failed.
```

The swap was then reverted, and the focused test passed again (`+2: All tests
passed!`).
