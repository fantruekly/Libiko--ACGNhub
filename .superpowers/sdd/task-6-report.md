# Task 6 Report: 追番 button + 追番 tab

## What I implemented

- **`lib/modules/anime/anime_detail_page.dart`**
  - Added imports `../../core/account/sync_service.dart` and `../../core/services/follow_manager.dart`.
  - In `_header`, inserted the brief's `Consumer` follow button immediately before `const WindowControls(),` (inside the `DragToMoveArea`/`Row`, so it stays clickable). It watches `followProvider` for `r.work.id == w.id`, shows `favorite_rounded`/`favorite_border_rounded` (blue/grey), and on press calls `followProvider.notifier.toggle(w)` then `syncProvider.schedule()`.
- **`lib/modules/anime/anime_follow.dart` (new)** — `class AnimeFollowView extends ConsumerWidget`, created verbatim from the brief. Watches `followProvider`; renders `EmptyState(icon: Icons.favorite_border_rounded, message: '还没有追番')` when empty, else a `GridView.builder` (`crossAxisCount: 5`, spacing 16, `childAspectRatio: 0.66`) of `WorkCard`s (no subtitle, no clear button) that push `AnimeDetailPage` via `smoothRoute`.
- **`lib/modules/anime/anime_home.dart`** — added `import 'anime_follow.dart';`, changed `DefaultTabController(length: 4)` to `length: 5`, appended `Tab(text: '追番')` after 历史记录, and appended `_heroTab(controller, 4, const AnimeFollowView()),` to the `TabBarView` children.
- **`test/modules/anime/anime_detail_page_test.dart`** — necessary test adaptation (see Deviations): imported `AppDatabase` and changed `setUp` to `await AppDatabase.init()`.

## What I verified and results

- `flutter analyze lib test` → **`No issues found!`** (ran in 1.7s)
- `flutter test` → **`All tests passed!`** (108 tests)
- `flutter build windows --debug` → **`√ Built build\windows\x64\runner\Debug\acgnhub.exe`** (13.7s; only the pre-existing `webview_windows` CMake CMP0175 dev warning)

## Files changed

- `lib/modules/anime/anime_detail_page.dart` (+16/−0)
- `lib/modules/anime/anime_follow.dart` (new, 39 lines)
- `lib/modules/anime/anime_home.dart` (+3/−1)
- `test/modules/anime/anime_detail_page_test.dart` (+5/−1)

Commit: `4e0e5bf feat(follow): add the detail-page follow button and the 追番 tab` (4 files changed, 64 insertions(+), 2 deletions(-)).

Only these four files were staged; the many unrelated pre-existing working-tree modifications under `.superpowers/sdd/*` were left untouched.

## Deviations from the brief (both required)

1. **`syncProvider.notifier` does not exist.** The brief (and the plan's Task 6 code) writes `ref.read(syncProvider.notifier).schedule();`, but `syncProvider` is a plain `Provider<SyncService>`, not a `NotifierProvider`, so `.notifier` is a compile error. The existing trigger in `anime_history.dart:92` already uses the correct form, so I used `ref.read(syncProvider).schedule();`. Behavior is identical; without this fix the code does not compile.
2. **Existing detail-page widget tests needed DB init.** Once the header watches `followProvider` (which builds `FollowNotifier` → `FollowManager` → `AppDatabase`), the three tests in `test/modules/anime/anime_detail_page_test.dart` threw `Bad state: AppDatabase not initialized`. The huge `RenderFlex overflowed by 99390 pixels` in the first failure was a *symptom*: the thrown `StateError` replaced the `Consumer` with a wide `ErrorWidget` inside the header `Row`. Every other DB-touching test in the repo already calls `await AppDatabase.init()` in `setUp` (e.g. `watch_history_test.dart`, `follow_manager_test.dart`, `sync_service_test.dart`), so I applied that same established pattern. No assertions or test intent changed. The brief's commit list omitted this file, but committing the lib changes without it would leave `flutter test` red.

## Self-review findings

- **Completeness:** all three brief steps done; the button is inside the `DragToMoveArea`; the tab is index 4 and wrapped by `_heroTab(controller, 4, ...)` exactly like the other four.
- **Quality:** 2-space indentation; no comments added; imports grouped with the existing relative imports. `AnimeFollowView` mirrors `AnimeHistoryView`'s grid constants exactly.
- **YAGNI:** no extra widgets, providers, or abstraction; `AnimeFollowView` is stateless (`ConsumerWidget`) and needs no keep-alive.
- **Hero wiring:** `_heroTab` enables `HeroMode` only when `controller.index == index`, so the follow tab's `WorkCard` heroes cannot collide with the same work shown in another tab. Correct.
- **Button correctness:** the `Consumer`'s `ref` shadows the state's `ref` only within the builder closure; `followProvider` and `syncProvider` resolve via the enclosing `ProviderScope`. Fine.

## Concerns

- The brief's code contains the `syncProvider.notifier` compile error and does not mention the test adaptation. Both are documented above and were the minimum changes needed to satisfy the brief's own verification requirement (`flutter analyze lib test`, `flutter test`, build).
- `AnimeFollowView` is rebuilt from `followProvider` on every follow/unfollow, so an offscreen follow tab stays consistent automatically. No concern.
- No new tests were added (per the brief); the new UI is covered only by the existing detail-page tests that now exercise the header's follow button during build.

Status: DONE_WITH_CONCERNS
