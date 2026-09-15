# Task 1 Report: Bangumi 热门推荐改为热度榜（含分页）

## Status: DONE

## What I implemented

1. **`lib/core/metadata/bangumi_provider.dart`**
   - Added `static const _heatPerPage = 20;` after `_base`.
   - Rewrote `feed(...)`:
     - `AnimeFeed.trending` now issues `POST /v0/search/subjects` with
       query `limit=20` / `offset=(page-1)*20`, body
       `{keyword:'', sort:'heat', filter:{type:[2], nsfw:false}}`,
       `Content-Type: application/json`, and returns `parseSearch(res.data)`.
     - `season` / `today` still hit `GET /calendar`; `page > 1` still returns `const []`.
       The old `switch` was collapsed to a ternary since `trending` is handled first.
   - Widened `parseSearch(dynamic)` to read `data['list'] ?? data['data']`, so it
     accepts both the legacy `{list:[...]}` shape and the v0 `{data:[...]}` shape.
   - `_parseItem` already parses the v0 Subject shape, so no parser change was needed.

2. **`lib/modules/anime/anime_home.dart:88`**
   - Lowered `_FeedViewState._perPage` from `25` to `20`. `_loadMore` uses
     `_hasMore = next.length >= _perPage`; the heat feed is fixed at 20/page, so
     the threshold must be ≤20 to keep paging. AniList/Jikan return 25/page so
     20 is still satisfied for a full page; `season`/`today` return empty for
     `page > 1` so they stop immediately (behavior unchanged).

3. **`test/core/metadata/bangumi_provider_test.dart`**
   - Added a `_RecordingAdapter` that captures `RequestOptions.last`.
   - Replaced `parseSearch reads data.list` with a test covering both
     `{list:[...]}` and `{data:[...]}`.
   - Split the old combined feed test: kept the `today` filter / `page>1` empty
     assertions and removed the obsolete `trending sorts by score` assertion.
   - Added `feed(trending) posts to v0 search sorted by heat, paged by offset`,
     asserting path, query params, JSON body, and mapped `Work` fields.

## What I tested and results

- Focused: `flutter test test/core/metadata/bangumi_provider_test.dart` → 8/8 passed.
- Static analysis: `flutter analyze lib test` → `No issues found!`
- Full suite: `flutter test` → `+270 ~1: All tests passed!` (270 passed, 1 skipped).

## TDD evidence

### RED (before implementation)

Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/metadata/bangumi_provider_test.dart
```

Failing output (excerpt):
```
00:00 +2 -1: parseSearch reads data.list and data.data [E]
  Bad state: No element
  dart:core                                             List.single
  test\core\metadata\bangumi_provider_test.dart 118:12  main.<fn>

00:00 +4 -2: feed(trending) posts to v0 search sorted by heat, paged by offset [E]
  LateInitializationError: Field 'last' has not been initialized.
  test\core\metadata\bangumi_provider_test.dart         _RecordingAdapter.last
  test\core\metadata\bangumi_provider_test.dart 204:20  main.<fn>

00:00 +6 -2: Some tests failed.
```

Why the failures were expected:
- `parseSearch({data:[...]})` was still reading only `data['list']`, so the list
  was empty and `.single` threw `Bad state: No element`.
- `feed(trending, page: 2)` still returned `const []` at the `page > 1` guard
  (trending still went through `/calendar`), so no HTTP request was made and
  `_RecordingAdapter.last` was never assigned → `LateInitializationError`.

### GREEN (after implementation)

Command:
```
$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/metadata/bangumi_provider_test.dart
```

Passing output:
```
00:00 +0: parseCalendar maps items to Work with the Chinese name and https cover
00:00 +1: parseCalendar onlyWeekday filters days
00:00 +2: parseSearch reads data.list and data.data
00:00 +3: parseDetail reads tags and falls back to name when name_cn is empty
00:00 +4: feed(today) filters to the injected weekday; page>1 is empty
00:00 +5: feed(trending) posts to v0 search sorted by heat, paged by offset
00:00 +6: parseCharacters maps name, relation, image and actors
00:00 +7: parseRelated prefers name_cn and keeps relation
00:00 +8: All tests passed!
```

## Files changed

- `lib/core/metadata/bangumi_provider.dart`
- `lib/modules/anime/anime_home.dart`
- `test/core/metadata/bangumi_provider_test.dart`

Commit: `0a1b640 feat(anime): 热门推荐 uses Bangumi all-anime heat ranking`
Pushed: `061c938..0a1b640 dev -> dev` on `origin`.

## Self-review findings

- Implementation and tests match the brief verbatim; no extra scope, no comments,
  no new dependencies, `pubspec.yaml` untouched.
- `season`/`today` paths and AniList/Jikan providers were not modified; the
  collapsed ternary preserves the original `today` vs `season` semantics.
- Test hygiene: the new recording adapter is isolated and does not affect the
  existing `_FakeAdapter` tests; the removed trending-sort assertion was genuinely
  obsolete (that behavior no longer exists).
- `parseSearch` precedence `list ?? data` keeps the legacy search endpoint
  (`{list:[...]}`) working while adding the v0 shape.

## Issues or concerns

- Per the brief's known trade-offs: result set caps at 1000 items / 20 per page
  (Bangumi API limit), `nsfw:false` excludes R18, and v0 subjects have no
  top-level `rank` so `extra['rank']` is null (unused elsewhere).
- The `_FeedView` scroll-triggered paging was not covered by a widget test
  (private widget, layout-dependent); the brief accepts full-suite + build +
  manual scroll verification for this. I did not run the manual GUI scroll check
  as part of this automated task.
- Pre-existing working-tree modifications to `.superpowers/sdd/progress.md` and
  `.superpowers/sdd/task-1-brief.md` were intentionally left unstaged, per the
  brief's exact `git add` file list.

---

# Task 1 Follow-up Report: Test hardening (calendar regression + trending method/content-type)

## Status: DONE

## What changed

Changed ONLY `test/core/metadata/bangumi_provider_test.dart`:

1. `feed(today) filters to the injected weekday; page>1 is empty`: switched the
   adapter from `_FakeAdapter(days)` to `_RecordingAdapter(days)` (bound to a
   local `adapter`), and added
   `expect(adapter.last.path, '/calendar')` and
   `expect(adapter.last.method, 'GET')` to assert `today`/`season` still hit
   `GET /calendar`.
2. `feed(trending) posts to v0 search sorted by heat, paged by offset`: added
   `expect(adapter.last.method, 'POST')` and
   `expect(adapter.last.contentType, Headers.jsonContentType)` right after the
   path assertion.
3. Deleted the now-unused `_FakeAdapter` class (verified via search that the only
   remaining references were its own declaration/constructor).

No production code, no new dependencies, no comments.

## Verification (exact commands + results)

- `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/metadata/bangumi_provider_test.dart`
  → `00:00 +8: All tests passed!` (8 passed).
- `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
  → `Analyzing 2 items... No issues found! (ran in 1.8s)`.
- `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
  → `00:13 +270 ~1: All tests passed!` (270 passed, 1 skipped: the pre-existing
  flutter_qjs native-library skip).

## Files changed

- `test/core/metadata/bangumi_provider_test.dart` (1 file, +6 / -24)

## Commit

- `b41989a test(anime): assert /calendar regression and trending request method/content-type`
- Pushed: `0a1b640..b41989a dev -> dev` on `origin`.
