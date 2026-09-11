### Task 5: Add metadata Riverpod providers

**Files:**
- Modify: `lib/modules/anime/anime_providers.dart`

**Interfaces:**
- Consumes: `MetadataService`, `AnimeFeed`.
- Produces: `metadataServiceProvider` (`Provider<MetadataService>`), `animeFeedProvider` (`FutureProvider.family<List<Work>, AnimeFeed>`). Keeps existing providers until Task 9.

- [ ] **Step 1: Add imports and providers**

In `lib/modules/anime/anime_providers.dart`, add these imports at the top:

```dart
import '../../core/metadata/metadata_provider.dart';
import '../../core/metadata/metadata_service.dart';
```

Add after `animeSourceListProvider`:

```dart
final metadataServiceProvider = Provider<MetadataService>((ref) => MetadataService());

final animeFeedProvider = FutureProvider.family<List<Work>, AnimeFeed>((ref, feed) {
  return ref.watch(metadataServiceProvider).feed(feed);
});
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/modules/anime/anime_providers.dart`
Expected: No errors (warnings about unused old providers are fine).

- [ ] **Step 3: Commit (only if user asked)**

```bash
git add lib/modules/anime/anime_providers.dart
git commit -m "feat(anime): expose metadata service and feed provider"
```

---
