### Task 2: Make Bangumi primary + generalize the breaker

**Files:**
- Modify: `lib/core/metadata/metadata_service.dart`
- Test: `test/core/metadata/metadata_service_test.dart`

**Interfaces:**
- Consumes: `BangumiProvider` (Task 1).
- Produces: `MetadataService({MetadataProvider? bangumi, MetadataProvider? anilist, MetadataProvider? jikan, DateTime Function()? now, MetadataCache? cache, MetadataSeedLoader? seedLoader, Map<String, Duration>? intervals})`; provider order `[bangumi, anilist, jikan]`; per-provider transient disable.

- [ ] **Step 1: Update the test helper to inject a failing Bangumi**

In `test/core/metadata/metadata_service_test.dart`, add an import at the top:
```dart
import 'package:acgnhub/core/metadata/bangumi_provider.dart';
```
and change the `_service` helper to:
```dart
MetadataService _service({
  MetadataProvider? bangumi,
  MetadataProvider? anilist,
  MetadataProvider? jikan,
  MetadataCache? cache,
  MetadataSeedLoader? seedLoader,
  DateTime Function()? now,
}) {
  return MetadataService(
    bangumi: bangumi ?? _FakeProvider('bangumi', fail: true),
    anilist: anilist ?? _FakeProvider('anilist'),
    jikan: jikan ?? _FakeProvider('jikan'),
    cache: cache ?? _FakeCache(),
    seedLoader: seedLoader ?? () async => const [],
    now: now,
    intervals: const {},
  );
}
```
(The default failing Bangumi makes the existing assertions about `anilist`/`jikan` call counts still hold.)

Add this new test inside `main()`:
```dart
  test('tries Bangumi first, then falls back', () async {
    final bangumi = _FakeProvider('bangumi', fail: true);
    final anilist = _FakeProvider('anilist');
    final service = _service(bangumi: bangumi, anilist: anilist);

    final works = await service.feed(AnimeFeed.trending);
    expect(works.single.sourceId, 'anilist');
    expect(bangumi.calls, 1);
    expect(anilist.calls, 1);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/metadata/metadata_service_test.dart`
Expected: FAIL — `MetadataService` has no `bangumi` parameter (compile error).

- [ ] **Step 3: Update `MetadataService`**

In `lib/core/metadata/metadata_service.dart`:

1. Add the import:
```dart
import 'bangumi_provider.dart';
```

2. Add the `bangumi` field and change the constructor:
```dart
  final MetadataProvider bangumi;
  final MetadataProvider anilist;
  final MetadataProvider jikan;
```
and:
```dart
  MetadataService({
    MetadataProvider? bangumi,
    MetadataProvider? anilist,
    MetadataProvider? jikan,
    DateTime Function()? now,
    MetadataCache? cache,
    MetadataSeedLoader? seedLoader,
    Map<String, Duration>? intervals,
  })  : bangumi = bangumi ?? BangumiProvider(),
        anilist = anilist ?? AniListProvider(),
        jikan = jikan ?? JikanProvider(),
        _now = now ?? DateTime.now,
        cache = cache ?? PrefsMetadataCache(),
        seedLoader = seedLoader ?? _defaultSeedLoader,
        _intervals = intervals ??
            const {
              'bangumi': Duration(milliseconds: 300),
              'anilist': Duration(milliseconds: 1000),
              'jikan': Duration(milliseconds: 350),
            };
```

3. Replace the `DateTime? _anilistDisabledUntil;` field with:
```dart
  final Map<String, DateTime> _disabledUntil = {};

  List<MetadataProvider> get _providers => [bangumi, anilist, jikan];
```

4. Replace the body of `_run<T>` with:
```dart
  Future<T> _run<T>(String key, Future<T> Function(MetadataProvider) op) async {
    final cached = _cache[key];
    if (cached != null && _now().difference(cached.at) < _cacheTtl) {
      return cached.value as T;
    }

    var order = _providers.where((p) {
      final until = _disabledUntil[p.id];
      return until == null || !_now().isBefore(until);
    }).toList();
    if (order.isEmpty) order = List.of(_providers);

    Object? lastError;
    for (final provider in order) {
      try {
        final result = provider == jikan
            ? await _serializeJikan(() => _withRetry(() => _call(provider, () => op(provider))))
            : await _withRetry(() => _call(provider, () => op(provider)));
        _disabledUntil.remove(provider.id);
        _cache[key] = _CacheEntry(_now(), result);
        return result;
      } catch (e) {
        lastError = e;
        if (e is DioException) {
          _disabledUntil[provider.id] = _now().add(_disableDuration);
        }
      }
    }
    throw Exception('All metadata providers failed: $lastError');
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/metadata/metadata_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit (only if user asked)**

```bash
git add lib/core/metadata/metadata_service.dart test/core/metadata/metadata_service_test.dart
git commit -m "feat(metadata): make Bangumi primary and generalize the provider breaker"
```

---
