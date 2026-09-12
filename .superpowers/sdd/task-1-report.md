# Task 1 Report: `SourceRule` model

## What I implemented
Created `lib/core/video/source_rule.dart`, a Kazumi-compatible JSON rule model:
- `class SourceRule` with `name`, `baseUrl`, `searchUrl`, `searchList`, `searchName`, `searchResult`, `chapterRoads`, `chapterResult` (all `String`) and `userAgent` (`String?`).
- `const` constructor with required named parameters.
- `String get id => 'rule:$name'`.
- `factory SourceRule.fromJson(Map<String, dynamic>)` — validates required fields via a local `req` helper that throws `FormatException` for missing/non-string/blank values; maps blank `userAgent` to `null`; trims string values.
- `factory SourceRule.fromJsonString(String)` — decodes JSON and throws `FormatException` if the decoded value is not a JSON object.
- `String buildSearchUrl(String keyword)` — replaces `@keyword` with `Uri.encodeComponent(keyword)`.

Unknown JSON keys (`api`, `type`, `version`, `muliSources`, `useWebview`, `useNativePlayer`) are ignored, matching Kazumi plugin files.

## What I tested and results
Created `test/core/video/source_rule_test.dart` with the 4 brief-specified tests:
1. `fromJsonString parses a Kazumi plugin and ignores unknown keys` — verifies name, baseUrl, searchList, chapterResult, `userAgent == null` (empty string → null), and `id == 'rule:七色番'`.
2. `buildSearchUrl substitutes and URL-encodes @keyword` — verifies UTF-8 percent-encoding of `进击的巨人`.
3. `fromJson throws FormatException on a missing required field`.
4. `fromJsonString throws FormatException on a non-object` (`[1,2,3]`).

Results:
- Focused test: `flutter test test/core/video/source_rule_test.dart` → `00:00 +4: All tests passed!`
- Full suite: `flutter test` → `00:06 +53: All tests passed!`
- Static analysis: `flutter analyze lib test` → `No issues found! (ran in 3.3s)`

## TDD evidence
### RED
Command: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/video/source_rule_test.dart`

Output (excerpt):
```
test/core/video/source_rule_test.dart:2:8: Error: Error when reading 'lib/core/video/source_rule.dart': 系统找不到指定的文件。
test/core/video/source_rule_test.dart:25:18: Error: Undefined name 'SourceRule'.
...
00:00 +0 -1: loading D:/ACGNhub/test/core/video/source_rule_test.dart [E]
  Failed to load ... Compilation failed ...
00:00 +0 -1: Some tests failed.
```
Why expected: the test imports `package:acgnhub/core/video/source_rule.dart`, which did not exist yet, so compilation failed before any test could run. This confirms the test actually exercises the not-yet-written model.

### GREEN
Command: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/video/source_rule_test.dart`

Output:
```
00:00 +0: fromJsonString parses a Kazumi plugin and ignores unknown keys
00:00 +1: buildSearchUrl substitutes and URL-encodes @keyword
00:00 +2: fromJson throws FormatException on a missing required field
00:00 +3: fromJsonString throws FormatException on a non-object
00:00 +4: All tests passed!
```

## Files changed
- `lib/core/video/source_rule.dart` (new)
- `test/core/video/source_rule_test.dart` (new)

Commit: `523346b feat(video): add Kazumi-compatible SourceRule model` (2 files changed, 116 insertions)

## Self-review findings
- Completeness: All interface items from the brief are present (fields, `id`, both factories, `buildSearchUrl`).
- Quality: Implementation matches the brief verbatim and follows existing 2-space, no-comment style; imports use `package:acgnhub/...`.
- YAGNI: No serialization, no extra methods, no speculative fields — only what the interface specifies.
- Tests verify real behavior: They assert parsed values, UTF-8 encoding, and both error paths; the RED phase proved the tests genuinely depend on the new code.
- `git add` was scoped to only the two task files; unrelated `.superpowers/sdd` modifications were left unstaged.

## Concerns
None. The model is self-contained; later tasks (WebView scraper, `RuleVideoSource`, rule store, detail UI) can consume it as specified.
