# Task 1 Report: `BangumiProvider`

## Status
DONE_WITH_CONCERNS (minor: one import path in the brief was incorrect and had to be fixed)

## What I implemented
Created `lib/core/metadata/bangumi_provider.dart` implementing the existing
`MetadataProvider` interface (`id`, `feed`, `search`, `detail`) plus the static
test seams `parseCalendar`, `parseSearch`, and `parseDetail`. Also created the
test `test/core/metadata/bangumi_provider_test.dart` verbatim from the brief.

Implementation is the brief's code verbatim with a single necessary correction:
the brief's import `import '../../models/work.dart';` resolves to
`lib/models/work.dart` (nonexistent). The correct path from
`lib/core/metadata/` is `../models/work.dart`, matching
`lib/core/metadata/metadata_provider.dart`. Changed only that line.

## TDD evidence

### RED
Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/metadata/bangumi_provider_test.dart
```
Output (failing):
```
Error: Error when reading 'lib/core/metadata/bangumi_provider.dart': 系统找不到指定的文件。
import 'package:acgnhub/core/metadata/bangumi_provider.dart';
Error: Undefined name 'BangumiProvider'.
00:00 +0 -1: Some tests failed.
```

### GREEN
Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/metadata/bangumi_provider_test.dart
```
Output (passing):
```
00:00 +0: parseCalendar maps items to Work with the Chinese name and https cover
00:00 +1: parseCalendar onlyWeekday filters days
00:00 +2: parseSearch reads data.list
00:00 +3: parseDetail reads tags and falls back to name when name_cn is empty
00:00 +4: All tests passed!
```

### Analyzer
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib/core/metadata/bangumi_provider.dart test/core/metadata/bangumi_provider_test.dart
No issues found! (ran in 1.7s)
```

## Files changed
- `lib/core/metadata/bangumi_provider.dart` (new)
- `test/core/metadata/bangumi_provider_test.dart` (new)

## Commit
- `ac9f022` feat(metadata): add BangumiProvider

## Self-review findings
- Implementation matches the brief exactly except the corrected relative import.
- `parseCalendar` de-duplicates by `bangumiId` and honors `onlyWeekday`; verified by tests.
- `parseDetail` extracts tags only in detail mode (`tags` empty for feed/search), as specified.
- Cover URLs are upgraded from `http://` to `https://`; verified by test.
- `feed(AnimeFeed.today)` filters by `DateTime.now().weekday`; `trending` sorts by score desc;
  `season` returns the full calendar. Matches brief.
- `detail` requires `extra['bangumiId']` and throws `StateError` otherwise.
- Only the two task files were staged; unrelated working-tree changes were left untouched.

## Concerns
1. The brief's import path was wrong; fixed to `../models/work.dart`. The delivered code
   therefore differs from the brief by that one line. All tests/analyzer pass.
2. `search` uses Bangumi's legacy endpoint `GET /search/subject/{keyword}?type=2&responseGroup=small`.
   Bangumi has largely moved to `POST /v0/search/subjects`; the legacy endpoint may be
   deprecated/unreliable. Out of scope for this task (brief specified the legacy call), but
   worth flagging for a follow-up if search returns empty in practice.
3. `parseCalendar` casts `w.extra['bangumiId'] as int` unconditionally in the `seen.add`
   expression; items without an `id` are filtered by `_parseItem` returning null, so this is
   safe, but a malformed non-int `id` would throw. Bangumi always returns int ids.
4. `feed(season)` returns the whole weekly calendar rather than a true seasonal filter; this is
   the brief's intended behavior for now.
