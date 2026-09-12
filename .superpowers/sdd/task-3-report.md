# Task 3 Report: `RuleVideoSource`

## What I implemented

- `lib/core/video/rule_source.dart`: `RuleVideoSource implements VideoSource`, backed by a
  Kazumi-compatible `SourceRule`.
  - Constructor `RuleVideoSource(SourceRule rule, {WebviewScraper? scraper})` (defaults to a
    fresh `WebviewScraper`).
  - Interface members: `id` (`rule.id`), `name`, `baseUrl`, `search`, `episodes`.
  - `search` builds the keyword URL via `rule.buildSearchUrl`, scrapes with
    `buildSearchScript(rule)`, and maps via `mapSearch`.
  - `episodes` scrapes the detail URL with `buildEpisodesScript(rule)` and maps via
    `mapEpisodes`.
  - `@visibleForTesting static` pure helpers: `mapSearch`, `mapEpisodes`, `resolveUrl`.
- `test/core/video/rule_source_test.dart`: the four brief-specified tests.

Implementation and tests are verbatim from the brief.

## What I tested and results

- Focused: `flutter test test/core/video/rule_source_test.dart` → 4/4 pass.
- Static analysis: `flutter analyze lib test` → "No issues found!".
- Full suite: `flutter test` → 63 tests pass.

Covered behavior:
- `mapSearch` resolves relative/absolute hrefs, filters rows with empty name or href.
- `mapEpisodes` assigns 0-based indexes and generates fallback titles (`第N集`), resolves
  protocol-relative URLs.
- Non-list inputs (`null`, `String`) return empty.
- `resolveUrl` upgrades `http://` → `https://` and normalizes trailing/leading slashes.

## TDD evidence

### RED

Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/video/rule_source_test.dart
```

Output (abridged):
```
Failed to load ".../rule_source_test.dart":
Compilation failed for testPath=.../rule_source_test.dart:
test/core/video/rule_source_test.dart:2:8: Error: Error when reading
  'lib/core/video/rule_source.dart': 系统找不到指定的文件。
...
test/core/video/rule_source_test.dart:18:19: Error: Undefined name 'RuleVideoSource'.
...
00:00 +0 -1: Some tests failed.
```

Why expected: the test imports `lib/core/video/rule_source.dart`, which did not exist yet, so
compilation failed with "file not found" and undefined `RuleVideoSource`. This is the intended
first-failure state before implementation.

### GREEN

Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/video/rule_source_test.dart
```

Output:
```
00:00 +0: mapSearch resolves relative hrefs and drops empty rows
00:00 +1: mapEpisodes assigns 0-based indexes and fallback titles
00:00 +2: mapSearch returns empty for non-list input
00:00 +3: resolveUrl upgrades http and normalizes slashes
00:00 +4: All tests passed!
```

## Files changed

- `lib/core/video/rule_source.dart` (new)
- `test/core/video/rule_source_test.dart` (new)

Commit: `50e8cf4 feat(video): add RuleVideoSource with pure search/episode mapping`

## Self-review findings

- Completeness: all four `VideoSource` members implemented; all three required static helpers
  present with `@visibleForTesting`; constructor signature matches the Task 4 contract.
- Quality: matches repo conventions (2-space indent, trailing commas, relative imports), no
  extra comments beyond the brief, analyzer clean.
- YAGNI: no speculative fields or methods added.
- Tests verify real behavior: mapping/filtering/indexing/URL normalization are exercised with
  concrete assertions; the WebView path is intentionally not unit-tested (per brief, it is
  integration-tested elsewhere). Static helpers are pure and do not touch the scraper.
- Script/mapper contract check: `buildSearchScript` emits `{name, href}` and `mapSearch` reads
  `name`/`href`; `buildEpisodesScript` emits `{title, href}` and `mapEpisodes` reads
  `title`/`href`. Consistent.

## Concerns

- `resolveUrl` unconditionally rewrites `http://` to `https://`. This is the brief-specified
  behavior, but a source that only serves plain HTTP would fail. Out of scope for this task;
  flagging in case Task 4/5 needs a fallback.
- `mapSearch`/`mapEpisodes` assume list-of-map rows; non-map rows are skipped safely. No
  cover parsing is done because the scraper scripts do not emit a cover field (matches brief).
