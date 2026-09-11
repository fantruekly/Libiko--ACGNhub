# Task 7 Report: Rewrite anime search to use the metadata service

## What was implemented
Replaced the body of `_search()` in `lib/modules/anime/anime_search.dart` so it calls
`ref.read(metadataServiceProvider).search(k)` and assigns the returned `List<Work>`
directly to `_results`. Removed the previous `bangumiServiceProvider.searchSubject(k)`
call and the manual `Work` mapping. Added a `mounted` guard before `setState` on the
success path. Loading/error/empty states and the rest of the widget are unchanged.

## Files changed
- `lib/modules/anime/anime_search.dart` (3 insertions, 14 deletions)

## Imports review
- `anime_providers.dart` kept — still required for `metadataServiceProvider`.
- `bangumi_detail_page.dart` kept — `BangumiDetailPage` is still referenced at the
  `WorkCard` `onTap` (renamed later in Task 8).
- `work.dart` kept — `List<Work> _results` still uses `Work`.

## Verification
Command: `flutter analyze lib/modules/anime/anime_search.dart`
Result: `No issues found! (ran in 1.1s)`

## Commit
`4a1a7f0` feat(anime): search via metadata service

## Self-review findings
- `_search()` matches the brief verbatim.
- No unused imports (analyzer reports no issues).
- Error handling preserved via try/catch.
- `_hasSearched`, `_loading`, `_error`, `_results` state semantics preserved.

## Concerns
None.
