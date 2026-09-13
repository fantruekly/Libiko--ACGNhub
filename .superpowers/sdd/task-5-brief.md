### Task 5: Comic search

**Files:**
- Create: `lib/modules/comic/comic_search.dart`

**Interfaces:**
- Consumes: `comicSearchProvider` (Task 3), `ComicCard` (Task 4 — make it a public widget in `comic_home.dart` or move it to a shared file so both pages use it).
- Produces: `class ComicSearchPage extends ConsumerStatefulWidget`.

- [ ] **Step 1: Create `lib/modules/comic/comic_search.dart`**

Mirror `lib/modules/anime/anime_search.dart`:
- A top search field (a `TextField` with a search icon, `onSubmitted` sets the keyword state).
- `ref.watch(comicSearchProvider(keyword))` → `ShimmerLoader` while loading, an inline error + 重试 on failure, `EmptyState(icon: Icons.search_off_rounded, message: '没有找到漫画')` when empty, else the same `GridView` of `ComicCard`s (grid constants as in Task 4).
- Each result is a `ComicSearchResult` (already defined in Task 3), so the card carries its `sourceKey`; tapping pushes `ComicDetailPage(sourceKey: result.sourceKey, comicId: result.comic.id, title: result.comic.title, cover: result.comic.cover)`.

- [ ] **Step 2: Analyze and build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug` → built.

- [ ] **Step 3: Commit**

```bash
git add lib/modules/comic/comic_search.dart lib/modules/comic/comic_providers.dart
git commit -m "feat(comic): add comic search"
```

---
