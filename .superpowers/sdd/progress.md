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

## Chip bar transition feature (plan 2026-09-15-chip-bar-transition.md)
Task 1: complete (commits 4edac71..12cb247, review clean: Approved). New lib/core/widgets/chip_bar.dart + test/core/widgets/chip_bar_test.dart.
  Minor (deferred): AnimatedDefaultTextStyle uses linear curve (pill easeInOutCubic); limited test coverage; TextPainter per label per rebuild; no auto-scroll to selected chip; no Semantics.
Task 2: complete (commits 12cb247..6920c98, review clean: Approved). novel_home.dart _sourceChips/_sectionChips/_optionChips use ChipBar; _chip + pill_chip import removed.
  Minor (deferred): no automated test for section index mapping (selectedIndex=_groupIndex+1); index<0 fallback unreachable.
Task 3: complete (commits 6920c98..062fa40, review clean: Approved after fix). comic_home.dart source/section/part rows use ChipBar; removed _chip/_sourceChip/_horizontalScroll/gestures import + pill_chip.dart.
  Plan-mandated finding (human decided FIX): third-row keys omitted parent identity -> fix 062fa40 added source.key+section / _sourceId+_groupIndex to comic-part and novel-option keys.
  Minor (deferred): delimiter-collision theoretical; no automated test for section/option index mapping; animation not visually confirmed headless.
ALL 3 TASKS COMPLETE. Next: final whole-branch review.
Final whole-branch review (4edac71..062fa40): 'With fixes'. 1 Important (ChipBar lost NotoSansSC via AnimatedDefaultTextStyle replace-not-merge) + 1 Important plan-level (caller-managed row keys fragile) + minors.
Fix 5f78a59: merge ambient DefaultTextStyle into chip style (font restored, used for measure+render); add easeInOutCubic to text-color animation; ChipBar owns row identity via KeyedSubtree(ValueKey(Object.hashAll(labels))); removed 6 caller keys; reverted _partChips signature; added 'changing labels jumps' test. Re-review 062fa40..5f78a59: Approved.
  Minor (deferred): internal label-only identity means two different parents with identical labels animate instead of jump (user chose encapsulation); scroll offset no longer resets on row change; no test for the font fix.
Chip bar transition feature: COMPLETE (4edac71..5f78a59). Pushed to origin/dev. Live manual verification still owed.

## Anime trending heat-list feature (plan 2026-09-15-anime-trending-heat.md, base eccc741)
Task 1: complete (commits eccc741..0a1b640, review clean: Approved). bangumi_provider feed(trending) -> POST /v0/search/subjects (sort=heat, type=[2], nsfw=false, limit=20, offset paging); parseSearch accepts {data:[...]}; anime_home _perPage 25->20.
  Minor (deferred): test does not assert Content-Type; _perPage=20 may cause one extra fetch for AniList/Jikan when a page returns exactly 20.
ALL TASKS COMPLETE. Next: final whole-branch review.
Final whole-branch review (061c938..0a1b640): 'With fixes'. 1 Important (missing season/today -> GET /calendar regression assertion) + minors (no Content-Type/method assertion; tall-viewport paging stall; no cross-page dedupe).
Fix b41989a: today/season test now asserts path=/calendar + method=GET via recording adapter; trending test asserts method=POST + Content-Type json; deleted unused _FakeAdapter. Re-review 0a1b640..b41989a: Approved.
  Minor (deferred): feed(season) page-1 path only covered indirectly; _perPage=20 may cause one extra fetch for AniList/Jikan on a full 20-item page; tall-viewport (grid doesn't overflow) paging stall possible; no cross-page dedupe in _FeedView._extra (pre-existing).
Anime trending heat-list feature: COMPLETE (061c938..b41989a). Pushed to origin/dev.

## Follow-up: 热门推荐 must match Bangumi website 热度 (2026-09-15)
Root cause: website 热度 = /anime/browser?sort=trends (currently-trending); our API used POST /v0/search/subjects sort=heat (all-time heat). v0 API rejects 'trends' (400 sort not supported); no JSON endpoint exposes it -> scrape website HTML.
Fix 5c60166: BangumiProvider.feed(trending) GETs https://bgm.tv/anime/browser?sort=trends&page=N (browser UA, text/html), new parseBrowserList (ul#browserItemList li.item -> id/h3 a.l/h3 small.grey/img.cover/span.rank/p.rateInfo small.fade/p.info.tip); _https handles protocol-relative //; removed _heatPerPage. Tests: parseBrowserList fixture + feed(trending) request assertions.
  Verified live: page1 = Re:Zero S4 夺还篇, 尼古喵喵, 无职转生 S3, 穹庐下的魔女... (matches website); app screenshot confirmed. 271 tests pass, analyze clean.
  Trade-off: depends on bgm.tv HTML structure (fragile vs JSON API); airDate/episodes best-effort parsed from p.info.tip (detail page still authoritative via API).

## Sidebar + shell transitions feature (plan 2026-09-15-shell-transitions.md, base 36a4b28)
Task 1: complete (commits 36a4b28..0d0c529, review clean: Approved). app_sidebar.dart _SidebarItem: label 13px/w600-w500/height1.4/no letterSpacing; TweenAnimationBuilder 0<->1 (200ms easeInOutCubic) drives line Opacity+scaleY from center and icon/text color lerp; line key ValueKey('sidebar-line'). New test/shell/app_sidebar_test.dart.
  Minor (deferred): first-build no-animation not asserted; color lerp/font inheritance untested; 3px border inset removed so content shifts ~1.5px left.
Task 2: complete (commits 0d0c529..b9f79f8, review clean: Approved). main_shell.dart: IndexedStack -> Stack(fit:expand) of per-page IgnorePointer + AnimatedOpacity(key ValueKey('module-page-'), 250ms easeInOut); all pages stay mounted. New test/shell/main_shell_test.dart (implementer changed pump() -> pump(100ms) to avoid pending dio timers; production matches brief).
  Minor (deferred): test asserts only opacity target (not animation); depends on advancing past network timers; hardcoded 4 pages.
ALL TASKS COMPLETE. Next: final whole-branch review.
Final whole-branch review (c6a1079..b9f79f8): 'With fixes'. 2 Important (both new tests only asserted target/end state, so they could not detect removal of the animations) + minors (3px inset removed; thin font coverage; hardcoded page count; fragile finder; reused line key; StackFit.expand; no TickerMode).
Fix a1ece38: sidebar test asserts mid-flight line opacity (0<t<1) + label style (weight/height/no letterSpacing/no fontFamily); main_shell test asserts AnimatedOpacity duration/curve + mid-flight rendered opacity via inner FadeTransition + scoped sidebar finder; bounded 300ms pump instead of pumpAndSettle (ShimmerLoader never settles). Re-review b9f79f8..a1ece38: Approved.
  Minor (deferred): test couples to AnimatedOpacity->FadeTransition internals; 3px border inset removed (content ~1.5px left, no longer jitters); StackFit.expand vs loose; non-current pages still tick.
Sidebar + shell transitions feature: COMPLETE (c6a1079..a1ece38). Pushed to origin/dev.

## Bug fix: copy_manga 排行 only loaded one row (2026-09-15)
Root cause (probe .superpowers/sdd/copy_manga_probe.dart): the app built ComicSource.categoryOptions as the FIRST option of EVERY categoryComics.optionList group -> [ '', '*datetime_updated', 'male', 'day' ]. copy_manga's categoryComics.load for 排行 expects only the groups shown for that category (audience+date = ['male','day']); with the wrong values the request is audience_type=&date_type=*datetime_updated and the API returns 210. So 排行 parts (今日/本周/本月排行, 6 items = one grid row) could not page into the rank category.
Fix f2218fd: JS finish() now emits per-group {options, showWhen, notShowWhen} (optionGroups); ComicSource parses them + categoryOptionsFor(category) keeps only groups visible for that category (default option, split on '-'); manager.category uses source.categoryOptionsFor(cat). New unit tests (option-group filtering + flat-options fallback).
  Verified: probe now reports options=[male, day] and category default count=30 maxPage=10 (was ERROR 210). 276 tests pass, analyze clean.

## Game module v1 ledger - home browse + detail

Plan: docs/superpowers/plans/2026-09-15-game-module.md
Spec: docs/superpowers/specs/2026-09-15-game-module-design.md
Base commit: bc6ff0e (before Task 1)

Task 1: complete (commits bc6ff0e..83025ef, review clean)
  Minor (deferred): views double parses to null; no container-model tests; GameDetail has no fromJson/toJson.

Task 2: complete (commits 83025ef..29c1b2c, review clean)
  Minor (deferred): constructor-duplicate/empty-sources untested; sources copies per access.

Task 3: complete (commits 29c1b2c..6276962, review clean)
  Minor (deferred): no-posts-warp fallback parses whole doc (plan-mandated, untested); parseCount M/lowercase/garbage + itemCount==11 boundary untested.

Task 4: complete (commits 6276962..9b29830, review clean; justified deviation: check data: before _absUrl)
  Minor (deferred): lazy src=data: placeholder drops real data-src; _valueAfterColon ASCII-colon preference; cover-exclusion/no-p/title-fallback untested.

Task 5: complete (commits 9b29830..60a6f57, review clean)
  Minor (deferred): _get non-200 branch largely unreachable (Dio throws first); error path untested.

Task 6: complete (commits 60a6f57..9f95e4e, review clean)
  Minor (deferred): gameDetailProvider unknown-source guard + gameSourcesProvider untested.

Task 7: complete (commits 9f95e4e..2044588, review clean; justified deviation: byTooltip returns Tooltip not IconButton)
  Minor (deferred): _sourceId hardcoded; no cover-image/error/empty/tap coverage.

Task 8: complete (commits 2044588..d14f427 + registrants 92479fe + fix d14f427, review clean after 1 fix)
  Fix: gallery thumbnails 200x130 -> 200x112.5 (16:9, per human: spec governs).
  Controller: committed regenerated desktop plugin registrants (92479fe) omitted from plan commit list.
  Minor (deferred): launchUrl result/exception ignored; gallery lacks memCacheWidth; viewer uses MaterialPageRoute not smoothRoute; viewer has no DragToMoveArea; date/count formatting untested.

Task 9: complete (commits d14f427..825b0a1, review clean; full suite 295 pass/1 skip, analyze clean)
  Minor (deferred): manual Windows in-app verification outstanding.
ALL 9 TASKS COMPLETE. Next: final whole-branch review.

Final whole-branch review (bc6ff0e..825b0a1): 'With fixes'. 1 Important must-fix (viewer window controls on frameless window) + deferred minors.
Fix wave: cf5569c (DragToMoveArea strip + WindowControls + smoothRoute + memCacheWidth) and d6b390f (optional light foreground/hover colors on WindowControls/WindowButton). Re-review 825b0a1..d6b390f: Ready to merge: Yes.
Game module v1: COMPLETE (bc6ff0e..d6b390f). Pushed to origin/dev; user merges via PR.
  MUST-VERIFY (human, live site): manual Windows run - tab content, section switching, paging, detail fields, gallery viewer, external browser, offline retry; specifically multi-posts-warp scoping on '/' and UTF-8 decode of Chinese.
  Deferred Minors: parseGameList fallback to documentElement; _get non-200 dead branch; _sourceId hardcoded; launchUrl result ignored; views double->null; container-model tests; parseCount M/lowercase/boundary tests; GameDetail fromJson absent; game_home_test lacks chip/card tap; viewer route smoothRoute (ok).


## Game page-size 48/page feature (plan 2026-09-15-game-page-size.md, base 968f464)

Spec: docs/superpowers/specs/2026-09-15-game-page-size-design.md

Task 1: complete (commits 968f464..6444fc8 + corrections bf651d4, 6444fc8; review clean after fixes)
  Fixes: numeric test fixtures + restore numeric /game/(\\d+) regex (bf651d4); later-page failure -> hasMore=false + exception-path tests (6444fc8).
  Minor (deferred): empty-page branch untested; surplus >12/source-page dropped (spec-mandated).
Game page-size 48/page feature: COMPLETE (968f464..6444fc8 + spec clarification). Full suite 300 pass/1 skip, analyze clean.
  MUST-VERIFY (human, live site): game home 48/page, no blank rows, paging, last-page disabled.


## Game card layout feature (plan 2026-09-15-game-card-layout.md, base 1ef9eed)

Spec: docs/superpowers/specs/2026-09-15-game-card-layout-design.md (supersedes the 48/page spec; pageSize 48->24)

Task 1: complete (commits 1ef9eed..2789864 + test hardening 2789864; review clean after 1 fix)
  pageSize 48->24 (2 source pages/app page); game grid 4-col 3:2 via LayoutBuilder mainAxisExtent.
  Fix: test now derives expected cell width from the real surface and measures the rendered cover (was self-fulfilling).
  Minor (deferred): ShimmerLoader spacing mismatch (pre-existing, shared widget, out of scope).
Game card layout feature: COMPLETE (1ef9eed..2789864). Full suite 301 pass/1 skip, analyze clean.
  MUST-VERIFY (human, live site): game home 4-col 3:2 uncropped, 24/page (6 rows), no blank rows, paging, last page disabled.


## Card open-transition feature (plan 2026-09-15-card-open-transition.md, base 3d8c4f4)

Spec: docs/superpowers/specs/2026-09-15-card-open-transition-design.md

Task 1 (novel): complete (commit 3d8c4f4..ec727fd, review clean)
  NovelCard heroTag + HeroMode per tab + explore/favorites/search Hero + smoothRoute; detail cover Hero.
  Minor (deferred): AnimatedBuilder rebuilds per frame (matches anime pattern); no end-to-end tag-pairing test; duplicate grid results would collide.

Task 2 (game): complete (commit ec727fd..4b7e51b, review clean; + fix wave ba19d24, d762bcf, re-review clean)
  GameCard heroTag + home card tag + smoothRoute; detail cover Hero.
  Cross-cutting fix: novel & game detail loading now renders the info card immediately (from the passed title/cover) so the cover Hero exists on frame one and the flight plays on cold opens (anime approach); removed unused ShimmerLoader imports; added loading-state Hero tests.
  Minor (deferred): fabricated empty GameDetail during loading; novel favorite button interactive during loading.
Card open-transition feature: COMPLETE (3d8c4f4..d762bcf + spec update). Full suite 307 pass/1 skip, analyze clean.
  MUST-VERIFY (human, live site): novel/game card -> detail cover flight (cold open), back-flight, no Hero tag collision across novel tabs.


## Nekogal second source feature (plan 2026-09-15-nekogal-source.md, base c29ab9b)

Spec: docs/superpowers/specs/2026-09-15-nekogal-source-design.md

Task 1 (shared paging): complete (commit c29ab9b..e11f36d, review clean)
  game_paging.dart (gamePageSize=24, GameSourcePage, buildGamePage); GalgameZywzSource.browse uses it; galgameZywzPageSize removed.
  Minor (deferred): parse exceptions now swallowed into hasMore=false (spec-level, unavoidable with the fetch callback).

Task 2 (image headers): complete (commit e11f36d..4c6c90f, review clean)
  game_image.dart gameImageHeadersFor(url); 4 call sites updated; removed unused galgamezywz_source imports from game_home/game_detail_page.
  Minor (deferred): duplicated galgamezywz base URL literal; substring 'nekogal' matching (spec-mandated).

Task 3 (NekogalSource): complete (commit 4c6c90f..ceac00d, review clean)
  nekogal_source.dart (parser + source) + parser/source tests; registered in game_providers.
  Minor (deferred): parseNekogalCount '1.2K'->12 (brief-mandated); empty data-src blocks src fallback; date regex needs 2-digit month/day; empty '#' tag.
ALL 3 TASKS COMPLETE. Next: final whole-branch review.

Final whole-branch review (c29ab9b..ceac00d): 'With fixes'. 2 Important (hardcoded source attribution shown on NekoGAL; no two-source coverage) + 1 Minor guard (sourcePageSize divides gamePageSize).
Fix 9b118e4: attribution derived from sourceUrl host; provider test (default manager = [galgamezywz, nekogal]) + home two-source chip/switch test; assert in buildGamePage + rewritten trim test. Re-review ceac00d..9b118e4: Approved.
Nekogal second source feature: COMPLETE (c29ab9b..9b118e4). Full suite 325 pass/1 skip, analyze clean.
  MUST-VERIFY (human, live site): game home shows 2 source chips; NekoGAL sections PC/HH/SR/模拟器 load + page 24; pan.nekogal.top covers load; detail fields (title/cover/paragraphs/screenshots/tags/date) correct; '在原站打开' opens nekogal.
  Deferred Minors: parseNekogalCount '1.2K'->12; empty data-src blocks src fallback; date regex needs 2-digit month/day; empty '#' tag; duplicated base-URL literal; substring 'nekogal' matching; extra['url'] unused.


## Bug fix: nekogal 加载失败 (2026-09-15)
Root cause (probe test/nekogal_probe_test.dart): www.nekogal.com INTERMITTENTLY rejects Dart/BoringSSL TLS handshakes (SSLV3_ALERT_HANDSHAKE_FAILURE, alert 40) - TLS 1.2 works, TLS 1.3 fails on some backends; same URL alternated fail/fail/fail/OK/OK/OK. Dart cannot pin TLS 1.2, so the first source-page fetch threw -> provider error -> 加载失败. galgamezywz unaffected (200).
Fix 8ef0386: NekogalSource._get retries up to 4 attempts (200ms apart) on connection-level DioExceptions (no HTTP response); HTTP status errors are not retried. Regression test uses a flaky adapter (first 2 connection attempts fail).
Live verified: browse(pcgame)=24, browse(pegame)=24, detail(6661) title + 7 paragraphs + tags. Full suite 326 pass/1 skip, analyze clean. Pushed origin/dev.
  New observation (deferred): detail 发布时间 empty (date=null) - the date span exists (title='2026年09月14日 20:56发布') but parseNekogalDetail's '.article-header span' selector doesn't pick it up.

Fix 5665b51 (nekogal detail date): real date span parent is '.px12-sm.muted-2-color.text-ellipsis' (title='2026年09月14日 20:56发布'), NOT '.article-header' - the old fixture mirrored the wrong selector so the test was green while the live site showed no date. Replaced with _findPublishedDate(doc) scanning [title] for /(\\d{4})年(\\d{1,2})月(\\d{1,2})日/; fixture updated to real markup (RED->GREEN). Live verified detail(6661).publishedAt=2026-09-14. Full suite 326 pass/1 skip, analyze clean. Pushed origin/dev.


## Game search feature (plan 2026-09-15-game-search.md, base b4f6d76)

Spec: docs/superpowers/specs/2026-09-15-game-search-design.md

Task 1 (GameSource.search): complete (commit b4f6d76..a0066b5, review clean)
  search on interface + both sources (/?s=<encoded>, reuse parsers, blank->[]); 4 test fakes updated; source search tests.
  Minor (deferred): nekogal blank-keyword short-circuit not directly tested.

Task 2 (shared grid): complete (commit a0066b5..6c68857, review clean)
  game_grid.dart extracted (4-col 3:2 metrics); game_home uses it.

Task 3 (search providers): complete (commit 6c68857..2447927, review clean)
  GameSearchResult + gameSearchTimeout + gameSearchSourceProvider + gameSearchProvider (dedupe/isolation/all-fail).
  Minor (deferred): aggregate blank/empty-source branches + first-wins sourceKey not pinned.

Task 4 (GameSearchPage): complete (commit 2447927..caf6ea5, review clean)
  game_search.dart (search bar + progressive per-source 4-col 3:2 results + heroTag + smoothRoute); 4 tests (added progressive-source test to resolve the brief's unused delay warning).

Task 5 (shell entry): complete (commit caf6ea5..0d90efe, review clean)
  main_shell search button widened to index<=3 -> GameSearchPage; shell test (400ms pump due to DragToMoveArea double-tap timeout).
ALL 5 TASKS COMPLETE. Next: final whole-branch review.


## Game detail source-button feature (plan 2026-09-15-game-detail-source-button.md, base 3667a13)

Spec: docs/superpowers/specs/2026-09-15-game-detail-source-button-design.md


## Content slide-transition feature (plan 2026-09-15-content-slide-transition.md, base a03bd00)

Spec: docs/superpowers/specs/2026-09-15-content-slide-transition-design.md

Task 1 (SlideSwitcher): complete (commit a03bd00..88529ae, review clean; justified deviation: brief's 3rd assertion impossible, fixed to hasRunningAnimations==false + position zero)
  lib/core/widgets/slide_switcher.dart + test.
  Minor (deferred): no outgoing-direction assertion; hasRunningAnimations binding-wide.

Task 2 (game): complete (commit 88529ae..a25a690, review clean after 1 fix)
  Fix a25a690: SlideSwitcher must wrap the WHOLE async.when (was inside data: branch -> unmounted on loading -> no slide); pager is a sibling. Docs 7fe4570 updated spec+plan for game/novel.
  Minor (deferred): pager hidden during loading (matches prior behavior).

Task 3 (novel): complete (commit a25a690..fda1d82, review clean)
  Explore tab: switcher wraps whole async.when (推荐 + group branches); pager sibling outside.
  Minor (deferred): index strides assume page<=100/option<=99.

Task 4 (comic): complete (commit fda1d82..f74cb47, review clean)
  _explore(source, section, part, sourceIndex); switcher wraps whole async.when; _paginationBar outside.
Task 5 (full regression): 344 pass / 1 skip, analyze clean.
ALL TASKS COMPLETE. Next: final whole-branch review.

Final whole-branch review (a03bd00..f74cb47): 'With fixes'. 2 Important (novel 推荐<->分组 didn't slide - branch shape differed; latent duplicate-Hero crash during slide).
Fix 8acccf5: novel _body both branches return Column([Expanded(SlideSwitcher(...)), if(pageData!=null) _pager]); SlideSwitcher layoutBuilder wraps previousChildren in HeroMode(enabled:false); novel_home_pager_test asserts 2 SlideTransitions mid-switch. Docs b00778f synced. Re-review f74cb47..8acccf5: Approved.
Content slide-transition feature: COMPLETE (a03bd00..8acccf5). Full suite 344 pass/1 skip, analyze clean. Pushed origin/dev.
  MUST-VERIFY (human): comic/novel/game - grid slides left/right on source/section/sub-category/page switch; pager stays fixed; no duplicate-Hero crash.
  Deferred Minors: outgoing-direction test; hasRunningAnimations binding-wide; pager hidden during load; packed index assumes <100.


## Settings remove-login feature (plan 2026-09-16-settings-remove-login.md, base 8a1d31a)

Spec: docs/superpowers/specs/2026-09-16-settings-remove-login-design.md

Task 1 (remove settings account section): complete (commit 8a1d31a..e2e374e, review clean)
  settings_page.dart: removed 账号 block + _AccountSection/_AccountSectionState + riverpod/account_service imports; kept 缓存/关于. New test/shell/settings_page_test.dart asserts login UI gone + sections present. Full suite 345 pass/1 skip, analyze clean.
Settings remove-login feature: COMPLETE (8a1d31a..e2e374e). Pushed origin/dev.
  Minor (deferred): test's removal failure mode is a ProviderScope exception rather than a clean expect.


## Android playback adaptation (plan 2026-09-16-android-playback.md, base a86615f)

Spec: docs/superpowers/specs/2026-09-16-android-playback-design.md

Task 1 (add flutter_inappwebview): complete (commits a86615f..b1b4511, review clean)
  pubspec.yaml/.lock add flutter_inappwebview ^6.1.5; b1b4511 commits regenerated Windows+macOS plugin registrants (now register flutter_inappwebview_windows). APK 127.3MB built, Windows release build OK, analyze clean.
  Minor (deferred): b1b4511 message says build(windows) but also touched macos; macOS registrant committed without a macOS build; flutter_inappwebview_windows adds a second WebView2 wrapper on Windows (no behavioural smoke test yet).
Task 2 (extract looksLikeMediaUrl into HeadlessBrowser abstraction): complete (commit b1b4511..5e7a795, review clean)
  New lib/core/video/headless_browser.dart (abstract class + top-level looksLikeMediaUrl); stream_resolver.dart points at the shared helper, static removed; test/core/video/stream_resolver_test.dart -> headless_browser_test.dart. 345 pass / 1 skip, analyze clean.
  Minor (deferred): test does not cover the Uri.tryParse(...) == null fallback branch (pre-existing gap).
Task 3 (Windows impl + factory, switch callers): complete (commits 5e7a795..590c509, review clean after fix)
  New headless_browser_windows.dart (wraps webview_windows HeadlessWebview), temporary Android stub, createHeadlessBrowser factory; StreamResolver + WebviewScraper rewritten onto the abstraction. 346 pass / 1 skip, analyze clean, Windows release build OK, app launches (smoke).
  Fix 590c509 (human ruling): resolve no longer blocks on navigation - load is fired concurrently so timeout still bounds the whole operation (was plan-mandated 15s nav wait + 30s media wait = ~45s).
  Minor (deferred): abstraction imports its own implementations (import cycle; factory file would be cleaner); load() silently no-ops when _webview == null; _emit filtering untested; Android stub's mediaUrls contract inconsistent (replaced in Task 4); load errors swallowed without debugPrint.
  MUST-VERIFY (human): Windows interactive anime playback still resolves/starts after the refactor.
Task 4 (android headless browser): complete (commit 590c509..7945a97, review clean)
  headless_browser_android.dart implements HeadlessBrowser with flutter_inappwebview HeadlessInAppWebView + shouldInterceptRequest + evaluateJavascript. 347 pass / 1 skip, analyze clean, APK built + installed on emulator.
  EMULATOR VERIFICATION (controller-run, emulator libiko_test):
    PASS - app runs; rule-source search returned results for 七色番/MXdm/akianime/moonci/gugu3 (proves page render + evaluateJavascript on Android).
    PASS - source episodes load (AGE动漫 第01-11集, gimy 3 eps).
    PASS - stream resolution: logcat "[StreamResolver] resolved=https://cdn.yzzyvip-29.com/.../index.m3u8" via shouldInterceptRequest; player page opened and media_kit created a 1920x1080 surface.
    LIMIT - mpv then failed to open the CDN .ts segment in the emulator ("Failed to open .../3000k/hls/*.ts") - emulator network, not the resolution code.
    LIMIT - agedm.io's player never emitted a media request headlessly (source-specific; other sources work).
  Minor (deferred): start() has no re-entry guard (leaks a previous HeadlessInAppWebView); eval() does not catch JS errors; dispose() during an in-flight load leaves the completer to time out; the Android factory test only exercises pre-start no-op paths.
  MUST-VERIFY (human): actual video playback on a real phone (emulator CDN fetch failed).
Task 5 (android touch controls): complete (commit 7945a97..4a98de8, review clean)
  video_player_page.dart: isDesktop picks MaterialDesktopVideoControlsTheme/Controls vs MaterialVideoControlsTheme/Controls; _desktopControlsTheme body unchanged; _video() helper added. 347 pass / 1 skip, analyze clean, APK + Windows builds succeed, APK installs on emulator.
  Minor (deferred): title Text + episode-toggle button duplicated between the two theme builders (plan-mandated); mobile title fontSize 15 vs desktop 16 (plan-mandated).
  NOT DONE (controller, environment): interactive touch-controls check in the player - reaching the player needs a successful resolve, and only gimy's player emitted a media request while the emulator cannot fetch the media CDN. Structural verification (reviewer) + both builds stand in.
  MUST-VERIFY (human): touch controls (tap toggle, fullscreen rotation, episode panel) in the player on a real phone.
Task 6 (end-to-end verification): covered by the Task 4 emulator run (rule-source search + episodes + stream resolution all exercised on Android).
Final whole-branch review (a86615f..4a98de8): verdict "With fixes".
  Fix 60088c8: added looksLikeMediaResponse + injected mediaSniffer JS (fetch/XHR/HTMLMediaElement.src -> addJavaScriptHandler) for extension-less HLS; StreamResolver now logs load failures and completes null immediately.
  Fix 79899f8: fetch hook now chains the response and reads its content-type; HTMLMediaElement.src descriptor keeps enumerable.
  Re-review: Finding B fully resolved; Finding A resolved after 79899f8 (controller-verified the applied code).
  Deferred Minors for triage: import cycle (factory file would be cleaner); eval() does not honour its "null on failure" doc; load() silently no-ops when not started; Android start() has no re-entry guard; dispose() during in-flight load leaves the completer to time out; the "usable Android" test is vacuous; createHeadlessBrowser maps Linux/macOS to the Windows impl; flutter_inappwebview_windows adds a second unused WebView2 wrapper on Windows; b1b4511 message scope; duplicated player theme UI (plan-mandated); Uri.tryParse null branch untested; mp2t MIME can make a bare .ts segment a resolve candidate.
Android playback adaptation: implementation COMPLETE (a86615f..79899f8). 349 pass / 1 skip, analyze clean, APK + Windows builds succeed.
  MUST-VERIFY (human): real-phone playback (emulator could not fetch the media CDN) and the touch controls in the player.
  MUST-VERIFY (human): Windows interactive anime playback after the HeadlessBrowser refactor.

## Mobile UI redesign (plan 2026-09-16-mobile-ui-redesign.md, base 79899f8)

Spec: docs/superpowers/specs/2026-09-16-mobile-ui-redesign-design.md

UI Task 1 (add flutter_staggered_grid_view ^0.7.0): complete (commit 79899f8..ff84829, review clean)
  Both Android + Windows release builds succeed; no Dart changed.
  Minor (deferred): the package is in maintenance-only stasis (~3 years old).
UI Task 2 (CoverRatioCache): complete (commit ff84829..4ac41fe, review clean)
  lib/core/images/cover_ratio_cache.dart + 4 tests. Memory-before-prefs, swallows prefs failures, rejects non-finite/non-positive. 353 pass / 1 skip, analyze clean.
  Minor (deferred): unbounded growth (no eviction - brief-scoped out); read-path validation untested; empty-url short-circuit untested; concurrent remember can persist out of order; stored-but-unusable pref is not deleted.
UI Task 3 (RatioCover widget): complete (commits 4ac41fe..b0bf3ed, review clean after fix)
  lib/core/widgets/ratio_cover.dart: resolves the ratio (cache first, else measures the decoded image), animates between them, plain image on desktop (no AspectRatio, cache untouched). 357 pass / 1 skip, analyze clean.
  Fix b0bf3ed: added didUpdateWidget (url/enabled change resets + re-measures - unkeyed element reuse was showing the previous cover's ratio); one shared ImageProvider for display+measurement (was double-decoding full-size).
  Minor (deferred): didUpdateWidget ignores httpHeaders/cache changes; enabled-toggle briefly re-animates from fallback; cache write runs before the mounted check; covers are now cached on disk at 400px under a separate key (non-destructive).
UI Task 4 (AdaptiveGridView / SliverAdaptiveGrid): complete (commits b0bf3ed..6330ad5, review clean after fix)
  lib/core/widgets/adaptive_grid.dart + 4 tests. Mobile = SliverMasonryGrid/MasonryGridView with the caller's mobileColumns; desktop = the existing fixed grid (default 6 cols, 20/16 spacing, aspect 0.60 overridable). 361 pass / 1 skip, analyze clean.
  Fix 6330ad5 (review Critical): desktop columns were hardcoded to 6, which would have changed anime_search's 5-column desktop grid - added desktopColumns (default 6). anime_search must pass desktopColumns: 5 in UI Task 6.
  Minor (deferred): the class doc still says "6-column grid"; spacing has no override (matches every current grid).
UI Task 5 (mobile shell / bottom bar): complete (commit 6330ad5..87627f5, review clean)
  lib/shell/app_bottom_bar.dart (translucent GlassSurface, 4 modules, blue selection, SafeArea) + main_shell.dart platform split (mobile: no sidebar, no toggle, bottomNavigationBar; desktop unchanged) + test. 362 pass / 1 skip, analyze clean, APK built+installed; emulator confirms sidebar gone, bar translucent, selection switches pages.
  Minor (deferred): accent/fg colours duplicated vs main_shell; SidebarState still constructed on mobile (wasted prefs read); MainShell mobile wiring untested; initially-selected item animates from grey.
UI Task 6 (anime module grids): complete (commit 87627f5..495a498, review clean)
  WorkCard uses RatioCover (desktop keeps Expanded+Hero, mobile intrinsic height); anime_home/follow/history/search use SliverAdaptiveGrid/AdaptiveGridView (3 mobile columns; search passes desktopColumns:5); ShimmerLoader gained mobileColumns. 362 pass / 1 skip, analyze clean; emulator shows 3-column masonry.
  Deviations (correct): anime_follow's original padding (16,16,16,24) preserved explicitly (the brief omitted it -> would have regressed Windows by 8px).
  Concerns: only an android-x64 release APK could be built this session (host OOM with the emulator running) - the universal APK is unverified; follow/history/search screens not screenshotted (empty tabs, top-bar search tap unresponsive under synthetic input).
  Minor (deferred): WorkCard desktop nests ClipRRect>RepaintBoundary (was RepaintBoundary>ClipRRect; equivalent); shimmer mobile is a fixed-ratio grid while content is masonry.
UI Task 7 (comic + novel grids): complete (commits 495a498..00f09d2, review clean after fix)
  ComicCard/NovelCard use RatioCover; all comic/novel grids -> AdaptiveGridView (3 mobile cols; novels desktopAspectRatio 0.58; every desktop padding preserved); shimmer call sites pass mobileColumns:3. 362 pass / 1 skip, analyze clean; comic tab verified 3-column masonry on the emulator (via a temporary probe source, since comic ships with no default source).
  Fix 00f09d2 (review Important): ComicCard's cover fade had silently dropped 200ms -> Duration.zero on desktop - restored.
  Minor (deferred): novel_home:242 shimmer omits mobileColumns (defaults to 3); report overstated the shimmer coverage.
UI Task 8 (game module): complete (commit 00f09d2..7d81ca2, review clean)
  GameCard uses RatioCover (fallbackRatio 3/2, headers, Duration.zero, Hero kept); game_home/game_search keep the original desktop delegate (4 cols, mainAxisExtent) and use AdaptiveGridView(mobileColumns:1) on mobile. 362 pass / 1 skip, analyze clean; emulator shows one full-width card per row.
  Minor (deferred): gameCell is block-bodied in search vs expression-bodied in home.

UI Task 9 (verification): controller-run on the emulator libiko_test (Android 15).
  PASS - bottom bar: 4 equal items (uiautomator y=2098..2274), tapping switches modules, selected item blue.
  PASS - game tab: one full-width card per row, heights follow the cover.
  PASS - novel tab: 3-column masonry, cover-driven heights.
  PASS - anime tab (Task 6): 3-column masonry.
  PASS - no Flutter layout/overflow exceptions in logcat.
  FINDING (pre-existing, now more visible): the mobile top bar has no top safe-area padding, so the app title/clock share a row and the search button sits in the status-bar band - synthetic taps on it do not navigate (blocked three subagent verifications). Needs a decision.
  NOT DONE: Windows interactive regression (build + launch smoke only).
Final whole-branch review (79899f8..7d81ca2): verdict "With fixes".
  Fix 025872b: mobile top bar now pads by the status-bar inset inside the GlassSurface (search was unreachable under the status bar - it blocked 3 on-device verifications); game loading skeletons now use mobileColumns:1 with a landscape mobile aspect ratio.
  VERIFIED: search button bounds [833,136][965,267] sit just below the status bar [0,0][1080,136]; tapping (899,201) opened the anime search page. 362 pass / 1 skip, analyze clean.
  Deferred Minors for triage: CoverRatioCache never evicts (LRU cap suggested); RatioCover.didUpdateWidget ignores httpHeaders/cache; cache write before the mounted check; comic_detail_page's shared ShimmerLoader now shows 3 columns on mobile (skeleton-only, page was a non-goal); novel_home:242 shimmer omits mobileColumns; adaptive_grid doc says "6-column grid"; AppBottomBar duplicates colours + initially-selected item animates from grey; SidebarState still constructed on mobile; no MainShell mobile test; CoverRatioCache edge cases untested; flutter_staggered_grid_view 0.7.0 maintenance-only; gameCell style asymmetry; all four cards now render Image+CachedNetworkImageProvider instead of CachedNetworkImage (so "Windows byte-for-byte" should read "visually unchanged").
Mobile UI redesign: implementation COMPLETE (79899f8..025872b). 362 pass / 1 skip, analyze clean, Android + Windows builds OK.
  MUST-VERIFY (human): real-phone look (status bar/notch, masonry heights, bottom bar feel); the comic/novel/anime search pages on a real phone; Windows visual regression.

## Android polish + builtin comic sources + M3 migration (2026-09-17)

Spec: docs/superpowers/specs/2026-09-17-android-polish-manga-m3-design.md
Plans (in execution order):
- A: docs/superpowers/plans/2026-09-17-android-top-bar.md (base 025872b, 4 tasks)
- B: docs/superpowers/plans/2026-09-17-android-playback-fix.md (5 tasks)
- C: docs/superpowers/plans/2026-09-17-builtin-comic-sources.md (6 tasks)
- D: docs/superpowers/plans/2026-09-17-material3-migration.md (7 tasks)

A Task 1 (window controls guard): complete (commit 025872b..831afde, review clean)
A Task 2 (detail-page top bars): complete (commit 831afde..3cd506c, review clean)
A Task 3 (reader-page top bars): complete (commit 3cd506c..3a03726, review clean)
  DONE_WITH_CONCERNS: `novel_reader_page.dart:188` `_illustrationHeight` still subtracts a fixed 56 (not the mobile bar's +inset) — cosmetic/scrollable, out of scope, deferred.
A Task 4 (emulator verification): controller-run. x64 release APK built (89.4MB), installed, launched; no Flutter exceptions in logcat. Screenshot at .superpowers/sdd/a-task4-main.png.
  MUST-VERIFY (human): detail/reader pages show no window buttons and clear the status bar.
PLAN A: implementation COMPLETE (025872b..3a03726).

B Task 1 (cleartext config): complete (commit 3a03726..5805a92, review clean). Debug APK built.
B Task 2 (android headless browser): complete (commit 5805a92..cd21309, review clean).
  Minor (deferred, plan-level): `forMainFrameOnly: false` is a no-op on Android (doc scopes it to iOS/macOS); Android already injects into all frames, so the meaningful fix is `mixedContentMode`.
B Task 3 (preserve URL scheme, TDD): complete (commit cd21309..b95b146, review clean). RED→GREEN evidence in report; 29/29 video tests.
  Minor (deferred): guard narrowed `startsWith('http')` → explicit `http://`/`https://` (a relative `httpsomething` now joins the base — arguably more correct); `GimySource._abs` has no direct test.
B Task 4 (reuse resolved URL): complete (commit b95b146..1e18328, review clean). One-shot flag logic verified correct.
B Task 5 (android playback verification): controller-run smoke — x64 release APK built + installed with all B changes.
  MUST-VERIFY (human): actual playback from AGE动漫/Gimy/a rule source, one resolve per initial episode; Windows playback regression. (Prior session: the emulator cannot fetch the media CDN, so playback is not automatable here.)
PLAN B: implementation COMPLETE (3a03726..1e18328).

C Task 1 (bundle sources): complete (commit 1e18328..f35ad93, review clean). 6 vendored Venera sources + index.json + pubspec asset entry; debug APK built.
C Task 2 (BuiltinSourceInstaller, TDD): complete (commit f35ad93..14616ca, review clean). 4/4 tests, real filesystem I/O.
  Minor (deferred): unvalidated manifest `fileName` joined into the path (trusted asset, low risk); no test for malformed manifest / marker-unwritten-on-failure.
C Task 3 (wire installer): complete (commit 14616ca..cd3f0e8, review clean). 366 pass / 1 skip.
C Task 4 (JS bridge additions): complete (commit cd3f0e8..0e88ddf, review clean). UI global, bare-domain cookies, ES2022 shims, subTitle fallback, app messenger key.
  Minor (deferred): `replaceAll` regex shim mishandles capture groups (only string-arg `replaceAll` is used by the 6 bundled sources — verified); showLoading/cancelLoading inert.
C Task 5 (verify sources on Android): controller-run on emulator-5554 (fresh install clears comic_source/, proxy 10.0.2.2:10888).
  PASS - all 6 built-ins install and appear (再漫画/包子漫画/Komiic/MangaDex/漫画柜/拷贝漫画).
  PASS - 再漫画 FULL pipeline: explore grid (real covers) -> detail (title/author/tags/desc/3 chapters) -> reader (real manhwa pages, "1 / 5"). Screenshots c5-*.png.
  PASS - 包子漫画 explore (熱門漫畫/推薦國漫/韓漫/日漫 + real covers); Komiic explore (real covers); MangaDex explore (Popular/Recent/Updated + real covers).
  PARTIAL - 漫画柜 explore: titles load, some covers render as letter placeholders (image hotlink protection).
  PARTIAL - 拷贝漫画 explore: only 3 items then blank (its 推荐 section is sparse/paged).
  No Flutter exceptions in logcat throughout.
  MUST-VERIFY (human): detail/chapter/reader for 包子漫画/Komiic/MangaDex/漫画柜/拷贝漫画; the 漫画柜 cover placeholders and 拷贝漫画 sparse explore.
C Task 6 (full verification): controller-run. `flutter analyze` clean; `flutter test` 366 pass / 1 skip; `flutter build windows --release` OK.
  MUST-VERIFY (human): Windows in-app source list (installer should run there too) + a Windows source search.
PLAN C: implementation COMPLETE (1e18328..0e88ddf).

D Task 1 (central theme): complete (commit 0e88ddf..bd0fec7, review clean). `lib/core/theme/app_theme.dart` + main.dart uses `buildAppTheme()`.
  Watch (D7): global FilledButton is now `Size(0,40)` intrinsic (was `Size(infinity,48)`); unstyled full-width FilledButtons (comic_reader 下一章/重试, comic_source buttons) may no longer stretch. Intentional (infinite width in a Row caused the prior pager freeze) — verify visually and wrap if needed.
D Task 2 (selection widgets): complete (commit bd0fec7..54f5589, review clean). PillButton tonal; ChipBar/TabStrip on theme colors. Justified deviation: omitted unused AppRadii import in tab_strip.
D Task 3 (shell): complete (commit 54f5589..299b628, review clean). Bottom bar/sidebar/main_shell on theme colors; sidebar text metrics preserved. Title-bar constants deferred to D6.
D Task 4 (search bars): complete (commit 299b628..04d6503, review clean). 4 files; only colors changed.
  Minor (deferred): close/clear icon still onSurface@30%; search-page Scaffold bg + progress track still hard-coded (outside the brief's mapping).
D Task 5 (detail-page buttons): complete (commit 04d6503..7bd4e64, review clean). Toggle buttons theme-derived; action buttons inherit theme.
D Task 6 (brand-color sweep): complete (commit 7bd4e64..d9633d2, review clean). 16 files; four constants replaced with cs reads, semantic colors preserved.
  Minor (deferred): `work_card.dart` still hard-codes `_accent` (outside brief's file list); novel_detail `_tag` inline cs; comic_reader `_openChapterList` captures page cs for the sheet.
D Task 7 (verify both platforms): controller-run. Android x64 release APK built + installed; anime home / comic home / comic detail render cleanly after the restyle (no overflow/exception in logcat; screenshots d7-*.png). Windows release built.
  MUST-VERIFY (human): Windows visual regression; full M3 look on a real phone.
PLAN D: implementation COMPLETE (0e88ddf..d9633d2).

Final whole-branch review (025872b..d9633d2): "With fixes".
  Important: (1) `forMainFrameOnly:false` is inert on Android (plan-level) -> the iframe HLS-sniffing goal is UNPROVEN; needs the plan's manual emulator playback check. (2) global FilledButton width regression (Size(infinity,48)->Size(0,40)). (3) page background inconsistency (theme surface vs hard-coded #F2F2F7).
  Minor: work_card still hard-codes _accent; novel_reader _illustrationHeight fixed 56; #E8F0FE tags; installer fileName unvalidated; replaceAll regex shim; cookie-key change; missing tests for ui bridge/cookie/malformed manifest; vendored JS has no license header.
Fix cdd4e89 (re-review clean): wrapped 下一章/重试/登录 in SizedBox(width: double.infinity); 9 page Scaffolds now use cs.surface.
FEATURE SET COMPLETE (025872b..cdd4e89). Pushed to origin/dev.

## Final-review minors (plan 2026-09-17-final-review-minors.md, base cdd4e89)

F Task 1 (UI color leftovers): complete (commit cdd4e89..4bd7505). work_card theme colors; 4 `#E8F0FE` -> secondaryContainer/onSecondaryContainer; search clear icons -> onSurfaceVariant; novel_reader `_illustrationHeight` accounts for insets.
F Task 2 (installer hardening, TDD): complete (commit 4bd7505..47f654d). `p.basename(fileName) != fileName` guard; malformed-manifest + failed-copy tests.
F Task 3 (JS bridge fixes + tests + provenance): complete (commit 47f654d..fb39298). `replaceAll` regex branch fixed; `normalizeCookieKey` public + handles paths; `_cookie` legacy raw-key fallback; `cookie_key_test`; `app_messenger_test`; builtin README (licensing caveat).
F Task 4 (review): Approved. 1 Important (escape-test assertions were vacuous) fixed in cb376cf with guard-removed FAIL / guard-restored PASS evidence.
MINORS BATCH COMPLETE (cdd4e89..cb376cf). `flutter analyze` clean; 371 pass / 1 skip. Pushed origin/dev.
  Accepted/remaining: `forMainFrameOnly` inert (plan-level; Android playback unproven - emulator can't fetch the media CDN); `replaceAll` string-branch doesn't expand `$&`; `_cookie` raw-key fallback untested (qjs-only); vendored JS licensing unconfirmed; `work_card` pastel placeholder palette left as-is.

## Anime UI + Playback Round 2 (2026-09-17)

Spec: docs/superpowers/specs/2026-09-17-anime-ui-playback-round2-design.md
Plan: docs/superpowers/plans/2026-09-17-anime-ui-playback-round2.md (base 1f26c67, 6 tasks)
Root cause (systematic debugging, emulator): `[StreamResolver] resolved=...index.m3u8` then mpv `HTTP error 403 Forbidden` with `http-header-fields=null`; the WebView's successful m3u8 request carried `Referer: https://bf.sbbzy.com/`, an Android WebView UA and `Origin`. Fix = replay those headers in media_kit.

R2 Task 1 (media request headers): complete (commit 1f26c67..7224941, review clean).
  `MediaCandidate` + `playerHeadersFrom`; `HeadlessBrowser.mediaUrls` -> `Stream<MediaCandidate>`; Android captures request headers (Windows emits empty); `StreamResolver.resolve` -> `MediaCandidate?`; player passes `httpHeaders`. 374 pass / 1 skip.
  Justified deviation: `request.headers ?? const {}` (nullable).
R2 Task 2 (remove 今日放送): complete (commits 7224941..fc7d2c8, review clean). Plan gap: `anime_home_test.dart` asserted the old 5-tab list; fixed in fc7d2c8.
R2 Task 3 (aligned mobile grids): complete (commits fc7d2c8..6560495, review clean after 1 fix).
  Plan gaps: `adaptive_grid_test.dart` asserted masonry (fixed 8a60ed4); review found the sliver branch double-subtracted horizontal padding (fixed 6560495, test pins mainAxisExtent values). `flutter_staggered_grid_view` is now an unused dependency.
R2 Task 4 (two-column buttons): complete (commit 6560495..f2e44a3, review clean). `TwoColumnButtonGrid` + full-width `PillButton`; wired anime/comic/novel. 375 pass / 1 skip.
  Minor (deferred): test doesn't assert the odd trailing child's width.
R2 Task 5 (bottom bar indicator): complete (commit f2e44a3..58bbd09, review clean). Glass shell kept; 200ms capsule + color animation.
  Minor (deferred): transparent->secondaryContainer lerp passes through a dark tint; mid-animation reverse snaps.
R2 Task 6 (verify): controller-run on emulator-5554 (fresh install, proxy set).
  PASS - anime home has 4 tabs (no 今日放送); covers strictly aligned per row (top/bottom edges match); titles 2-line ellipsis; bottom bar 4 items with a lavender capsule on the selected icon.
  PASS - detail page episodes render as two equal-width columns (435px each).
  PASS - PLAYBACK FIXED: gimy `resolved=...index.m3u8`, NO 403 anywhere, player progresses (00:56 -> 01:21) and audio started; video black only due to the emulator's EGL/SW-rendering limitation.
  Gates: analyze clean; 375 pass / 1 skip; Windows release builds.
  MUST-VERIFY (human): Windows interactive regression (grid/buttons/playback) and real-phone video rendering.
R2 final whole-branch review (1f26c67..58bbd09): "With fixes".
  Important: (1) `TwoColumnButtonGrid` stretched buttons to half a wide desktop window; (2) the bottom-bar capsule had no test.
  Minor: `flutter_staggered_grid_view` now unused; first-candidate-wins can drop headers for extension-less HLS; `CoverRatioCache` dead in prod; `.superpowers/` tracked despite gitignore; grid half-width rounding; history title extent metric-dependent; grid test gaps.
Fix 964e5d9 (re-review clean): grid capped at 420 + left-aligned; capsule keyed + animation test added.
R2 COMPLETE (1f26c67..964e5d9). analyze clean; 377 pass / 1 skip; Android + Windows builds. Pushed origin/dev.

## Anime UI + Playback Round 3 (2026-09-17)

Spec: docs/superpowers/specs/2026-09-17-anime-ui-playback-round3-design.md
Plan: docs/superpowers/plans/2026-09-17-anime-ui-playback-round3.md (base 964e5d9, 8 tasks)
Root cause (emulator, systematic debugging): rule-source play page `7sefun.top/vodplay/...` redirects a MOBILE WebView UA to `/app/android.php` -> nothing sniffed -> `[StreamResolver] TIMEOUT`. `StreamResolver` started the browser with no UA (Android default = mobile); the scraper uses the desktop `kBrowserUserAgent`, and Windows' WebView defaults to desktop. Fix = pass `kBrowserUserAgent` in the resolver.

R3 Task 1 (playback desktop UA): complete (commit 964e5d9..3619f46, review clean). Only `stream_resolver.dart` changed (diagnostics removal left the android file identical to HEAD).
R3 Task 2 (anime TabStrip): complete (commit 3619f46..ce09870, review clean). Plan gap again: `anime_home_test.dart` read `Tab` widgets; updated to read `TabStrip` Text labels.
R3 Task 3 (lighter-blue theme): complete (commit ce09870..6109eea, review clean). Seed #3B9EFF, scaffold #F2F7FF.
R3 Task 4 (cover decode size): complete (commits 6109eea..6800069, review clean after 1 fix).
  `RatioCover` decodes at layoutWidth x DPR (clamp 200-1600). Review found `setState`-during-build on cached images; fixed 6800069 (defer via post-frame callback). 378 pass / 1 skip.
R3 Task 5 (content-area swipe): complete (commit 6800069..f38e223, review clean). Comic part / novel option step on fling; falls through to TabBarView when no deeper row. Justified deviation: also wrapped the novel home branch in a null-handler GestureDetector to preserve the 推荐↔分组 slide.
  Minor (deferred): no automated test for the swipe semantics.
R3 Task 6 (tonal pager): complete (commits f38e223..8cd1bd2, review clean). Shared `PagerBar`; wired comic/novel/game. Plan gap: `game_home_test.dart` asserted the old IconButton; fixed 8cd1bd2 (find.descendant InkWell.onTap). 378 pass / 1 skip.
R3 Task 7 (bottom-bar capsule): complete (commit 8cd1bd2..ed6bd63, review clean). Capsule wraps icon+label, centred; test now decoration-based.
  Minor (deferred): tap target ~60.4px (margin shrinks it); large textScale overflow unguarded.
R3 Task 8 (verify): controller-run on emulator-5554.
  PASS - playback: 七色番 (rule) resolves in <1s (NO timeout) and the player initializes (1920x1080); gimy resolves. The UA fix is confirmed. Video black = emulator SW rendering.
  PARTIAL - gimy: resolves but media_kit fails to open the HLS sub-playlist (`.../3000k/hls/mixed.m3u8`) - downstream media_kit/CDN issue, not the resolver.
  PASS - UI: crisp TabStrip tabs; pale-blue background; sharp 3:2 game covers; comic swipe changes the deepest chip row; tonal pager; capsule wraps icon+label centred.
  Gates: analyze clean; 378 pass / 1 skip; Android + Windows builds.
R3 final whole-branch review (964e5d9..b236469): "With fixes".
  Important: (1) `StreamResolver` ignored the per-rule `userAgent`; (2) `RatioCover` decode width churned during Hero flights/resizes.
  Minor: dead novel gesture wrapper; velocity-only swipe; no swipe test; PagerBar tap targets 40x32; capsule overflow at large text scale; RatioCover micro-inefficiencies; test gaps; sniffer emits header-less candidates (may explain the gimy HLS failure).
Fix cd0bd5e (re-review clean): `VideoEpisode.userAgent` threaded through both resolve call sites; decode width bucketed to 128px.
R3 COMPLETE (964e5d9..cd0bd5e). analyze clean; 378 pass / 1 skip; Android + Windows builds. Pushed origin/dev.

## Round 4 (2026-09-17)

Spec: docs/superpowers/specs/2026-09-17-anime-ui-sources-round4-design.md
Plan: docs/superpowers/plans/2026-09-17-anime-ui-sources-round4.md (base cd0bd5e, 7 tasks)

R4 Task 1 (lighten palette): complete (commit cd0bd5e..0aed11e, review clean). Seed #6BB6FF, background #EAF3FF.
R4 Task 2 (bottom-bar capsule): complete (commit 0aed11e..24ae559, review clean). Item padding h8; capsule h10/v2.
R4 Task 3 (player controls lift): complete (commit 24ae559..8f18de2, review clean). bottomButtonBarMargin bottom 24.
R4 Task 4 (pager persistence): complete (commits 8f18de2..3add3fc, review clean after 1 fix). `_lastPage`/`_lastHasMore` cache; swipe handlers clear it too.
R4 Task 5 (settings hub + source pages): complete (commit 3add3fc..ed4d0b1, review clean). `RuleStore.remove`; top-bar settings button; SettingsPage hub → SourceHubPage → AnimeSourcePage (import/delete) / ComicSourcePage / read-only Novel+Game; comic gear removed.
  Minor (deferred): `_remove` lacks a mounted guard/try-catch; no delete confirmation; no tests for the new pages.
R4 Task 6 (add kazumi rules): complete (commit ed4d0b1..a262db7, review clean). Added ezdmw/aafun/DM84/xfdmneo/baimao (10 built-ins); sorani dropped (API-mode, unsupported). rule_store_test updated.
R4 Task 7 (verify + prune): controller-run on emulator-5554.
  UI PASS: palette #EAF3FF; small/spaced capsule; pager stays visible while paging; settings hub + 4 module pages (anime import/delete, comic manage, novel/game read-only).
  Source audit (single title 無職転生III): moonci resolved+played; baimao resolved (player error `tcp: ffurl_read`); gugu3 TIMEOUT; AGE动漫 episodes failed; 7 others had no search results for that title (catalog difference, inconclusive).
R4 final whole-branch review (cd0bd5e..2dfd4d6): "With fixes".
  Important: aafun invalid chapterRoads; ezdmw incompatible selector; new rules not end-to-end verified; pager cache stale on error; missing regression tests.
Fix a861382 (re-review clean): dropped aafun+ezdmw (8 built-ins, test updated); pager cache cleared on error + next disabled while loading.
R4 COMPLETE (cd0bd5e..a861382). analyze clean; 378 pass / 1 skip; Android + Windows builds. Pushed origin/dev.

## Round 5 (2026-09-17)

Spec: docs/superpowers/specs/2026-09-17-anime-sources-round5-design.md
Plan: docs/superpowers/plans/2026-09-17-anime-sources-round5.md (base a861382, 6 tasks)

R5 Task 1 (best-match per source): complete (commit a861382..e08212e, review clean). `title_match.dart` (normalize + bigram Dice); detail page one row per source + expandable 更多结果. 381 pass / 1 skip.
R5 Task 2 (all chapter roads): complete (commit e08212e..8394ad2, review clean). `buildEpisodesScript` iterates all roads, 线路N prefix. 382 pass / 1 skip. (xpath_js_test + rule_source_test updated.)
R5 Task 3 (referer header): complete (commit 8394ad2..687ee70, review clean). SourceRule/VideoEpisode.referer; player merges UA+Referer+sniffed headers. 383 pass / 1 skip.
R5 Task 4 (legacy iframe parser): complete (commit 687ee70..f47a6c6, review clean). `useLegacyParser` -> `StreamResolver(legacy:)` -> `kLegacyIframeScript` via `HeadlessBrowser.start(extraScript:)`. Windows legacy is inert (no mediaSniffer handler) - documented.
  Minor (deferred): `start` doc says "document start" unconditionally (Windows differs); script has no Windows note.
R5 Task 5 (API mode): complete (commits f47a6c6..37b27d0, review clean after 1 fix). `searchMode/chapterMode=api` + configs; `api_rule.dart` (restricted JSONPath, episodePage template, dio client); routing by mode. Review fix: nested road names + fake-dio tests. 393 pass / 1 skip.
R5 Task 6 (verify + bundle sorani): controller-run on emulator-5554.
  PASS - detail page: one row per source (無職転生III 共4条 / BLEACH 共8条); 更多结果 works (gimy 2 alternatives).
  PASS - multi-road: moonci/xfdmneo show 线路1/线路2 episode prefixes.
  PASS - legacy xfdmneo: search/episodes/playback OK (`resolved=...暗黑01.mp4`, played 00:01/23:45).
  PASS - no HTTP 403 anywhere. UI (palette/bottom bar/seek bar/settings) PASS.
  API mode: engine unit-tested; bundled `sorani.json` (9 built-ins) so the path is now live-verifiable.
R5 COMPLETE (a861382..560cf84). analyze clean; 393 pass / 1 skip; Android + Windows builds. Pushed origin/dev.
  MUST-VERIFY (human): real-phone playback; live sorani (api) search/episodes; per-source reliability with matching titles (gimy/7sefun/DM84/MXdm/akianime had no results for the test titles - catalog differences).
  Deferred: antiCrawler/captcha (5 catalog rules); usePost (2 deprecated rules); Windows legacy parser inert (no mediaSniffer handler); `start` doc says document-start unconditionally.

## Round 6 (2026-09-18)

Spec: docs/superpowers/specs/2026-09-18-comic-login-sources-design.md
Plan: docs/superpowers/plans/2026-09-18-comic-login-sources.md (base 560cf84, 4 tasks)

R6 Task 1 (bundle picacg/jm/ehentai): complete (commit 560cf84..579b722, review clean). Manifest version 1->2, 9 built-in comic sources.
R6 Task 2 (login provider + shared dialog): complete (commit 579b722..2db0d1d, review clean). `comicLoginProvider`; `ComicAccountDialog` extracted and reused.
R6 Task 3 (detail login prompt): complete (commit 2db0d1d..1a71075, review clean). Error state shows 该源需要登录/去登录 when the source needs login and the user isn't. 394 pass / 1 skip.
R6 Task 4 (verify): PARTIAL. Windows release builds; analyze clean; 394 pass / 1 skip. Android emulator died (adb: no devices) before the on-device check could run.
R6 COMPLETE (560cf84..1a71075). Pushed origin/dev.
  MUST-VERIFY (human): picacg/jm/ehentai install + load; login prompt on a login-required source; login dialog + retry; real-phone.

## Round 7 (2026-09-18)

Spec: docs/superpowers/specs/2026-09-18-comic-login-and-jm-images-design.md
Plan: docs/superpowers/plans/2026-09-18-comic-login-jm-images.md (base 1a71075, 5 tasks)

R7 Task 1 (empty detail -> login prompt): complete (commit 1a71075..fc1f2f0, review clean). 396 pass / 1 skip.
R7 Task 2 (ImageLoadingConfig.modifyImage): complete (commit fc1f2f0..317fc0d, review clean). 397 pass / 1 skip.
R7 Task 3 (JS Image API + bridge): complete (commit 317fc0d..cc4651a, review clean). 399 pass / 1 skip. `image_bridge.dart` (RgbaImage/fillImageRangeAt), init.js `Image`, js_engine `image` ops.
  Important (for Task 4): `_images` has no JS-reachable free; Task 4 must add a Dart-side dispose path.
R7 Task 4 (apply modifyImage): complete (commits cc4651a..e41d45f, review clean after 1 fix). Custom `_ModifyImageProvider` + `ComicSourceManager.fetchImageBytes/modifyImage` + `JsEngine.runModifyImage` (frees handles). Fix e41d45f: rawRgba (premultiplied) round-trip.
  Minor (deferred): loadImage ignores the decode callback (no cacheWidth); error paths may skip disposal; `_images` not cleared in dispose; cache key omits headers.
R7 COMPLETE (1a71075..e41d45f). analyze clean; 399 pass / 1 skip; Windows build OK. Pushed origin/dev.
  MUST-VERIFY (human/device): 哔咔 detail failure -> login prompt; 禁漫 page renders reassembled (not strips); 禁漫/ehentai show content without a prompt; real-phone.
  MUST-VERIFY (human): real-phone playback (emulator can't render); per-source reliability with titles known to exist on each site (DM84/xfdmneo/baimao unverified end-to-end); seek-bar lift on device.
  Minor (deferred): source delete has no confirm/mounted guard; `_safeName` collisions; seekBarMargin right 16 vs button bar right 8; no regression tests for pager/remove/settings.
  MUST-VERIFY (human): real-phone video rendering (emulator cannot render); the gimy HLS sub-playlist failure; Windows interactive regression.
  MUST-VERIFY (human): Android anime playback (all sources; the iframe extension-less HLS case) - the emulator cannot fetch the media CDN; Windows visual regression; real-phone M3 look; per-source detail/chapter/reader for 包子漫画/Komiic/MangaDex/漫画柜/拷贝漫画; 漫画柜 cover placeholders; 拷贝漫画 sparse explore.

## UI + Player custom controls (plan docs/superpowers/plans/2026-09-18-ui-player-custom-controls.md, base 73facb2)

Spec: docs/superpowers/specs/2026-09-18-ui-player-custom-controls-design.md

Task 1: complete (commit 73facb2..9bd9cb0, review clean; 2 Minor plan-mandated: test omits errorBorder/focusedErrorBorder assertions; property-inspection test would not catch a theme re-supplying a border).
Task 2: complete (commit 9bd9cb0..46ad164, review clean; 1 Minor plan-mandated: test asserts decoration.border==null rather than rendered style).
Task 3: complete (commit 46ad164..56415ad, review clean; 2 Minor: report line-count typo; optional 3600s formatting case).
Task 4: complete (commit 56415ad..db8e1bc, review clean after 1 plan-mandated fix db8e1bc (unused _topBar param); 4 Minor deferred: drag clears before onSeek (snap-back risk); elapsed text not clamped; no drag/onChangeEnd test; theme-primary assertion could be a literal).
Task 5: complete (commit db8e1bc..ecce71a, review clean after 1 Critical plan-mandated fix ecce71a (Video default controls is AdaptiveVideoControls, not null -> duplicate controls); 4 Minor deferred: desktop fullscreen state not synced with OS ESC/F11; mobile exit forces portraitUp; no onLongPressCancel (rate can stick at 2x); no page-level widget test).
Task 6: complete (verification, HEAD ecce71a). analyze clean; test +436 ~1 all pass; Windows release build OK; Android release APK OK (NDK 27 vs flutter_qjs-required 28 warning). Player manual verification (gestures/fullscreen/controls) still 待人工验收.
Final whole-branch review (73facb2..ecce71a): "With fixes" (2 Important: long-press pointer-cancel can strand 2x; desktop _fullscreen not synced with OS events; + Minors).
Fix wave 63fe333 (re-review "Ready to merge? Yes"): Listener onPointerUp/Cancel + lifecycle/dispose rate reset; WindowListener + isFullScreen() read-back; onSeek before _drag clear; single clamped preview value; +errorBorder/focusedErrorBorder assertions; +3600->1:00:00 case.
Residuals (non-blocking): no page-level widget test -> manual player verification is the release gate; mobile exit forces portraitUp / no SystemChrome restore on dispose; _endBoost fires on every pointer-up (idempotent, harmless now); spec B4/B3/B5 drift corrected.
UI + Player feature: implementation COMPLETE (73facb2..63fe333). Pushed origin/dev for the user's PR.

## Anime source headless fix (plan docs/superpowers/plans/2026-09-18-anime-source-headless-fix.md, base 2e139af)

Spec: docs/superpowers/specs/2026-09-18-anime-source-headless-fix-design.md
Diagnosis: .superpowers/sdd/source-diagnosis.md
Scope: A (Windows headless -> flutter_inappwebview) + B (proxy media extraction) + C (agedm https). D (MacCMS) / E (AGE) deferred.

Task 1: complete (commit 2e139af..11a0576, review clean; 3 Minor: /// doc comment vs "no comments" (plan-mandated, matches file style); redundant looksLikeMediaUrl on https: prefix; no test where a non-media param precedes the media param).
Task 2: complete (commit 11a0576..c8e16fb, review clean; 1 Minor: stale interface doc comment headless_browser.dart:49-50 saying Windows/Android differ -> fold into Task 4).
Task 3: complete (commit c8e16fb..68df19d, review clean; 3 Minor: duplicated ternary across detection layers (plan-mandated shape); mediaUrlFromQuery can return a relative value like clip.mp4 (no absolute check); broadcast stream can double-report the same URL).
Task 4: complete (commit 68df19d..7101b01, review clean; 1 Minor: createHeadlessBrowser() doc still mentions the removed webview_windows fork).
Task 5: complete (commit 7101b01..6726a72, review clean; 3 Minor: scheme match case-sensitive (HTTP://); _https rewrites any host; no already-https passthrough test).
Task 6: complete (verification, no commit, HEAD 6726a72). Real-app probe: 7sefun search 2 / episodes 20; agedm episodes 10; gimy resolve non-null m3u8 with Referer. analyze clean; test 440 pass/1 skip; Windows release + Android release APK build OK (NDK 27 vs flutter_qjs-required 28 warning).
Final whole-branch review (2e139af..6726a72): "With fixes" (1 Important: mediaUrlFromQuery returned relative values that could shadow the real stream; + Minors).
Fix wave 15b9ace (re-review "Ready to merge? Yes"): absolute/protocol-relative guard + regression test; _https host-scoped + case-insensitive + passthrough test; factory doc de-references webview_windows. Full suite 442 pass/1 skip.
Residuals (non-blocking): media stream can double-report proxy+inner (single consumer completes on first); duplicated ternary across MIME-aware/no-MIME paths; _https prefix match could catch agedm.io.evil.com (scheme-only upgrade, no regression).
Anime source headless fix: implementation COMPLETE (2e139af..15b9ace). Pushed origin/dev for the user's PR.
Deferred to next round: D MacCMS player_aaaa direct extraction (7sefun playback); E AGE动漫 playback (check own API, else replace source).

## MacCMS direct + AGE removal (plan docs/superpowers/plans/2026-09-18-maccms-age-removal.md, base 4403910)

Spec: docs/superpowers/specs/2026-09-18-maccms-age-removal-design.md
Diagnosis: 7sefun player_aaaa encrypt:2 = urlDecode(base64Decode(url)) (validated; decoded mp4 302->signed CDN); gimy player_data encrypt:0 direct m3u8 (validated 200); AGE all lines are jx age_ WASM (unsolvable) -> user chose removal.
Scope: D (MacCMS first in StreamResolver) + E (remove AgedmSource).

Task 1: complete (commit 4403910..0b276c0, review clean; 4 Minor: URL-safe base64 branch untested; string-encrypt/empty-url branches untested; blanket catch; matcher ignores single-quoted JS strings).
Task 2: complete (commit 0b276c0..e2b3a80, review clean; 5 Minor: connectTimeout not covered by timeout; _originOf drops ports / protocol-relative malformed; test doesn't assert UA/override branches; broad catch; shared headers map instance).
Task 3: complete (commit e2b3a80..712678c, review clean after 1 Important fix 712678c (connectTimeout on the hot-path MacCMS fetch); 2 Minor: no null-candidate fallback test; fake resolver constructs a real Dio).
Task 4: complete (commit 712678c..d24f536, review clean; no findings).
Task 5: verification revealed an Important bug: 七色番 线路1 decrypts to a nested non-media page (lmm85 vxdev token), and StreamResolver returned it as a candidate (no fallback). Fix fe32c2f: MacCmsResolver now rejects non-media candidates. Re-verified: 七色番 线路2 -> direct .mp4; gimy -> .m3u8; 线路1 (vxdev chain) unsupported by design (user can pick 线路2). analyze/test/builds pass (test 446+1 skip).
Known limitation (not a defect): vxdev-chained roads are not statically resolvable; the direct-media road works.
Final whole-branch review (4403910..fe32c2f): "Ready to merge? Yes" (1 Important non-blocking: sequential MacCMS probe latency; + Minors). Hardening d1f4b65: probe timeout 15s->8s; _originOf ports/scheme guard; +2 resolver tests +URL-safe base64 test. Re-review flagged the base64 test as a false positive; corrected ee7fc97 (fn5-/fn5+fg== genuinely cover normalization + padding). Re-review: Ready to merge? Yes.
Residuals (non-blocking): `_`->`/` half of URL-safe normalization untested; _originOf explicit default port yields redundant `:443`; dead legacy `assets/rules/` AGE entry + unused animeSourceListProvider not removed (separate cleanup); blanket catches; MediaCandidate shares Dio headers map (only consumer copies it).
MacCMS + AGE removal: implementation COMPLETE (4403910..ee7fc97). Pushed origin/dev for the user's PR.

## Legacy dead-code cleanup (2026-09-18)

User chose scope A (dead code). Removed the unused legacy rule subsystem: `search_engine.dart`, `source/source_manager.dart`, `source/source_adapter.dart`, `anime_source.dart`, `anime_rule.dart`, `assets/rules/` (incl. stale AGE rule) + pubspec entry, `sourceManagerProvider`/`animeSourceListProvider`, and the 3 associated tests.
- Task: complete (commit 55ab513..016003d, review clean; 1 Minor: orphaned `SourceInfo`/`SearchResult` models).
- Follow-up: complete (commit 016003d..a9da423) removed `lib/core/models/source.dart` + `search_result.dart`.
- Verified: analyze clean; test 439 pass / 1 skip; Windows release build OK.
- Cleanup COMPLETE (55ab513..a9da423). Pushed origin/dev.
Remaining known limitations (not dead code, intentionally kept): vxdev-chained roads not statically resolvable; broad `catch (_)` for resilience.

## Source load performance + fast-fail (plan docs/superpowers/plans/2026-09-18-source-load-performance.md, base 507e9ba)

Diagnosis (real-app timing probe): rule search 14-15s because WebviewScraper awaited full onLoadStop before eval; failed resolves burned ~31s (MacCMS 8s + headless 30s). DM84/gugu3/akianime/7sefun-road1 use third-party AES parse players that never emit media -> unsupported (no reverse engineering this round).
Scope: 1) poll eval while loading; 2) MacCMS 4s + headless load+6s grace fast-fail; 3) clearer failure copy; 4) timing re-verification.

Task 1: complete (commit 507e9ba..b59841e, review clean; 4 Minor: eval has no timeout so the 12s window is soft; early return can read a partially-rendered list (by design); DateTime.now vs Stopwatch; no direct test for the loop).
Task 2: complete (commit b59841e..c9edac2, review clean; 4 Minor: hard load failure waits the full 6s grace; media >6s after load now fails (intended fail-fast, confirm live); headless race untested; dispose-race harmless).
Task 3: complete (commit c9edac2..2cec022, review clean; no findings).
Task 4: complete (verification, HEAD 2cec022, no commit). Perf probe: search 七色番 14.4s->2.3s, xfdmneo 15.2s->3.4s; failed resolve DM84 31s->9.5s, gugu3->10.5s, 七色番->11.3s, akianime->18s; working resolves unchanged (1-4.7s). Gates pass (analyze/test/Windows+APK release).
Final whole-branch review (507e9ba..2cec022): "With fixes" (2 Important: akianime still ~18s; unbounded eval can hang/leak; + Minors). Fix wave 9351bc4: headless absolute 10s cap, grace 4s + immediate on load error; eval bounded 3s. Re-measured: failed resolves DM84 7.4s/gugu3 8.5s/七色番 11.1s/akianime 11.4s; working 1.1-4.7s; search counts parity. Re-review: Ready to merge? Yes.
Residual notes (non-blocking): 10s cap is per-headless-phase (worst case ~14s with a slow MacCMS probe); `timeout` param now partially vestigial; no automated test for the race/polling (native).
Source load performance: implementation COMPLETE (507e9ba..9351bc4). Pushed origin/dev for the user's PR.

## Background cancel + image cache (plan docs/superpowers/plans/2026-09-18-background-cancel-image-cache.md, base 56ead44)

Diagnosis: abandoned pages never cancel in-flight headless searches (dispose only stops starting the next source; running browsers finish their ~12s timeout) -> compounding WebView2 load; AppCacheManager was dead code so images used DefaultCacheManager (200 objects) and thrashed. Image cold loads measured 0.1-0.8s each (anime 133ms, game 5-11ms, novel lknovel 250-430ms, comic 270-800ms); warm 0ms.
Scope: A) CancellationToken through WebviewScraper/StreamResolver/VideoSource + wire detail/player dispose; B) tune AppCacheManager and inject into all image sites.

Task 1: complete (commit 56ead44..722a77b, review clean; 2 Minor: a throwing listener aborts the rest (no try/catch); test uses a single listener).
Task 2: complete (commit 722a77b..9ed4c3d, review clean; 2 Minor: cancel logs resolved=null indistinguishably; cancel latency bounded by the in-flight eval <=3s + 250ms).
Task 3: complete (commit 9ed4c3d..3a42876, review clean; 1 Minor: detail page reuses _searchCancel for resolve (brief-mandated, safe)).
Task 4: complete (commit 3a42876..3083bed, review clean; 2 Minor: comic_image provider reformatted to multi-line; import ordering nit).
Task 5: complete (verification, HEAD 3083bed, no commit). Cancel probe: abandoned 七色番 search returned in 1484ms (was ~12s timeout) -> cancellation works. Gates: analyze clean; test 443+1 skip; Windows+APK release OK.
Final whole-branch review (56ead44..3083bed): "Ready to merge? Yes" (no Critical/Important; Minors only).
Hardening 8aa2b32: cancellation listeners isolated with try/catch + multi-listener test. Full suite 444 pass / 1 skip.
Residual notes (non-blocking): API/HTML (Dio) sources only check cancel before/after the request (no mid-request abort, no WebView2 held); cancel latency bounded by the in-flight eval (<=3s) + 250ms; cancel logs resolved=null indistinguishably.
Background cancel + image cache: implementation COMPLETE (56ead44..8aa2b32). Pushed origin/dev for the user's PR.

## sorani API @source fix (ad hoc, 2026-09-18)

Root cause (live probe): `ApiRuleClient.search` resolved `sourcePath` against `baseUrl`, so sorani's numeric id 828 became `https://www.sorani.net/828` and the chapter request `.../video/https://www.sorani.net/828` returned 400. `@source` must stay raw.
Fix 92b94bc: `ApiClient.search` now emits `VideoItem(id: source, detailUrl: source)`; tests updated + a raw-numeric-id case. Reviewed clean.
Verified end-to-end (real-app probe): sorani search 2 -> episodes 28 -> StreamResolver resolved an m3u8 (`sorani-vids.xyz/.../index.m3u8`). Full suite 445 pass / 1 skip.
Remaining unsupported anime sources: DM84/gugu3/akianime/七色番-线路1 (third-party AES/jx parse players; not reversed by choice).
