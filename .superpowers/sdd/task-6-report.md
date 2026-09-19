# Task 6 Report: Riverpod Providers

## What I implemented

Created the game module's Riverpod providers, mirroring `lib/modules/novel/novel_providers.dart`:

- `lib/modules/game/game_providers.dart`:
  - `gameSourceManagerProvider` — `Provider<GameSourceManager>` built with `GalgameZywzSource()`.
  - `gameSourcesProvider` — `Provider<List<GameSource>>` exposing the manager's sources.
  - `gameBrowseProvider` — `FutureProvider.family<GameList, (String, String, int)>`; resolves source by id, throws `StateError` when unknown, delegates to `browse(optionKey, page: page)`.
  - `gameDetailProvider` — `FutureProvider.family<GameDetail, (String, String)>`; resolves source by id, throws `StateError` when unknown, delegates to `detail(gameId)`.
- `test/modules/game/game_providers_test.dart` — test with a `_FakeSource` override verifying delegation for browse/detail and the unknown-source `StateError`.

Both files were written verbatim from the brief. No comments, no extra dependencies, no other files touched.

## What I tested and test results

Command: `C:\flutter\bin\flutter.bat test test/modules/game/game_providers_test.dart`

Result: `00:00 +3: All tests passed!` — 3 tests:
1. `gameBrowseProvider delegates to the registered source`
2. `gameDetailProvider delegates to the registered source`
3. `unknown source id throws`

Also ran `flutter analyze lib/modules/game/game_providers.dart test/modules/game/game_providers_test.dart` → `No issues found!`

## TDD Evidence

### RED

Command: `C:\flutter\bin\flutter.bat test test/modules/game/game_providers_test.dart`

Output (abridged):

```
test/modules/game/game_providers_test.dart:5:8: Error: Error when reading 'lib/modules/game/game_providers.dart': 系统找不到指定的文件
import 'package:acgnhub/modules/game/game_providers.dart';
       ^
test/modules/game/game_providers_test.dart:32:7: Error: Undefined name 'gameSourceManagerProvider'.
test/modules/game/game_providers_test.dart:41:30: Error: Method not found: 'gameBrowseProvider'.
test/modules/game/game_providers_test.dart:49:41: Error: Method not found: 'gameDetailProvider'.
...
00:00 +0 -1: Some tests failed.
```

Why expected: the implementation file `lib/modules/game/game_providers.dart` did not exist yet, so the test could not resolve the provider symbols — a genuine failing state driven by the missing production code.

### GREEN

Command: `C:\flutter\bin\flutter.bat test test/modules/game/game_providers_test.dart`

Output:

```
00:00 +0: loading D:/ACGNhub/test/modules/game/game_providers_test.dart
00:00 +0: gameBrowseProvider delegates to the registered source
00:00 +1: gameDetailProvider delegates to the registered source
00:00 +2: unknown source id throws
00:00 +3: All tests passed!
```

## Files changed

- Added: `lib/modules/game/game_providers.dart`
- Added: `test/modules/game/game_providers_test.dart`

Commit: `9f95e4e feat(game): add game Riverpod providers` (2 files changed, 91 insertions). Only these two files were staged; pre-existing modified `.superpowers/sdd/*` files were left untouched.

## Self-review findings

- Completeness: matches the brief exactly — same four providers, same signatures, code verbatim.
- Quality: follows `novel_providers.dart` conventions (manager provider → sources provider → family future providers with `StateError` on unknown id).
- Discipline: no overbuilding, no extra files, no added comments.
- Testing: tests verify delegation and error behavior; output pristine.

## Issues or concerns

None.
