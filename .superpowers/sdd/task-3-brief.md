### Task 3: Provider continuation

**Files:**
- Modify: `lib/modules/comic/comic_providers.dart`

**Interfaces:**
- Consumes: `ExplorePage.viewMore` (Task 1), `ComicSource.hasCategoryComics`/`ComicSourceManager.category` (Task 2).

- [ ] **Step 1: Make `comicExploreAllProvider` return `ExplorePage`**

Replace its body with:

```dart
/// The full one-shot result for a non-server-paged section (cached per
/// section), including its `viewMore` target.
final comicExploreAllProvider =
    FutureProvider.family<ExplorePage, (String, int)>((ref, key) async {
  final (sourceKey, section) = key;
  final manager = ref.watch(comicSourceManagerProvider);
  final source = ref
      .watch(comicSourcesProvider)
      .valueOrNull
      ?.where((s) => s.key == sourceKey)
      .firstOrNull;
  if (source == null) throw StateError('source $sourceKey not loaded');
  return manager.explore(source, section, page: 1);
});
```

- [ ] **Step 2: Replace the client-paged branch**

In `comicExploreProvider`, replace the current client-paged block (the `final all = ...` block through its `return`) with:

```dart
  final explore =
      await ref.watch(comicExploreAllProvider((sourceKey, section)).future);
  final all = explore.comics;
  final explorePages =
      all.isEmpty ? 1 : (all.length + _explorePageSize - 1) ~/ _explorePageSize;
  if (page <= explorePages) {
    final start = (page - 1) * _explorePageSize;
    final end = (start + _explorePageSize).clamp(0, all.length);
    final comics = start >= all.length ? const <Comic>[] : all.sublist(start, end);
    return ComicExplorePage(
      comics: comics,
      page: page,
      maxPage: source.hasCategoryComics ? null : explorePages,
      hasNext: source.hasCategoryComics || page < explorePages,
      serverPaged: false,
    );
  }
  if (!source.hasCategoryComics) {
    return ComicExplorePage(
      comics: const [],
      page: page,
      maxPage: explorePages,
      hasNext: false,
      serverPaged: false,
    );
  }
  final catPage = page - explorePages;
  final (cat, param) = _continuationTarget(explore.viewMore);
  final result =
      await manager.category(source, catPage, category: cat, param: param);
  return ComicExplorePage(
    comics: result.comics,
    page: page,
    maxPage: null,
    hasNext: result.maxPage != null
        ? catPage < result.maxPage!
        : result.comics.isNotEmpty,
    serverPaged: true,
  );
```

Add the helper at file scope (near `_explorePageSize`):

```dart
(String?, String?) _continuationTarget(String? viewMore) {
  if (viewMore == null || !viewMore.startsWith('category:')) {
    return (null, null);
  }
  final rest = viewMore.substring('category:'.length);
  final at = rest.indexOf('@');
  if (at < 0) return (rest, null);
  return (rest.substring(0, at), rest.substring(at + 1));
}
```

- [ ] **Step 3: Analyze and build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug` → built.

- [ ] **Step 4: Commit and push**

```bash
git add lib/modules/comic/comic_providers.dart
git commit -m "feat(comic): continue one-shot explore sections into the category listing"
git push
```

---
