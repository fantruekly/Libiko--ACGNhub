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
  MUST-VERIFY (human): Android anime playback (all sources; the iframe extension-less HLS case) - the emulator cannot fetch the media CDN; Windows visual regression; real-phone M3 look; per-source detail/chapter/reader for 包子漫画/Komiic/MangaDex/漫画柜/拷贝漫画; 漫画柜 cover placeholders; 拷贝漫画 sparse explore.
