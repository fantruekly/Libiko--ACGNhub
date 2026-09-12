# SDD Progress Ledger

Plan: docs/superpowers/plans/2026-09-12-rule-playback-sources.md
Base commit: 477fa3d (before Task 1)

Task 1: complete (commits 477fa3d..523346b, review clean)
Task 2: complete (commits 523346b..5a79918, review clean after 1 fix)
Task 3: complete (commits 0de58df..50e8cf4, review clean)
Task 4: complete (commits 50e8cf4..4a47a4f, review clean after 1 fix)
Task 5: complete (commits 4a47a4f..f1c9cbe, review clean after 1 fix)
Task 6: complete (commits f1c9cbe..c58d72c, review clean)
Task 7: verification complete (regression fix 7368429; rule calibrated 0c4ec34)
Final whole-branch review: complete; 3 Important findings fixed in 4b76f2a, fixes verified
Pending: human in-app smoke test (search -> episodes -> playback)

## Notes

- Task 2 fix: extraction scripts returned `JSON.stringify(...)`, but `HeadlessWebview.executeScript`
  JSON-decodes WebView2's result, so a JS string could never satisfy `result is List`.
  Fixed in `5a79918`; the plan was corrected.
- Task 4 fix: the `mergeRules` precedence test used identical built-in/imported values, so it
  could not fail for the wrong precedence. Fixed in `4a47a4f`.
- Task 5 fix: the episode "重试" button hit `_expandItem`'s toggle-collapse branch instead of
  re-fetching. Extracted `_loadEpisodes`; fixed in `f1c9cbe`.
- Task 7: Task 5's `Future.delayed(300ms)` leaked a pending timer and broke 3 existing widget
  tests (Task 5/6 ran analyze+build but not `flutter test`). Fixed in `7368429`.
- Task 7: the bundled 7sefun rule's XPaths (from the upstream Kazumi plugin) no longer matched
  the site DOM. Recalibrated against the live DOM and verified with headless Chrome: 12 results
  with titles + `/voddetail/N.html` hrefs, and 1 episode `/vodplay/32967-1-1.html`. The play
  page is JS-driven, so the existing `StreamResolver` headless path applies. Fixed in `0c4ec34`.
- Final review fixes (`4b76f2a`): `_disposed` guard stops queued searches after dispose; the
  scraper tracks the current URL so it does not complete on the initial `about:blank`; the rule
  import now also catches `FileSystemException`.
- `.superpowers/sdd/review-package.ps1` now forces UTF-8 console/output encoding.

## Minor findings (deferred; not required before merge)

- `test/core/video/source_rule_test.dart:42-47` — only a missing-field case is tested; non-String and whitespace-only rejection branches in `req` are unverified.
- `lib/core/video/source_rule.dart:50` — a non-String `userAgent` is silently coerced to null.
- `lib/core/video/source_rule.dart:35` — Chinese error message vs English doc comments (cosmetic).
- `test/core/video/xpath_js_test.dart:17,27` — test names still read "…returns JSON" though the contract is now an array.
- `lib/core/video/webview_scraper.dart:34,50` — doc comments say "returns a JSON array"; cosmetic.
- `lib/core/video/webview_scraper.dart:108-115` — the URL guard narrows but does not fully eliminate the `about:blank` completion race; a navigation that emits no `urlChanged` pays the full 20 s timeout.
- `lib/core/video/rule_source.dart:88` — strips one trailing slash from base (benign divergence from agedm/gimy `_abs`).
- `lib/core/video/rule_source.dart:55` — `VideoItem.id` is the full resolved URL (per brief).
- `test/core/video/rule_source_test.dart` — no coverage for `mapEpisodes` non-list input or its empty-href drop.
- `lib/core/video/rule_store.dart` — `_safeName` can collide (`"a b"` and `"a/b"` → `a_b`); `dir.list()` is unsorted so duplicate imported names win nondeterministically; `_importDir` creates the dir on read paths; `importJson` has no unit test; `AssetManifest.json` is deprecated in favour of `AssetManifest.loadFromAssetBundle`.
- `test/core/video/rule_store_test.dart:6-25` — `_ruleWith` duplicates `_rule` fields (cosmetic).
- `lib/modules/anime/anime_detail_page.dart` — `_playSection(Work w, ...)` no longer uses `w`; `_loadEpisodes` calls `setState` before a `mounted` check; the empty-state text uses `cs.onSurface.withValues(alpha: 0.5)` instead of `#8E8E93`; episodes are re-fetched on every expand rather than cached; `_playEpisode` can leave its modal dialog open if the page is disposed mid-resolve; `await openFile(...)` sits outside the import `try`.
