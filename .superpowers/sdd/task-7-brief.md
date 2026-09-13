### Task 7: Shell wiring + final verification

**Files:**
- Modify: `lib/shell/main_shell.dart`

- [ ] **Step 1: Wire the module into the shell**

In `lib/shell/main_shell.dart`:
- import `'../modules/comic/comic_home.dart'` and `'../modules/comic/comic_search.dart'`;
- replace `_pages[1]` (the 漫画 placeholder) with `const ComicHomePage()`;
- make the title-bar search `IconButton` open `ComicSearchPage` when `_currentIndex == 1` (it currently opens the anime search for `_currentIndex == 0`).

- [ ] **Step 2: Analyze, test, build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → all pass.
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug` → built.

- [ ] **Step 3: In-app smoke test (manual)**

Launch the app, open 漫画, and: add a source (import `assets/comic_source/test_source.js` from the repo via 从文件导入), confirm it appears with its capability chips; search a keyword and confirm the fixture's two results; open a detail page and confirm the chapters render and 收藏 toggles; check the 收藏 tab shows it and the 历史 tab is empty. Record the outcome.

- [ ] **Step 4: Commit**

```bash
git add lib/shell/main_shell.dart
git commit -m "feat(comic): wire the comic module into the shell"
```

---

## Self-Review

- **Spec coverage:** §3 stores → Tasks 1–2; §3 image + providers → Task 3; §4 home → Task 4; §5 source management → Task 4; §6 detail → Task 6; search (§4's search entry) → Task 5; shell wiring → Task 7; §10 tests → Tasks 1–2, 7. The reader (§7) is C2b.
- **Placeholders:** the only intentional placeholders are the C2a chapter/继续阅读 `SnackBar`s, which C2b replaces — called out explicitly in Task 6.
- **Type consistency:** `ComicFavorite{sourceKey, comicId, title, cover, addedAt}`, `ComicHistoryEntry{sourceKey, comicId, title, cover, chapterId, chapterTitle, page, readAt}`, `comicFavoritesProvider`/`comicHistoryProvider`, `comicSourcesProvider`/`comicExploreProvider`/`comicSearchProvider`/`comicDetailProvider`/`comicEpProvider`, `ComicImageProvider.resolve`, `ComicHomePage`/`ComicSourcePage`/`ComicSearchPage`/`ComicDetailPage` — used consistently across tasks.