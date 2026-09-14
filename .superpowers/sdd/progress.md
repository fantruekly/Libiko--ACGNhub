# SDD Progress Ledger

Plan: docs/superpowers/plans/2026-09-12-comic-ui-home-detail.md (C2a)
Base commit: 89c0a42 (before Task 1)

Task 1: complete (commit 89c0a42..5050360, review clean)
Task 2: complete (commit 5050360..ea2f1b3, review clean)
Task 3: complete (commit ea2f1b3..26b4696, review clean)
Task 4: complete (commit 26b4696..62f05bd + fix c2e2371, review clean after 1 fix)
Task 5: complete (commit c2e2371..31c4876, review clean)
Task 6: complete (commit 31c4876..6a9b0c9, review clean)
Task 7: complete (commit 6a9b0c9..763add6, review clean; manual GUI smoke test deferred to human)
Final whole-branch review: 89c0a42..763add6 → "merge with fixes"; fix commit 51791fd
  (serialized store writes; search surfaces total failure), re-review clean.
C2a: COMPLETE (89c0a42..51791fd) pending the manual GUI smoke test.
C2b: plan written (docs/superpowers/plans/2026-09-13-comic-reader.md), execution starting.

## C2b ledger — Comic Reader

Plan: docs/superpowers/plans/2026-09-13-comic-reader.md (C2b)
Base commit: 51791fd (before C2b Task 1)

Task 1: complete (commit 51791fd..36bac90, review clean)
Task 2: complete (commit 36bac90..a280520, review clean)
Task 3: complete (commit a280520..6c404a6 + fix ab4aca3, review clean after 1 fix)
Task 4: complete (commit ab4aca3..0ce11d0 + fixes a02d5ce, 65e78cd, d020df5, review clean after fixes)
Final whole-branch review: 51791fd..a02d5ce → "merge with fixes"; fix wave 65e78cd + d020df5
  (mode-switch page loss, history throttle, backward landing, prev-chapter preload, reliable resume),
  re-review clean.
C2b: COMPLETE (51791fd..d020df5), pushed to origin/dev, awaiting the user's PR.

## Venera source compatibility (ad hoc, plan 2026-09-13-comic-venera-compat.md)

- Task 1: complete (commit bbe2ed2..0dedd94 + fix 2db365b, review clean after fixes).
  Added `loadData`/`saveData`/`deleteData`, `Convert` aliases + `hmacString`, `Network.deleteCookies`,
  global `randomInt`/`fetch`, per-instance `init()`, and corrected `Network.post/put/delete` arg order.
- Imported 11 general Venera sources into the app source dir + `copy_manga.data`.
  Probe: 11/11 load; clean search for copy_manga(21), ManHuaGui(10), zaimanhua(16), Komiic(2),
  ikmmh(0), shonen_jump_plus(0). The other 5 (baozi/comick/manga_dex/manwaba/ykmh) load but
  search errored at the site/network layer (404/403/status 0/HTML change), not the engine.
- Out of scope (per user): AES, account/WebView login, `Cache`/`IO`, `minAppVersion` gating.

## C2c ledger — Comic explore sections + pagination

Plan: docs/superpowers/plans/2026-09-13-comic-explore-sections.md
Spec: docs/superpowers/specs/2026-09-13-comic-explore-sections-design.md
Base commit: 5638e3e (before C2c Task 1)

Task 1: complete (commit 5638e3e..1fa6552, review clean)
Task 2: complete (commit 39c1e4c..a430620, review clean; maxPage may be null for offset paging)
Task 3: complete (commit f1a5b55..f5d04bd + fix ec3fb68, review clean after 1 fix)
Final whole-branch review: 5638e3e..ec3fb68 → "merge with fixes"; fix abeaea4
  (client-paged retry, parser tests, section/page clamps, registry guard), re-review clean.
C2c: COMPLETE (5638e3e..abeaea4), pushed to origin/dev; manual in-app smoke test deferred to the human.

## C2d ledger — Comic AES + cursor paging

Plan: docs/superpowers/plans/2026-09-13-comic-aes-cursor.md
Spec: docs/superpowers/specs/2026-09-13-comic-aes-cursor-design.md
Base commit: c05d7d0 (before C2d Task 1)

Task 1: complete (commit c05d7d0..a889320, review clean)
Task 2: complete (commit a889320..3713de9, review clean)
Task 3: complete — imported jm/ehentai. ehentai explore works (12/11 galleries across its 2 sections)
  after an ad-hoc engine fix c5dc4ad (HtmlNode.children + capacity 64→1024). jm loads and AES works but its
  configured domains (`www.cdntwice.org/promote`) return 404 — external/source-domain issue, not the engine.
Final whole-branch review: c05d7d0..c5dc4ad → "merge with fixes"; fix 37eeea8
  (usesLoadNext requires no `load`; added a cursor probe proving c1→c2→c3), re-review clean.
C2d: COMPLETE (c05d7d0..37eeea8), pushed to origin/dev. ehentai explore works (2 sections);
  jm loads but its domains 404 (external). ehentai search needs search-options support (not built).
Ad-hoc UI fixes (53a4954, fbc56e5): HTML handle capacity 16384 (fixes ehentai pagination),
  48 comics/page, centered pager.

## C2f ledger — Continuous paging into category content

Plan: docs/superpowers/plans/2026-09-13-comic-continuous-paging.md
Spec: docs/superpowers/specs/2026-09-13-comic-continuous-paging-design.md
Base commit: 2964152 (before C2f Task 1)

Task 1: complete (commit 2964152..60c0da8, review clean)
Task 2: complete (commit 60c0da8..2068f91, review clean)
Task 3: complete (commit 2068f91..501fd54, review clean)
Task 4: complete (commit 501fd54..d25b510; continuous probe: page1 [a1] → page2 cat1-* → page3 cat2-* → stop)
Final whole-branch review: 2964152..d25b510 → "merge with fixes"; fix cba3013
  (empty-name continuation guard, maxPage normalize, viewMore parser tests, docs; real-source probe
  verified manhuagui/baozi category continuation), re-review clean.
C2f: COMPLETE (2964152..cba3013), pushed to origin/dev. One-shot explore sections now continue into
  the source's category listing; verified against manhuagui (78→42/page) and baozi (108→36/page).

## C2g ledger — Row-aligned source/cursor paging

Plan: docs/superpowers/plans/2026-09-13-comic-row-aligned-paging.md
Spec: docs/superpowers/specs/2026-09-13-comic-row-aligned-paging-design.md
Base commit: 2040a01 (before C2g Task 1)

Task 1: complete (commit 2040a01..e3c6566, review clean)
Task 2: complete (commit 7fe9064..392f65e; alignment probe 48/27; real sources aligned)
Final whole-branch review: 2040a01..392f65e → "merge with fixes"; fix a4174ef
  (extracted `buildAlignedExplorePage` + 4 unit tests; autoDispose on the explore families), re-review clean.
C2g: COMPLETE (2040a01..a4174ef), pushed to origin/dev. Server/cursor sections now show 48/page
  (multiple of 6) except the true last page; ehentai 48/48 + tail.
Ad-hoc fixes: reader default = page flip + tap-to-flip (096ec0d); white reader background (b773321);
  reader chrome on error (4a9046b); continuous pages fit window height (5c6e383);
  APP global + tags/chapters flattening (a030cb4); innerHTML alias (c357809).

## C2e ledger — Comic account login

Plan: docs/superpowers/plans/2026-09-13-comic-account-login.md
Spec: docs/superpowers/specs/2026-09-13-comic-account-login-design.md
Base commit: caf51ef (before C2e Task 1)

Task 1: complete (commit caf51ef..1347214 + fix 5f4f5f9, review clean after 1 fix)
Task 2: complete (commit 5f4f5f9..e49bae8 + fix cacbc39, review clean after 1 fix)
Task 3: complete (imported picacg 1.0.5; account probe: picacg hasLogin, ehentai hasCookieLogin fields=[ipb_member_id, ipb_pass_hash, igneous, star])
Final whole-branch review: caf51ef..cacbc39 → "merge with fixes"; fix bb9ca63
  (cookie domain matching + jar persistence + account tests), re-review clean.
C2e: COMPLETE (caf51ef..bb9ca63), pushed to origin/dev. Real sign-in left to the human.

### C2b minor findings (for the final whole-branch review to triage)

- `comic_reader_page.dart` — previous-chapter overscroll lands at the previous chapter's top (not its end); history page-change write is a 1 s debounce rather than a throttle; `_preload` has no de-dup/cancellation and reads `_chapterId` mid-flight (overlapping preloads on rapid scrolling); the bottom bar shows `0 / 0` while a newly selected chapter loads; `_continuous` mutates `_initialJumpDone` and schedules a frame callback during `build`.

## Notes

- C2 is split: **C2a** (this plan) and **C2b** (the reader). C2a's chapter buttons / 继续阅读 and the
  home's card taps are intentional placeholders — Task 4 chose `SnackBar('详情页开发中')` for card
  taps; Task 6 adds `ComicDetailPage` and must replace them.
- Task 4 fix (`c2e2371`): the kept-alive 发现/收藏 tabs duplicated `Hero` tags; each `TabBarView`
  child is now wrapped in `HeroMode(enabled: controller.index == i)` like `anime_home.dart`.
- Task 4 added `comicSourceListUrlProvider` (the plan was amended to say so).
- Briefs are extracted with an inline fence-aware script (`.superpowers/sdd/make-brief.ps1` is flaky
  on the longer plans); always check the brief's first line names the right task.

## Minor findings (triaged by the final whole-branch review — acceptable polish, not fixed)

- ~~`lib/core/comic/comic_favorite.dart:78` — `toggle` has no write serialization~~ FIXED in 51791fd (both stores now serialize via `_enqueue`).
- `lib/modules/comic/comic_source_page.dart` — `ref.invalidate(comicSourcesProvider)` runs before the `mounted` guard in async handlers; `_confirmClear` lacks a `context.mounted` guard; the remote-list URL persists on every keystroke; the remote 添加 button is not disabled while importing.
- `lib/modules/comic/comic_search.dart` — duplicates the private `_comicGrid` constants from `comic_home.dart`; the empty state can show a false-negative `没有找到漫画` while `comicSourcesProvider` is still loading (Task 3 provider behavior); clearing the field does not clear the last results. (The `.when(error:)` branch is now reachable after 51791fd.)
- `lib/modules/comic/comic_detail_page.dart` — the description 展开/收起 uses a `length > 60` heuristic instead of measuring 3 lines; a tagless comic leaves a stray 10px gap before the description; the favorite stores `details.cover`/`title` (may differ from the list entry's).

(previous plans are complete; their history is in git)

## Novel module v1 ledger — 首页浏览/排行

Plan: docs/superpowers/plans/2026-09-14-novel-module.md
Spec: docs/superpowers/specs/2026-09-14-novel-module-design.md
Base commit: a4691b5 (before Task 1)

Task 1: complete (commit a4691b5..3821f0b, review clean)
  Minor (deferred to final review): `_stringList` only flattens a top-level list;
  container classes (NovelSection/NovelHome/NovelList/NovelDetail/NovelChapter) have no direct tests.
Task 2: complete (commit 3821f0b..eeaed68, review clean)
  Minor (deferred): duplicate-id via constructor not asserted; `sources` allocates a wrapper per call; `byId` O(n).
Task 3: complete (commit eeaed68..c08c2f8, review clean)
  Minor (deferred): `hasNextPage` scans all `<a>` (could scope to div.pagination); `parseRankRows` omits category tags; some `_absUrl` branches untested.
Task 4: complete (commit c08c2f8..a7ebfcb, review clean)
  Minor (deferred): `_get` non-200 branch is dead (Dio throws first); home()/browse() routing/error paths untested; hasNextPage re-parses per call.
  Live-HTML behavior (selectors/UTF-8/URL join) verified only by manual run later.
Task 5: complete (commit a7ebfcb..784556e, review clean)
  Minor (deferred): provider bodies untested (only flattenHome); novelSourcesProvider is async without await.
Task 6: complete (commit 784556e..494da54, review clean)
  Minor (deferred): paging can re-fire/skip a page on fast scroll; next-page load swaps grid for full-screen shimmer;
  shimmer/grid aspect mismatch; source-load failure hidden by valueOrNull; NovelCard test is title/author only.
  Visual verification deferred to human.
Final whole-branch review: a4691b5..494da54 → "merge with fixes" (3 Important: replace-not-append paging,
  page-skip on fast scroll, hasMore not per spec; ~8 Minor).
  User decision: replace auto-load with a manual 上一页/下一页 pager; fix the rest.
Task 7 (review fixes): complete (commit 494da54..da36459, re-review: 3 Important resolved; 1 new Important)
  Manual pager; hasMore = pagination-control ? next-link : items>=10; Accept/Accept-Language headers;
  parseRankRows tags; novelSourcesProvider → sync Provider; shimmer/grid metrics matched; +2 parser tests, +1 card test.
Task 8 (re-review fixes): complete (commit da36459..c4519db, re-review clean: "Ready to merge? Yes")
  allvisit (人气榜) forced single-page (isSinglePageRanking) — fixes the 下一页 loop; rank-tags test; spec sync.
Novel module v1: COMPLETE (a4691b5..c4519db + spec doc fix). Pushed to origin/dev.
  Manual live-site verification (源 chip / 网格 / 排行子chip / 手动换页 / 文库) still owed to the human.
  Deferred Minors: hasMore `>=10` fallback can show one extra empty page; browse hasMore not unit-tested;
  double HTML parse in hasPaginationControl+hasNextPage; Novel.fromJson extra cast is lazy.

## Novel detail ledger — 书籍详情 + 分卷目录

Plan: docs/superpowers/plans/2026-09-14-novel-detail.md
Spec: docs/superpowers/specs/2026-09-14-novel-detail-design.md
Base commit: 9b96e56 (before Task 1)

Task 1: complete (commit 9b96e56..a52210b, review clean)
  Minor (deferred): no coverage for NovelVolume url==null / chapters==[] defaults; NovelChapterRef has no equality.
Task 2: complete (commit a52210b..a4e5064, review clean)
  Minor (deferred): parseCatalog non-chapter-href skip untested; missing-element fallbacks untested; cover src/data-original precedence asymmetry vs list parsers.
Task 3: complete (commit a4e5064..03cafdf, review clean)
  Minor (deferred): detail fetches the two pages sequentially; detail merge not unit-tested (network).
Task 4: complete (commit 03cafdf..e018ea5, review clean; no issues)
Task 5: complete (commit e018ea5..7d02e87, review clean)
  Minor (deferred): 展开/收起 shows even when the summary fits 3 lines; some surface colors outside tokens; no test for error/empty/SnackBar states.
  Visual verification deferred to human.
Final whole-branch review: 9b96e56..7d02e87 → "merge with fixes" (Critical: cover precedence; Important: cover placeholder, summary fallback; ~9 Minor).
Task 6 (review fixes): complete (commit 7d02e87..87710ee + 584df15, re-review clean: "Ready to merge? Yes")
  data-original-first cover; meta-description summary fallback; cover placeholder/errorWidget; overflow-gated 展开 (honors textScaler, painter disposed); Future.wait; spec sync.
Novel detail increment: COMPLETE (9b96e56..584df15). Pushed to origin/dev.
  Manual live-site verification (卡片→详情页：封面/作者/标签/简介/分卷目录/点章节提示) still owed to the human.
  Deferred Minors: no regression test for textScaler overflow; hardcoded TextDirection.ltr; `data-original=""` doesn't fall through to src;
  parseCatalog's unused novelId; eager Wrap of all chapters; some surface colors outside tokens.

## Novel ranking fix (ad hoc)

Bug (user): 点「排行」加载不出来. Root cause: `/top.html` (人气榜) rows are `div.rank_i_li`;
`/top/<key>/<page>.html` (月推荐/收藏榜/…) rows are `div.rank_d_list` — `parseRankRows` only handled the former.
Task 9: complete (commit b7a9af0..13a5f1f, review clean: Approved). Probe: allvisit→60, monthvote→30 (hasMore), goodnum→30 (hasMore).
  Parser cost measured at 8ms for a 79KB page → the reported 卡顿 is NOT HTML parsing; UI-layer cause still unconfirmed (asked user to re-test after the fix).

Ranking freeze (user): 切到排行就卡死/无法操作.
Root cause: the 排行/文库 pager used `OutlinedButton` inside a `Row`; the app-wide
`outlinedButtonTheme` sets `minimumSize: Size(double.infinity, 48)`, so the button
demanded infinite width under unbounded Row constraints → endless
`RenderBox was not laid out` / `!semantics.parentDataDirty` loop each frame → freeze.
Reproduced via `flutter run` log (9931 lines of repeating exceptions) with the app
temporarily starting on 排行. Fix: explicit bounded pager button style (Size(84,40)).
Task 10: complete (commit bf93a6b..0d08559) + regression test `novel_home_pager_test.dart`
  (fails without the fix, passes with it). Verified: 0 exceptions, allvisit→60, monthvisit/weekvisit→30.

## Novel reader ledger — 阅读器

Plan: docs/superpowers/plans/2026-09-14-novel-reader.md
Spec: docs/superpowers/specs/2026-09-14-novel-reader-design.md
Base commit: 98c8c85 (before Task 1)

Task 1: complete (commit 98c8c85..9d9cf5b, review clean)
  Minor (deferred): maxPages cap / self-referential link untested; fetchChapterPages passes '' as fallback title.
Task 2: complete (commit 9d9cf5b..79c4d7c, review clean)
  Minor (deferred): chapter path string duplicated between chapterPath and fetchChapterPages; chapter() has no direct behavioral test.
Task 3: complete (commit 79c4d7c..a00f8a0, review clean)
  Important (plan-mandated, deferred to final review): `write()` discards AppDatabase.setString's bool, then
  `_update` sets `state` unconditionally → a failed write desyncs state from storage. Same as comic_reader_settings.
  Minor (deferred): concurrent setter lost-updates; setter clamp untested.
Task 4: complete (commit a00f8a0..0103699, review clean)
  Minor (deferred): novelChapterProvider has no direct test (only flattenChapters).
Task 5: complete (commit 0103699..23fad20, review clean). 3 justified deviations from the brief's verbatim
  code (brief was internally inconsistent): test setUp needs AppDatabase.init(); added chapter-title heading
  the test asserts; wrapped content in Positioned.fill (Stack shrink-wrap → bottom-bar RenderFlex overflow).
  Minor (deferred): _topBar unused chapters/index params; sheets don't use the reading palette; happy-path test only.
Final whole-branch review: 98c8c85..23fad20 → "merge with fixes" (3 Important: settings lost-update/persist desync,
  missing next-chapter nav test, dead chapterPath; ~7 Minor).
Task 6 (review fixes): complete (commit 23fad20..6f9ba67, re-review clean: "Ready to merge? Yes")
  state synced before write; chapterPath wired into fetchChapterPages; volume-grouped + palette-themed sheets;
  _topBar params dropped; next-chapter navigation test added.
Novel reader increment: COMPLETE (98c8c85..6f9ba67). Pushed to origin/dev.

## Novel reader follow-up fixes (ad hoc)

Task 7 (illustrations): complete (commit 6f9ba67..6b7dc5b, review clean). `NovelChapter` now holds ordered
  `List<NovelBlock>` (`NovelText`/`NovelImage`); `parseChapter` reads `#TextContent` children, images from
  `data-src` (skipping sloading/.svg); reader renders `CachedNetworkImage`. Ripple test files also updated.
  Minor (deferred): `_imageUrl` trusts a present-but-empty data-src; no widget test for image rendering/empty state.
Task 8 (window controls): complete (commit 6b7dc5b..cfeaf12, review clean: Approved). Detail AppBar actions +
  reader `_topBar` now show `WindowControls` (the pushed full-screen routes had covered the shell title bar).
Task 9 (image hotlink): complete (commit cfeaf12..ea5ba0a, review clean). `novelImageHeaders` (Referer) applied to
  all 3 novel CachedNetworkImage sites — `img3.readpai.com` images 403 without it.
Task 10 (detail header/transition): complete (commit ea5ba0a..1eecffa, review clean). Custom 48px DragToMoveArea
  header (back + title + WindowControls) replacing the Material AppBar; `noTransitionRoute` for the detail push.
  Note: `_header(novel)` content card renamed `_infoCard(novel)` to avoid the name collision.
Task 11 (uniform cards): complete (commit ea1bc47..64df555, review clean). Author line removed from `NovelCard`
  (explore grid) so all covers are the same height; card test now asserts author is absent.
Task 12 (illustration sizing): complete (commit 64df555..3d79ee1, review clean). Reader `NovelImage` wrapped in a
  fixed `SizedBox(height: _illustrationHeight(context))` with `BoxFit.contain` — fills the page vertically, blank sides.
Task 13 (人气榜 covers): complete (commit 7227414..9277f9b, review clean). `rankPath` now uniform
  `/top/<key>/<page>.html`; allvisit uses `/top/allvisit/<page>.html` (30/30 rows with covers) instead of `/top.html`
  (only ~6/122 rows had covers); `isSinglePageRanking` removed. Minor: the `rank_i_li` branch in `parseRankRows` is now
  unreachable via `rankPath` but kept (with its test).
  Manual live-site verification owed to the human: selectors (#mlfy_main_text h1, div#TextContent p, div.mlfy_page a),
  relative vs absolute 下一页 hrefs, and that chapter bodies are <p>-wrapped.
  Deferred Minors: rapid-tap still bounded by rebuild timing; partial sheet theme override; duplicated Theme boilerplate;
  novelChapterProvider untested directly; maxPages cap untested.

## lknovel source plan (2026-09-14-lknovel-source.md)

Task 1: complete (commits 7ce8641..3fe3bb4, re-review clean: Approved). Browse model generalized:
  NovelBrowseOption/NovelBrowseGroup; NovelSource.browseGroups + browse(String optionKey); NovelBrowse(Kind) removed;
  NovelVolume.id optional; novelBrowseProvider key (sourceId,optionKey,page); novel_home renders source-declared groups.
  Fix 3fe3bb4 added LinovelibSource.browsePath + test/core/novel/linovelib_browse_test.dart.
  Minor (deferred to final review): parser dispatch (parseRankRows/parseBookList) not independently asserted; option-chip index cosmetic.
Task 2: complete (commits 3fe3bb4..79289b1, review clean: Approved). New lib/core/novel/lknovel_source.dart:
  LknovelSource (id lknovel, name 轻之国度) + LkPoster seam + pure parsers (lkData/parseLkBook/parseLkList/
  lkHasMore/parseLkVolumes/parseLkVolumeChapters/parseLkChapter); home() 4 feeds w/ per-feed resilience;
  browseGroups 排行/分类; browse() rank_scene vs feed endpoints; registered in novel_providers.dart.
  detail/chapter are intentional UnimplementedError stubs (Task 3).
  Confirmed live: bff/home-feed-v1 works (code 0) for new_books.
  Minor (deferred to final review): home partial-failure/all-empty untested; code string '0' not handled;
  lkHasMore 30-item fallback heuristic; _stringList duplicated from models.dart.
Task 3: complete (commits 79289b1..8e1159a, review clean: Approved). LknovelSource.detail (get-book-detail
  with_volumes:1 + per-volume get-volume-chapters, batch 6, page>=100 cap, per-volume try/catch -> empty) and
  chapter (get-chapter-detail -> parseLkChapter) implemented; 2 tests appended (RED->GREEN).
  Minor (deferred to final review): catch(_) swallows all errors (no debug log); failure isolation & pagination
  cap covered by construction only.
ALL 3 TASKS COMPLETE. Next: final whole-branch review.
Final whole-branch review (7ce8641..8e1159a): 'With fixes'. 2 Important (illustration URL normalization;
  prefer full summary over summary_short) + minors. Fix commit 86d4faa resolved Important #1/#2 and minors
  #3 (code via _asInt), #4 (rankingKeys Set), #5 (5 new tests). Re-review 8e1159a..86d4faa: Approved.
  Remaining Minors (recorded, not fixed): code!=0 test doesn't guard the _asInt change (needs a {"code":"0"} non-throw case);
  _imageUrl treats data-src="" as present and drops a valid src; non-http schemes (data:) mangled.
lknovel source feature: COMPLETE (7ce8641..86d4faa). Pushed to origin/dev.
  Live manual verification still owed: open a lknovel chapter with an illustration + a long-series detail.

## Novel library plan (2026-09-14-novel-library.md)

Task 1: complete (commits 3889f68..da31bef, review clean: Approved). Added lib/core/novel/novel_history.dart +
  novel_favorite.dart (SharedPreferences keys novel_history/novel_favorites, Riverpod notifiers/providers,
  upsert dedupe by (sourceKey,novelId), newest-first). Tests novel_history_test/novel_favorite_test.
  Minor (deferred): upsert inserts at index 0 relying on all() sort (comic-identical).
Task 2: complete (commits da31bef..56308ac, review clean: Approved). NovelHomePage now DefaultTabController
  探索/收藏/历史; _ExploreTab (keep-alive) holds prior explore UI; _FavoritesTab grid; _HistoryTab list + 清空历史
  confirm + empty states. NOTE: implementer pre-added optional unused NovelReaderPage.cover (brief-sanctioned) —
  Task 3 must reuse it, not add a second.
  Minor (deferred): _confirmClear reads ref after await (disposed-ref risk, comic-identical); tabs test doesn't
  cover clear-flow/routes/headers; _relativeTime future-delta edge.
Task 3: complete (commits 56308ac..ef15e4a, review clean: Approved). NovelReaderPage records NovelHistoryEntry via
  ref.listen on novelChapterProvider (whenData), reuses pre-existing cover field. Test asserts recorded entry.
  Minor (deferred): ref.listen fireImmediately=false means an already-cached chapter won't re-record on reopen
  (timestamp may be stale within a session); empty-title fallback branch untested; some entry fields unasserted.
Task 4: complete (commits ef15e4a..0395001, review clean: Approved). NovelDetailPage: favorite FilledButton.icon in
  _infoCard (收藏/已收藏); full-width 继续阅读 when history exists; _openChapter passes cover.
  Minor (deferred): cover fallback doesn't guard widget.cover==''; favorite saves novel.coverUrl (null when using
  widget.cover fallback); isFavorite/cover resolution DRY nits.
ALL 4 TASKS COMPLETE. Next: final whole-branch review.
Final whole-branch review (3889f68..0395001): 'With fixes'. 1 Important (reader stale when chapter already cached)
  + minors. Fix commit 809da9f: reader records via build-time async.whenData + _lastRecordedChapterId guard
  (Riverpod 2.6.1 has no listen fireImmediately / overrideWithValue — adapted); detail persists resolved cover;
  removed dead isFavorite; added storage round-trip/malformed tests + cached-chapter regression test.
  Re-review 0395001..809da9f: Approved.
Novel library feature: COMPLETE (3889f68..809da9f). Pushed to origin/dev.
  Live manual verification still owed: open a novel, read chapters, check 继续阅读/收藏/历史/清空历史.

## Novel UI fixes plan (2026-09-14-novel-ui-fixes.md)

Task 1: complete (commits 64335b5..9330236, review clean: Approved). linovelib bunko now fetched from
  https://w.linovelib.com (Cloudflare-challenged on www); added linovelibMobileBaseUrl, parseMobileBookList,
  mobileHasNextPage; browsePath returns absolute URLs; _getUrl added. Ranking unchanged.
  Minor (deferred): bunkoPath/parseBookList now unused in prod (still tested); _getUrl duplicates _get;
  no test for img src fallback.
Task 2: complete (commits 9330236..b6028f3, review clean: Approved). LknovelSource.detail batchSize 6->12.
  Minor (deferred): higher concurrency may hit host rate limits (no backoff).
Task 3: complete (commits b6028f3..5bc213e, review clean: Approved). novel_home _pager now comic-style
  (chevron IconButtons + 第 X 页 + top border); _pagerButtonStyle removed; pager test asserts chevrons.
  Minor (deferred): pager test still has inert outlinedButtonTheme override + stale name/comment.
Task 4: complete (commits 5bc213e..e85c766, review clean after fix: Approved). New lib/core/widgets/marquee_text.dart
  (fits -> plain Text; overflow -> OverflowBox intrinsic layout + MouseRegion hover scroll + outer ClipRect);
  applied to PillButton label + reader catalog ListTile. Fix e85c766 unclamped inner Text (was clipped) and
  disposed TextPainter; controller eager-inited in initState (brief's late-final lazy init crashed dispose).
  Minor (deferred): no didUpdateWidget reset; test assumes single Transform.
ALL 4 TASKS COMPLETE. Next: final whole-branch review.
Final whole-branch review (64335b5..e85c766): 'Ready to merge: Yes'. 1 Important (lknovel concurrency 12 +
  silent per-volume failure — pre-existing tradeoff, user chose higher concurrency) + minors. No must-fix.
  Live-verified: w.linovelib.com/wenku/<key>/1.html loads for dengekibunko/emuefubunkojei/other with the app's
  Referer, 30 book-li/page, numeric a.last (21/12/42).
  Minor (deferred): stale pager test scaffolding (inert outlinedButtonTheme + old name); bunkoPath/parseBookList
  unused in prod; _getUrl duplicates _get; marquee no didUpdateWidget; mobile parser src-fallback untested.
Novel UI fixes feature: COMPLETE (64335b5..e85c766). Pushed to origin/dev.

## Novel search plan (2026-09-14-novel-search.md)

Task 1: complete (commits 2fddbf2..2a0aabe, review clean: Approved). linovelib_source.dart: parseSearchResults
  (div.search-result-list) + LinovelibSource.search (POST /S6/ form searchkey). Test linovelib_search_parser_test.
  Minor (deferred): narrow test coverage; data-original='' not falling back to src (consistent with existing).
Task 2: complete (commits 2a0aabe..2433e0f, review clean: Approved). LknovelSource.search -> POST
  bff/apk-search-result-v1 {q,page,page_size}; parseLkList. Test added.
  Minor (deferred): empty-keyword branch untested.
Task 3: complete (commits 2433e0f..1a6feb6, review clean: Approved). NovelSearchResult + novelSearchProvider
  (aggregate, per-source failure isolation, title dedupe, all-fail StateError). 3 tests.
  Minor (deferred): catch(e) broad; zero-source throws with null lastError; empty-keyword untested.
Task 4: complete (commits 1a6feb6..4679bea, review clean: Approved). NovelSearchPage (mirror ComicSearchPage) +
  main_shell top-bar entry for index 2. 2 tests.
  Minor (deferred): grid inlined (no _resultsGrid helper); _currentIndex >= 0 redundant; noTransitionRoute
  differs from comic's smoothRoute; page tests don't cover provider merge logic.
ALL 4 TASKS COMPLETE. Next: final whole-branch review.
Final whole-branch review (2fddbf2..4679bea): 'With fixes'. 1 Important (missing empty-results page test)
  + minors. Fix 71f2596: added empty-results page test, empty-keyword tests (provider + lknovel), linovelib
  src-fallback test, and a zero-source guard in novelSearchProvider. Re-review 4679bea..71f2596: Approved.
Novel search feature: COMPLETE (2fddbf2..71f2596). Pushed to origin/dev.
  Live manual verification still owed: open novel module -> search a keyword -> results/detail.
