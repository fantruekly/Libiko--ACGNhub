### Task 7: Rewrite anime search to use the metadata service

**Files:**
- Modify: `lib/modules/anime/anime_search.dart`

**Interfaces:**
- Consumes: `metadataServiceProvider`, `WorkCard`, `ShimmerLoader`, `EmptyState`, `BangumiDetailPage` (renamed in Task 8).

- [ ] **Step 1: Replace the `_search` method**

In `lib/modules/anime/anime_search.dart`, replace the body of `_search()` with:

```dart
  Future<void> _search() async {
    final k = _ctrl.text.trim();
    if (k.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _hasSearched = true;
    });
    try {
      final results = await ref.read(metadataServiceProvider).search(k);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }
```

- [ ] **Step 2: Remove now-unused imports**

Remove the `import 'anime_providers.dart';` if it is no longer used — but it IS used for `metadataServiceProvider`. Keep it. Ensure `Work` import is still present.

- [ ] **Step 3: Verify build**

Run: `flutter analyze lib/modules/anime/anime_search.dart`
Expected: No errors.

- [ ] **Step 4: Commit (only if user asked)**

```bash
git add lib/modules/anime/anime_search.dart
git commit -m "feat(anime): search via metadata service"
```

---
