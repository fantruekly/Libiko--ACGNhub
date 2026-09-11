# Bangumi Chinese Metadata Source Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make anime metadata Chinese (names, summaries, scores, tags) and show current-season anime on the home, using Bangumi as the primary source; remove the on-card source label; regenerate the offline seed from Bangumi.

**Architecture:** Add a `BangumiProvider` implementing `MetadataProvider` (calendar/search/detail). Make it first in `MetadataService`'s provider order and generalize the transient-failure breaker to a per-provider map. Remove the source label from `WorkCard`. Regenerate the seed from Bangumi's calendar with a Dart generator (Dio/BoringSSL reaches Bangumi; curl/.NET cannot).

**Tech Stack:** Flutter 3.35, Dart 3, Riverpod 2, Dio 5, cached_network_image, flutter_test.

## Global Constraints

- Target platform: Windows first.
- `Work.extra['score']` is a 0–10 double (or absent); Bangumi `rating.score` is already 0–10.
- Anime-specific data lives in `Work.extra`; `Work` stays generic.
- Bangumi base `https://api.bgm.tv`; headers `User-Agent: ACGNhub/0.1 (https://github.com/acgnhub)` + `Accept: application/json`.
- Provider order: `bangumi → anilist → jikan`. Transient-failure disable window: 1 minute.
- No playback/player work in this plan.
- Commits: only run `git commit` steps if the user explicitly asks; otherwise treat them as checkpoints.

---

### Task 1: `BangumiProvider`

**Files:**
- Create: `lib/core/metadata/bangumi_provider.dart`
- Test: `test/core/metadata/bangumi_provider_test.dart`

**Interfaces:**
- Consumes: `MetadataProvider`, `AnimeFeed` (`lib/core/metadata/metadata_provider.dart`), `Work`.
- Produces: `class BangumiProvider implements MetadataProvider` with `BangumiProvider({Dio? dio})`, `String get id => 'bangumi'`, and static `parseCalendar(List<dynamic> days, {int? onlyWeekday})`, `parseSearch(dynamic data)`, `parseDetail(Map<String, dynamic> d)`.

- [ ] **Step 1: Write the failing test**

Create `test/core/metadata/bangumi_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/metadata/bangumi_provider.dart';

void main() {
  final calendarItem = {
    'id': 456080,
    'name': '転校先の清楚可憐な美少女が、昔男子と思って一緒に遊んだ幼馴染だった件',
    'name_cn': '转学后班上的清纯可爱美少女',
    'summary': '幼かった夏の終わり。',
    'air_date': '2026-07-06',
    'air_weekday': 1,
    'rating': {'score': 5.6, 'total': 100},
    'rank': 3000,
    'images': {'large': 'http://lain.bgm.tv/pic/cover/l/ce/e2/456080_C4q4C.jpg'},
  };

  test('parseCalendar maps items to Work with the Chinese name and https cover', () {
    final days = [
      {
        'weekday': {'id': 1, 'cn': '星期一'},
        'items': [calendarItem],
      },
    ];

    final works = BangumiProvider.parseCalendar(days);

    expect(works, hasLength(1));
    final w = works.first;
    expect(w.id, 'bangumi_456080');
    expect(w.title, '转学后班上的清纯可爱美少女');
    expect(w.coverUrl, 'https://lain.bgm.tv/pic/cover/l/ce/e2/456080_C4q4C.jpg');
    expect(w.summary, '幼かった夏の終わり。');
    expect(w.extra['bangumiId'], 456080);
    expect(w.extra['score'], closeTo(5.6, 0.001));
    expect(w.extra['airDate'], '2026-07-06');
  });

  test('parseCalendar onlyWeekday filters days', () {
    final days = [
      {'weekday': {'id': 1}, 'items': [calendarItem]},
      {'weekday': {'id': 3}, 'items': [calendarItem]},
    ];
    expect(BangumiProvider.parseCalendar(days, onlyWeekday: 3), hasLength(1));
    expect(BangumiProvider.parseCalendar(days, onlyWeekday: 2), isEmpty);
  });

  test('parseSearch reads data.list', () {
    final works = BangumiProvider.parseSearch({
      'list': [calendarItem]
    });
    expect(works.single.id, 'bangumi_456080');
  });

  test('parseDetail reads tags and falls back to name when name_cn is empty', () {
    final w = BangumiProvider.parseDetail({
      'id': 1,
      'name': 'Sousou no Frieren',
      'name_cn': '',
      'summary': 'A mage.',
      'date': '2023-09-29',
      'eps': 28,
      'rating': {'score': 8.9},
      'images': {'large': 'http://lain.bgm.tv/x.jpg'},
      'tags': [
        {'name': '奇幻'},
        {'name': '冒险'},
      ],
    });
    expect(w.title, 'Sousou no Frieren');
    expect(w.tags, ['奇幻', '冒险']);
    expect(w.extra['episodes'], 28);
    expect(w.extra['score'], closeTo(8.9, 0.001));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/metadata/bangumi_provider_test.dart`
Expected: FAIL — `bangumi_provider.dart` not found.

- [ ] **Step 3: Implement `BangumiProvider`**

Create `lib/core/metadata/bangumi_provider.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../models/work.dart';
import 'metadata_provider.dart';

class BangumiProvider implements MetadataProvider {
  static const _base = 'https://api.bgm.tv';

  final Dio _dio;

  BangumiProvider({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: _base,
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 20),
              headers: {
                'User-Agent': 'ACGNhub/0.1 (https://github.com/acgnhub)',
                'Accept': 'application/json',
              },
            ));

  @override
  String get id => 'bangumi';

  @override
  Future<List<Work>> feed(AnimeFeed feed, {int page = 1}) async {
    final res = await _dio.get('/calendar');
    final days = res.data as List<dynamic>;
    switch (feed) {
      case AnimeFeed.today:
        return parseCalendar(days, onlyWeekday: DateTime.now().weekday);
      case AnimeFeed.season:
        return parseCalendar(days);
      case AnimeFeed.trending:
        final works = parseCalendar(days);
        works.sort((a, b) {
          final sa = (a.extra['score'] as num?) ?? 0;
          final sb = (b.extra['score'] as num?) ?? 0;
          return sb.compareTo(sa);
        });
        return works;
    }
  }

  @override
  Future<List<Work>> search(String keyword, {int page = 1}) async {
    final res = await _dio.get(
      '/search/subject/${Uri.encodeComponent(keyword)}',
      queryParameters: {'type': 2, 'responseGroup': 'small'},
    );
    return parseSearch(res.data);
  }

  @override
  Future<Work> detail(Work work) async {
    final id = work.extra['bangumiId'];
    if (id == null) {
      throw StateError('BangumiProvider.detail requires bangumiId');
    }
    final res = await _dio.get('/v0/subjects/$id');
    return parseDetail(res.data as Map<String, dynamic>);
  }

  @visibleForTesting
  static List<Work> parseCalendar(List<dynamic> days, {int? onlyWeekday}) {
    final works = <Work>[];
    final seen = <int>{};
    for (final day in days) {
      final d = day as Map<String, dynamic>;
      final weekday = (d['weekday'] as Map<String, dynamic>?)?['id'] as int?;
      if (onlyWeekday != null && weekday != onlyWeekday) continue;
      for (final item in (d['items'] as List<dynamic>? ?? [])) {
        final w = _parseItem(item as Map<String, dynamic>);
        if (w != null && seen.add(w.extra['bangumiId'] as int)) works.add(w);
      }
    }
    return works;
  }

  @visibleForTesting
  static List<Work> parseSearch(dynamic data) {
    final list = ((data is Map ? data['list'] : data) as List<dynamic>?) ?? [];
    return list.map((e) => _parseItem(e as Map<String, dynamic>)).whereType<Work>().toList();
  }

  @visibleForTesting
  static Work parseDetail(Map<String, dynamic> d) => _parseItem(d, isDetail: true)!;

  static Work? _parseItem(Map<String, dynamic> item, {bool isDetail = false}) {
    final id = item['id'] as int?;
    if (id == null) return null;
    final nameCn = (item['name_cn'] as String?)?.trim() ?? '';
    final name = (item['name'] as String?)?.trim() ?? '';
    final title = nameCn.isNotEmpty ? nameCn : name;
    if (title.isEmpty) return null;

    final images = item['images'] as Map<String, dynamic>?;
    final cover = images?['large'] as String? ?? images?['common'] as String?;
    final rating = item['rating'] as Map<String, dynamic>?;
    final score = rating?['score'];
    final tags = (item['tags'] as List<dynamic>?)
            ?.map((t) => (t as Map<String, dynamic>)['name'] as String)
            .toList() ??
        [];

    return Work(
      id: 'bangumi_$id',
      sourceId: 'bangumi',
      sourceName: 'Bangumi',
      type: WorkType.anime,
      title: title,
      coverUrl: _https(cover),
      summary: (item['summary'] as String?)?.trim(),
      tags: isDetail ? tags : const [],
      extra: {
        'bangumiId': id,
        'score': score is num ? score.toDouble() : null,
        'episodes': item['eps'],
        'airDate': item['air_date'] ?? item['date'],
        'rank': item['rank'],
      },
    );
  }

  static String? _https(String? url) {
    if (url == null || url.isEmpty) return null;
    return url.startsWith('http://') ? url.replaceFirst('http://', 'https://') : url;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/metadata/bangumi_provider_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit (only if user asked)**

```bash
git add lib/core/metadata/bangumi_provider.dart test/core/metadata/bangumi_provider_test.dart
git commit -m "feat(metadata): add BangumiProvider"
```

---

### Task 2: Make Bangumi primary + generalize the breaker

**Files:**
- Modify: `lib/core/metadata/metadata_service.dart`
- Test: `test/core/metadata/metadata_service_test.dart`

**Interfaces:**
- Consumes: `BangumiProvider` (Task 1).
- Produces: `MetadataService({MetadataProvider? bangumi, MetadataProvider? anilist, MetadataProvider? jikan, DateTime Function()? now, MetadataCache? cache, MetadataSeedLoader? seedLoader, Map<String, Duration>? intervals})`; provider order `[bangumi, anilist, jikan]`; per-provider transient disable.

- [ ] **Step 1: Update the test helper to inject a failing Bangumi**

In `test/core/metadata/metadata_service_test.dart`, change the `_service` helper to:
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

### Task 3: Remove the source label from cards

**Files:**
- Modify: `lib/core/widgets/work_card.dart`

**Interfaces:**
- Produces: `WorkCard({Work work, VoidCallback? onTap})` — no `subtitle`, no source-name line.

- [ ] **Step 1: Remove the subtitle**

In `lib/core/widgets/work_card.dart`:
1. Remove the `final String? subtitle;` field and the `this.subtitle` constructor parameter.
2. Remove the line `final sub = subtitle ?? work.sourceName;`.
3. Remove the conditional `if (sub.isNotEmpty) Text(sub, ...)` widget (and its preceding `const SizedBox`/spacing if it becomes orphaned).

The `build` method's `children` should end with the title `Text` (2-line clamp) only.

- [ ] **Step 2: Verify**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib/core/widgets/work_card.dart`
Expected: No issues found.

- [ ] **Step 3: Commit (only if user asked)**

```bash
git add lib/core/widgets/work_card.dart
git commit -m "style(anime): drop the source label from work cards"
```

---

### Task 4: Regenerate the offline seed from Bangumi

**Files:**
- Create: `tool/gen_seed.dart`
- Replace: `assets/anime_seed.json`

**Interfaces:**
- Produces: `assets/anime_seed.json` — a JSON array of up to 40 `Work`-shaped objects with Chinese `title`, `summary`, `coverUrl` (https), and `extra = {bangumiId, score, episodes, airDate}`.

**Note:** the generator must be **Dart** (Dio/BoringSSL), not PowerShell — curl/.NET fail on Bangumi's TLS revocation check.

- [ ] **Step 1: Write the Dart generator**

Create `tool/gen_seed.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';

Future<void> main() async {
  final dio = Dio(BaseOptions(
    baseUrl: 'https://api.bgm.tv',
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
    headers: {
      'User-Agent': 'ACGNhub/0.1 (https://github.com/acgnhub)',
      'Accept': 'application/json',
    },
  ));

  final res = await dio.get('/calendar');
  final days = res.data as List<dynamic>;
  final works = <Map<String, dynamic>>[];
  final seen = <int>{};

  for (final day in days) {
    for (final item in ((day as Map<String, dynamic>)['items'] as List<dynamic>? ?? [])) {
      final m = item as Map<String, dynamic>;
      final id = m['id'] as int;
      if (!seen.add(id)) continue;
      final nameCn = (m['name_cn'] as String?)?.trim() ?? '';
      final name = (m['name'] as String?)?.trim() ?? '';
      final title = nameCn.isNotEmpty ? nameCn : name;
      if (title.isEmpty) continue;
      final images = m['images'] as Map<String, dynamic>?;
      final cover = images?['large'] as String? ?? images?['common'] as String?;
      final rating = m['rating'] as Map<String, dynamic>?;
      works.add({
        'id': 'bangumi_$id',
        'sourceId': 'bangumi',
        'sourceName': 'Bangumi',
        'type': 'anime',
        'title': title,
        'coverUrl': cover == null
            ? null
            : (cover.startsWith('http://') ? cover.replaceFirst('http://', 'https://') : cover),
        'summary': (m['summary'] as String?)?.trim(),
        'tags': <String>[],
        'author': null,
        'extra': {
          'bangumiId': id,
          'score': rating?['score'],
          'episodes': m['eps'],
          'airDate': m['air_date'],
        },
      });
      if (works.length >= 40) break;
    }
    if (works.length >= 40) break;
  }

  await File('assets/anime_seed.json').writeAsString(
    const JsonEncoder.withIndent('  ').convert(works),
  );
  stdout.writeln('wrote ${works.length} entries');
}
```

- [ ] **Step 2: Run the generator**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; dart run tool/gen_seed.dart`
Expected: `wrote <N> entries` with N ≥ 30.

- [ ] **Step 3: Verify the asset and tests**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: all tests pass.

- [ ] **Step 4: Commit (only if user asked)**

```bash
git add tool/gen_seed.dart assets/anime_seed.json
git commit -m "chore(seed): regenerate offline seed from Bangumi calendar"
```

---

### Task 5: Final verification

**Files:** none (verification only).

- [ ] **Step 1: Analyze**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

- [ ] **Step 2: Run the full test suite**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: all tests pass.

- [ ] **Step 3: Build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug`
Expected: `Built build\windows\x64\runner\Debug\acgnhub.exe`.

- [ ] **Step 4: Smoke-run (manual)**

Run: `flutter run -d windows`
Expected: the home shows current-season anime with **Chinese names**; detail pages show Chinese name + summary + stars; no source label on cards; search returns Chinese results.

---

## Self-Review

- **Spec coverage:** BangumiProvider + mapping (§3, §4) → Task 1; provider order + generalized breaker (§5) → Task 2; remove source label (§7) → Task 3; seed from calendar (§6) → Task 4; tests (§8) → Tasks 1–2, 5. All spec sections covered.
- **Placeholders:** none.
- **Type consistency:** `BangumiProvider({Dio? dio})`, `parseCalendar(List<dynamic>, {int? onlyWeekday})`, `parseSearch(dynamic)`, `parseDetail(Map<String,dynamic>)`, `MetadataService({..., bangumi, anilist, jikan, ...})`, `Work.extra['bangumiId']/['score']/['episodes']/['airDate']` are consistent across tasks.
