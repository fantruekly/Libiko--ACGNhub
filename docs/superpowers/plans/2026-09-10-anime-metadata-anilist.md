# Anime Metadata via AniList (with Jikan fallback) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Bangumi anime metadata with a provider abstraction — AniList primary, Jikan (MyAnimeList) automatic fallback — consumed by the home, search, and detail pages.

**Architecture:** `lib/core/metadata/` holds a `MetadataProvider` interface, `AniListProvider` (GraphQL), `JikanProvider` (REST), and a `MetadataService` that tries AniList, falls back to Jikan on error, disables AniList for 10 minutes after a failure, and caches responses in memory for 5 minutes. Riverpod exposes the service and a feed family; the UI keeps its existing design.

**Tech Stack:** Flutter 3.35, Dart 3, Riverpod 2, Dio 5, cached_network_image, url_launcher, flutter_test.

## Global Constraints

- Target platform: Windows first.
- Light theme only; do not touch `main.dart` theme or the shell/sidebar.
- Anime-specific data lives in `Work.extra`; `Work` stays generic across modules.
- `perPage` = 25 for all feeds and search (Jikan's documented max; AniList accepts 25 too).
- AniList endpoint: `https://graphql.anilist.co` (POST, JSON `{query, variables}`).
- Jikan endpoint: `https://api.jikan.moe/v4` (GET).
- AniList disabled-for: 10 minutes after a failure. Response cache TTL: 5 minutes.
- No video/player work in this plan.
- Commits: only run the `git commit` steps if the user explicitly asks for commits; otherwise treat them as checkpoints.

---

### Task 1: Work model getters

**Files:**
- Modify: `lib/core/models/work.dart`
- Test: `test/core/models/work_test.dart`

**Interfaces:**
- Produces: `int? get anilistId`, `int? get malId`, `String? get bannerUrl` on `Work`.

- [ ] **Step 1: Write the failing test**

Append to `test/core/models/work_test.dart` inside `main()`:

```dart
  test('Work exposes anime metadata getters from extra', () {
    const work = Work(
      id: 'anilist_1',
      sourceId: 'anilist',
      sourceName: 'AniList',
      type: WorkType.anime,
      title: 'Test',
      extra: {'anilistId': 1, 'malId': 2, 'bannerUrl': 'https://x/b.jpg'},
    );
    expect(work.anilistId, 1);
    expect(work.malId, 2);
    expect(work.bannerUrl, 'https://x/b.jpg');
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/models/work_test.dart`
Expected: FAIL — "The getter 'anilistId' isn't defined".

- [ ] **Step 3: Add the getters**

In `lib/core/models/work.dart`, add after the `toJson` map (before the closing brace of the class):

```dart
  int? get anilistId => extra['anilistId'] as int?;
  int? get malId => extra['malId'] as int?;
  String? get bannerUrl => extra['bannerUrl'] as String?;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/models/work_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit (only if user asked)**

```bash
git add lib/core/models/work.dart test/core/models/work_test.dart
git commit -m "feat(metadata): add anime metadata getters to Work"
```

---

### Task 2: MetadataProvider interface + JikanProvider

**Files:**
- Create: `lib/core/metadata/metadata_provider.dart`
- Create: `lib/core/metadata/jikan_provider.dart`
- Test: `test/core/metadata/jikan_provider_test.dart`

**Interfaces:**
- Produces: `enum AnimeFeed { trending, season, today }`; `abstract class MetadataProvider { String get id; Future<List<Work>> feed(AnimeFeed feed, {int page = 1}); Future<List<Work>> search(String keyword, {int page = 1}); Future<Work> detail(Work work); }`
- Produces: `JikanProvider({Dio? dio})` with `static List<Work> parseList(dynamic data)` and `static Work parseItem(Map<String, dynamic> item)`.

- [ ] **Step 1: Create the interface**

Create `lib/core/metadata/metadata_provider.dart`:

```dart
import '../../models/work.dart';

enum AnimeFeed { trending, season, today }

abstract class MetadataProvider {
  String get id;
  Future<List<Work>> feed(AnimeFeed feed, {int page = 1});
  Future<List<Work>> search(String keyword, {int page = 1});
  Future<Work> detail(Work work);
}
```

- [ ] **Step 2: Write the failing test**

Create `test/core/metadata/jikan_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/metadata/jikan_provider.dart';

void main() {
  test('parseList maps a Jikan response to Work items', () {
    final data = {
      'data': [
        {
          'mal_id': 52991,
          'title': 'Sousou no Frieren',
          'title_english': 'Frieren: Beyond Journey\'s End',
          'title_japanese': '葬送のフリーレン',
          'images': {
            'jpg': {'image_url': 'https://cdn/x.jpg', 'large_image_url': 'https://cdn/x-l.jpg'},
          },
          'synopsis': '<p>A mage <i>journeys</i>.</p>',
          'genres': [
            {'name': 'Adventure'},
            {'name': 'Drama'},
          ],
          'studios': [
            {'name': 'Madhouse'},
          ],
          'episodes': 28,
          'score': 9.3,
          'status': 'Finished Airing',
          'year': 2023,
        }
      ]
    };

    final works = JikanProvider.parseList(data);

    expect(works, hasLength(1));
    final w = works.first;
    expect(w.id, 'jikan_52991');
    expect(w.title, 'Sousou no Frieren');
    expect(w.coverUrl, 'https://cdn/x-l.jpg');
    expect(w.summary, 'A mage journeys.');
    expect(w.tags, ['Adventure', 'Drama']);
    expect(w.malId, 52991);
    expect(w.extra['score'], 9.3);
    expect(w.extra['episodes'], 28);
    expect(w.extra['seasonYear'], 2023);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/core/metadata/jikan_provider_test.dart`
Expected: FAIL — `jikan_provider.dart` not found.

- [ ] **Step 4: Implement JikanProvider**

Create `lib/core/metadata/jikan_provider.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../models/work.dart';
import 'metadata_provider.dart';

class JikanProvider implements MetadataProvider {
  static const perPage = 25;
  static const _weekdays = [
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday',
  ];

  final Dio _dio;

  JikanProvider({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://api.jikan.moe/v4',
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 20),
              headers: {'Accept': 'application/json'},
            ));

  @override
  String get id => 'jikan';

  @override
  Future<List<Work>> feed(AnimeFeed feed, {int page = 1}) async {
    final path = switch (feed) {
      AnimeFeed.trending => '/top/anime',
      AnimeFeed.season => '/seasons/now',
      AnimeFeed.today => '/schedules',
    };
    final query = <String, dynamic>{'limit': perPage, 'page': page};
    if (feed == AnimeFeed.trending) query['filter'] = 'bypopularity';
    if (feed == AnimeFeed.today) query['filter'] = _weekdays[DateTime.now().weekday - 1];
    final res = await _dio.get(path, queryParameters: query);
    return parseList(res.data);
  }

  @override
  Future<List<Work>> search(String keyword, {int page = 1}) async {
    final res = await _dio.get('/anime', queryParameters: {
      'q': keyword,
      'sfw': true,
      'limit': perPage,
      'page': page,
    });
    return parseList(res.data);
  }

  @override
  Future<Work> detail(Work work) async {
    final malId = work.malId;
    if (malId == null) {
      throw StateError('JikanProvider.detail requires malId');
    }
    final res = await _dio.get('/anime/$malId/full');
    return parseItem((res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
  }

  @visibleForTesting
  static List<Work> parseList(dynamic data) {
    final list = (data is Map ? data['data'] : data) as List<dynamic>? ?? [];
    return list.map((e) => parseItem(e as Map<String, dynamic>)).toList();
  }

  @visibleForTesting
  static Work parseItem(Map<String, dynamic> item) {
    final malId = item['mal_id'] as int;
    final jpg = ((item['images'] as Map<String, dynamic>?)?['jpg']) as Map<String, dynamic>?;
    final genres = (item['genres'] as List<dynamic>?)
            ?.map((g) => (g as Map<String, dynamic>)['name'] as String)
            .toList() ??
        [];
    final studios = (item['studios'] as List<dynamic>?)
            ?.map((s) => (s as Map<String, dynamic>)['name'] as String)
            .toList() ??
        [];

    return Work(
      id: 'jikan_$malId',
      sourceId: 'jikan',
      sourceName: 'MyAnimeList',
      type: WorkType.anime,
      title: _title(item),
      coverUrl: jpg?['large_image_url'] as String? ?? jpg?['image_url'] as String?,
      summary: _clean(item['synopsis'] as String?),
      tags: genres,
      extra: {
        'malId': malId,
        'titleNative': item['title_japanese'],
        'titleEnglish': item['title_english'],
        'score': item['score'],
        'episodes': item['episodes'],
        'status': item['status'],
        'seasonYear': item['year'],
        'studios': studios,
        'bannerUrl': null,
      },
    );
  }

  static String _title(Map<String, dynamic> item) {
    final t = item['title'] as String?;
    if (t != null && t.trim().isNotEmpty) return t;
    return (item['title_english'] as String?) ?? (item['title_japanese'] as String?) ?? '';
  }

  static String? _clean(String? s) {
    if (s == null || s.isEmpty) return null;
    return s.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll('&amp;', '&').trim();
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/core/metadata/jikan_provider_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit (only if user asked)**

```bash
git add lib/core/metadata/metadata_provider.dart lib/core/metadata/jikan_provider.dart test/core/metadata/jikan_provider_test.dart
git commit -m "feat(metadata): add MetadataProvider interface and JikanProvider"
```

---

### Task 3: AniListProvider

**Files:**
- Create: `lib/core/metadata/anilist_provider.dart`
- Test: `test/core/metadata/anilist_provider_test.dart`

**Interfaces:**
- Consumes: `MetadataProvider`, `AnimeFeed` (Task 2).
- Produces: `AniListProvider({Dio? dio})` with `static List<Work> parsePage(Map<String, dynamic> data)`, `static List<Work> parseAiring(Map<String, dynamic> data)`, `static Work parseMedia(Map<String, dynamic> m)`.

- [ ] **Step 1: Write the failing test**

Create `test/core/metadata/anilist_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/metadata/anilist_provider.dart';

void main() {
  final media = {
    'id': 21,
    'title': {'romaji': 'ONE PIECE', 'english': 'One Piece', 'native': 'ワンピース'},
    'coverImage': {'extraLarge': 'https://img/xl.jpg', 'large': 'https://img/l.jpg'},
    'bannerImage': 'https://img/banner.jpg',
    'description': 'A pirate <i>adventure</i>.',
    'genres': ['Action', 'Adventure'],
    'episodes': 1000,
    'duration': 24,
    'status': 'RELEASING',
    'season': 'FALL',
    'seasonYear': 1999,
    'format': 'TV',
    'averageScore': 88,
    'studios': {'nodes': [{'name': 'Toei Animation'}]},
  };

  test('parsePage maps AniList media to Work items', () {
    final works = AniListProvider.parsePage({
      'Page': {'media': [media]}
    });

    expect(works, hasLength(1));
    final w = works.first;
    expect(w.id, 'anilist_21');
    expect(w.title, 'ワンピース');
    expect(w.coverUrl, 'https://img/xl.jpg');
    expect(w.bannerUrl, 'https://img/banner.jpg');
    expect(w.summary, 'A pirate adventure.');
    expect(w.tags, ['Action', 'Adventure']);
    expect(w.anilistId, 21);
    expect(w.extra['score'], 88);
    expect(w.extra['episodes'], 1000);
    expect(w.extra['seasonYear'], 1999);
    expect(w.extra['format'], 'TV');
    expect(w.extra['studios'], ['Toei Animation']);
  });

  test('parseAiring reads nested media', () {
    final works = AniListProvider.parseAiring({
      'Page': {
        'airingSchedules': [
          {'airingAt': 123, 'episode': 5, 'media': media}
        ]
      }
    });
    expect(works.single.id, 'anilist_21');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/metadata/anilist_provider_test.dart`
Expected: FAIL — `anilist_provider.dart` not found.

- [ ] **Step 3: Implement AniListProvider**

Create `lib/core/metadata/anilist_provider.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../models/work.dart';
import 'metadata_provider.dart';

class AniListProvider implements MetadataProvider {
  static const perPage = 25;
  static const _endpoint = 'https://graphql.anilist.co';

  final Dio _dio;

  AniListProvider({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 20),
              headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            ));

  @override
  String get id => 'anilist';

  static const _media = '''
    id
    title { romaji english native }
    coverImage { extraLarge large color }
    bannerImage
    description(asHtml: false)
    genres
    episodes
    duration
    status
    season
    seasonYear
    format
    averageScore
    popularity
    studios(isMain: true) { nodes { name } }
  ''';

  Future<Map<String, dynamic>> _post(String query, [Map<String, dynamic>? variables]) async {
    final res = await _dio.post(_endpoint, data: {'query': query, 'variables': variables ?? {}});
    final body = res.data as Map<String, dynamic>;
    if (body['errors'] != null) {
      throw Exception('AniList error: ${body['errors']}');
    }
    return body['data'] as Map<String, dynamic>;
  }

  @override
  Future<List<Work>> feed(AnimeFeed feed, {int page = 1}) async {
    switch (feed) {
      case AnimeFeed.trending:
        final data = await _post(
          'query(\$page:Int,\$perPage:Int){Page(page:\$page,perPage:\$perPage){'
          'media(type:ANIME,sort:TRENDING_DESC,isAdult:false){$_media}}}',
          {'page': page, 'perPage': perPage},
        );
        return parsePage(data);
      case AnimeFeed.season:
        final (season, year) = _currentSeason();
        final data = await _post(
          'query(\$page:Int,\$perPage:Int,\$season:MediaSeason,\$seasonYear:Int){'
          'Page(page:\$page,perPage:\$perPage){media(type:ANIME,season:\$season,'
          'seasonYear:\$seasonYear,sort:POPULARITY_DESC,isAdult:false){$_media}}}',
          {'page': page, 'perPage': perPage, 'season': season, 'seasonYear': year},
        );
        return parsePage(data);
      case AnimeFeed.today:
        final now = DateTime.now();
        final start = DateTime(now.year, now.month, now.day);
        final end = start.add(const Duration(days: 1));
        final data = await _post(
          'query(\$start:Int,\$end:Int){Page(perPage:$perPage){'
          'airingSchedules(airingAt_greater:\$start,airingAt_lesser:\$end,sort:TIME){'
          'media{$_media}}}}',
          {
            'start': start.millisecondsSinceEpoch ~/ 1000,
            'end': end.millisecondsSinceEpoch ~/ 1000,
          },
        );
        return parseAiring(data);
    }
  }

  @override
  Future<List<Work>> search(String keyword, {int page = 1}) async {
    final data = await _post(
      'query(\$page:Int,\$perPage:Int,\$search:String){Page(page:\$page,perPage:\$perPage){'
      'media(type:ANIME,search:\$search,sort:SEARCH_MATCH,isAdult:false){$_media}}}',
      {'page': page, 'perPage': perPage, 'search': keyword},
    );
    return parsePage(data);
  }

  @override
  Future<Work> detail(Work work) async {
    final variables = <String, dynamic>{};
    final String query;
    if (work.anilistId != null) {
      query = 'query(\$id:Int){Media(id:\$id,type:ANIME){$_media}}';
      variables['id'] = work.anilistId;
    } else if (work.malId != null) {
      query = 'query(\$idMal:Int){Media(idMal:\$idMal,type:ANIME){$_media}}';
      variables['idMal'] = work.malId;
    } else {
      throw StateError('AniListProvider.detail requires anilistId or malId');
    }
    final data = await _post(query, variables);
    return parseMedia(data['Media'] as Map<String, dynamic>);
  }

  static (String, int) _currentSeason() {
    final now = DateTime.now();
    final season = switch (now.month) {
      >= 1 && <= 3 => 'WINTER',
      >= 4 && <= 6 => 'SPRING',
      >= 7 && <= 9 => 'SUMMER',
      _ => 'FALL',
    };
    return (season, now.year);
  }

  @visibleForTesting
  static List<Work> parsePage(Map<String, dynamic> data) {
    final page = data['Page'] as Map<String, dynamic>?;
    final media = (page?['media'] as List<dynamic>?) ?? [];
    return media.map((m) => parseMedia(m as Map<String, dynamic>)).toList();
  }

  @visibleForTesting
  static List<Work> parseAiring(Map<String, dynamic> data) {
    final page = data['Page'] as Map<String, dynamic>?;
    final schedules = (page?['airingSchedules'] as List<dynamic>?) ?? [];
    return schedules
        .map((s) => parseMedia((s as Map<String, dynamic>)['media'] as Map<String, dynamic>))
        .toList();
  }

  @visibleForTesting
  static Work parseMedia(Map<String, dynamic> m) {
    final id = m['id'] as int;
    final title = (m['title'] as Map<String, dynamic>?) ?? {};
    final cover = m['coverImage'] as Map<String, dynamic>?;
    final studios = ((m['studios'] as Map<String, dynamic>?)?['nodes'] as List<dynamic>?)
            ?.map((s) => (s as Map<String, dynamic>)['name'] as String)
            .toList() ??
        [];
    final native = title['native'] as String?;
    final romaji = title['romaji'] as String?;
    final english = title['english'] as String?;
    final display = (native != null && native.isNotEmpty)
        ? native
        : (romaji != null && romaji.isNotEmpty ? romaji : (english ?? ''));

    return Work(
      id: 'anilist_$id',
      sourceId: 'anilist',
      sourceName: 'AniList',
      type: WorkType.anime,
      title: display,
      coverUrl: cover?['extraLarge'] as String? ?? cover?['large'] as String?,
      summary: _strip(m['description'] as String?),
      tags: (m['genres'] as List<dynamic>?)?.cast<String>() ?? [],
      extra: {
        'anilistId': id,
        'titleNative': native,
        'titleEnglish': english,
        'bannerUrl': m['bannerImage'],
        'score': m['averageScore'],
        'episodes': m['episodes'],
        'duration': m['duration'],
        'status': m['status'],
        'seasonYear': m['seasonYear'],
        'format': m['format'],
        'studios': studios,
      },
    );
  }

  static String? _strip(String? s) {
    if (s == null || s.isEmpty) return null;
    return s
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .trim();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/metadata/anilist_provider_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit (only if user asked)**

```bash
git add lib/core/metadata/anilist_provider.dart test/core/metadata/anilist_provider_test.dart
git commit -m "feat(metadata): add AniListProvider"
```

---

### Task 4: MetadataService (fallback + cache)

**Files:**
- Create: `lib/core/metadata/metadata_service.dart`
- Test: `test/core/metadata/metadata_service_test.dart`

**Interfaces:**
- Consumes: `MetadataProvider`, `AnimeFeed`, `AniListProvider`, `JikanProvider`.
- Produces: `MetadataService({MetadataProvider? anilist, MetadataProvider? jikan, DateTime Function()? now})` with `Future<List<Work>> feed(AnimeFeed, {int page})`, `Future<List<Work>> search(String, {int page})`, `Future<Work> detail(Work)`.

- [ ] **Step 1: Write the failing test**

Create `test/core/metadata/metadata_service_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/metadata/metadata_provider.dart';
import 'package:acgnhub/core/metadata/metadata_service.dart';
import 'package:acgnhub/core/models/work.dart';

class _FakeProvider implements MetadataProvider {
  @override
  final String id;
  bool fail;
  int calls = 0;
  _FakeProvider(this.id, {this.fail = false});

  List<Work> _items() => [
        Work(id: '${id}_1', sourceId: id, sourceName: id, type: WorkType.anime, title: id),
      ];

  @override
  Future<List<Work>> feed(AnimeFeed feed, {int page = 1}) async {
    calls++;
    if (fail) throw DioException(requestOptions: RequestOptions(path: '/$id'));
    return _items();
  }

  @override
  Future<List<Work>> search(String keyword, {int page = 1}) async {
    calls++;
    if (fail) throw DioException(requestOptions: RequestOptions(path: '/$id'));
    return _items();
  }

  @override
  Future<Work> detail(Work work) async {
    calls++;
    if (fail) throw DioException(requestOptions: RequestOptions(path: '/$id'));
    return work;
  }
}

void main() {
  test('falls back to Jikan when AniList fails, then skips AniList for 10 min', () async {
    var now = DateTime(2026, 9, 10, 12);
    final anilist = _FakeProvider('anilist', fail: true);
    final jikan = _FakeProvider('jikan');
    final service = MetadataService(anilist: anilist, jikan: jikan, now: () => now);

    final first = await service.feed(AnimeFeed.trending);
    expect(first.single.sourceId, 'jikan');
    expect(anilist.calls, 1);
    expect(jikan.calls, 1);

    // Within 10 min: different key, AniList is skipped entirely.
    await service.feed(AnimeFeed.trending, page: 2);
    expect(anilist.calls, 1);
    expect(jikan.calls, 2);

    // After 10 min: AniList is retried (now healthy).
    anilist.fail = false;
    now = now.add(const Duration(minutes: 11));
    final third = await service.feed(AnimeFeed.trending, page: 3);
    expect(third.single.sourceId, 'anilist');
    expect(anilist.calls, 2);
  });

  test('caches identical calls for 5 minutes', () async {
    final anilist = _FakeProvider('anilist');
    final jikan = _FakeProvider('jikan');
    final service = MetadataService(anilist: anilist, jikan: jikan);

    await service.feed(AnimeFeed.trending);
    await service.feed(AnimeFeed.trending);
    expect(anilist.calls, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/metadata/metadata_service_test.dart`
Expected: FAIL — `metadata_service.dart` not found.

- [ ] **Step 3: Implement MetadataService**

Create `lib/core/metadata/metadata_service.dart`:

```dart
import 'package:dio/dio.dart';
import '../models/work.dart';
import 'anilist_provider.dart';
import 'jikan_provider.dart';
import 'metadata_provider.dart';

class MetadataService {
  final MetadataProvider anilist;
  final MetadataProvider jikan;
  final DateTime Function() _now;

  static const _disableDuration = Duration(minutes: 10);
  static const _cacheTtl = Duration(minutes: 5);

  DateTime? _anilistDisabledUntil;
  final Map<String, _CacheEntry> _cache = {};

  MetadataService({
    MetadataProvider? anilist,
    MetadataProvider? jikan,
    DateTime Function()? now,
  })  : anilist = anilist ?? AniListProvider(),
        jikan = jikan ?? JikanProvider(),
        _now = now ?? DateTime.now;

  Future<List<Work>> feed(AnimeFeed feed, {int page = 1}) =>
      _run('feed:${feed.name}:$page', (p) => p.feed(feed, page: page));

  Future<List<Work>> search(String keyword, {int page = 1}) =>
      _run('search:$keyword:$page', (p) => p.search(keyword, page: page));

  Future<Work> detail(Work work) =>
      _run('detail:${work.anilistId ?? work.malId ?? work.id}', (p) => p.detail(work));

  Future<T> _run<T>(String key, Future<T> Function(MetadataProvider) op) async {
    final cached = _cache[key];
    if (cached != null && _now().difference(cached.at) < _cacheTtl) {
      return cached.value as T;
    }

    final skipAniList =
        _anilistDisabledUntil != null && _now().isBefore(_anilistDisabledUntil!);
    final order = skipAniList ? [jikan, anilist] : [anilist, jikan];

    Object? lastError;
    for (final provider in order) {
      try {
        final result = await op(provider);
        if (provider == anilist) _anilistDisabledUntil = null;
        _cache[key] = _CacheEntry(_now(), result);
        return result;
      } catch (e) {
        lastError = e;
        if (provider == anilist && e is DioException) {
          _anilistDisabledUntil = _now().add(_disableDuration);
        }
      }
    }
    throw Exception('All metadata providers failed: $lastError');
  }
}

class _CacheEntry {
  final DateTime at;
  final Object? value;
  _CacheEntry(this.at, this.value);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/metadata/metadata_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit (only if user asked)**

```bash
git add lib/core/metadata/metadata_service.dart test/core/metadata/metadata_service_test.dart
git commit -m "feat(metadata): add MetadataService with fallback and cache"
```

---

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

### Task 6: Rewrite anime home to use feeds

**Files:**
- Modify: `lib/modules/anime/anime_home.dart`

**Interfaces:**
- Consumes: `animeFeedProvider`, `metadataServiceProvider`, `AnimeFeed`, `WorkCard`, `ShimmerLoader`, `EmptyState`, `AnimeDetailPage` (Task 8 — until then use `BangumiDetailPage`; see note).

**Note:** This task references the detail page. Do Task 8's rename first OR keep importing `bangumi_detail_page.dart`/`BangumiDetailPage` here and switch in Task 8. To keep each task green, keep using `BangumiDetailPage` in this task; Task 8 updates the import.

- [ ] **Step 1: Replace the file**

Replace the entire contents of `lib/modules/anime/anime_home.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'anime_providers.dart';
import 'bangumi_detail_page.dart';
import '../../core/metadata/metadata_provider.dart';
import '../../core/widgets/work_card.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/models/work.dart';

class AnimeHomePage extends ConsumerStatefulWidget {
  const AnimeHomePage({super.key});

  @override
  ConsumerState<AnimeHomePage> createState() => _AnimeHomePageState();
}

class _AnimeHomePageState extends ConsumerState<AnimeHomePage> {
  static const _accent = Color(0xFF007AFF);
  static const _perPage = 25;

  AnimeFeed _feed = AnimeFeed.trending;
  final _scroll = ScrollController();
  final List<Work> _extra = [];
  int _page = 1;
  bool _loadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400 && _hasMore && !_loadingMore) {
      _loadMore();
    }
  }

  void _selectFeed(AnimeFeed feed) {
    if (_feed == feed) return;
    setState(() {
      _feed = feed;
      _extra.clear();
      _page = 1;
      _hasMore = true;
      _loadingMore = false;
    });
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final next = await ref.read(metadataServiceProvider).feed(_feed, page: _page + 1);
      if (!mounted) return;
      setState(() {
        _page++;
        _extra.addAll(next);
        _hasMore = next.length >= _perPage;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() { _loadingMore = false; _hasMore = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(animeFeedProvider(_feed));
    final cs = Theme.of(context).colorScheme;

    return async.when(
      loading: () => const ShimmerLoader(),
      error: (_, __) => EmptyState(
        icon: Icons.cloud_off_rounded,
        message: '加载失败',
        actionLabel: '重试',
        onAction: () => ref.invalidate(animeFeedProvider(_feed)),
      ),
      data: (works) {
        final items = [...works, ..._extra];
        return RefreshIndicator(
          onRefresh: () async {
            setState(() { _extra.clear(); _page = 1; _hasMore = true; });
            ref.invalidate(animeFeedProvider(_feed));
          },
          child: CustomScrollView(
            controller: _scroll,
            slivers: [
              if (items.isNotEmpty) _hero(items.first),
              _pills(),
              _sectionTitle(_label, cs),
              items.isEmpty
                  ? SliverToBoxAdapter(
                      child: SizedBox(
                        height: 300,
                        child: EmptyState(icon: Icons.live_tv_rounded, message: '暂无内容'),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.66,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => i >= items.length
                              ? null
                              : WorkCard(
                                  work: items[i],
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => BangumiDetailPage(work: items[i])),
                                  ),
                                ),
                          childCount: items.length,
                        ),
                      ),
                    ),
              if (_hasMore)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _accent.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String get _label => switch (_feed) {
        AnimeFeed.trending => '热门推荐',
        AnimeFeed.season => '本季新番',
        AnimeFeed.today => '今日放送',
      };

  Widget _hero(Work work) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => BangumiDetailPage(work: work)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 240,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (work.coverUrl != null && work.coverUrl!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: work.coverUrl!,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 300),
                      errorWidget: (_, __, ___) => Container(color: const Color(0xFF1C1C1E)),
                    )
                  else
                    Container(color: const Color(0xFF1C1C1E)),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                          stops: const [0.5, 1],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          work.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          work.sourceName,
                          style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7)),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 36,
                          child: FilledButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => BangumiDetailPage(work: work)),
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(120, 36),
                              backgroundColor: _accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('查看详情', style: TextStyle(fontSize: 14)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pills() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          children: [
            _pill('热门推荐', AnimeFeed.trending),
            const SizedBox(width: 8),
            _pill('本季新番', AnimeFeed.season),
            const SizedBox(width: 8),
            _pill('今日放送', AnimeFeed.today),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, AnimeFeed feed) {
    final sel = _feed == feed;
    return GestureDetector(
      onTap: () => _selectFeed(feed),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? _accent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: sel ? null : Border.all(color: const Color(0xFFE5E5EA)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: sel ? Colors.white : const Color(0xFF8E8E93),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, ColorScheme cs) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Text(
          title,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: cs.onSurface, height: 1.4),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify build**

Run: `flutter analyze lib/modules/anime/anime_home.dart`
Expected: No errors.

- [ ] **Step 3: Commit (only if user asked)**

```bash
git add lib/modules/anime/anime_home.dart
git commit -m "feat(anime): drive home from AniList/Jikan feeds"
```

---

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

### Task 8: Rename and rewrite the detail page

**Files:**
- Create: `lib/modules/anime/anime_detail_page.dart`
- Delete: `lib/modules/anime/bangumi_detail_page.dart`
- Modify: `lib/modules/anime/anime_home.dart` (imports + class name)
- Modify: `lib/modules/anime/anime_search.dart` (imports + class name)

**Interfaces:**
- Consumes: `metadataServiceProvider`, `Work` (with `anilistId`, `malId`, `bannerUrl`), `AnimeSearchPage`.
- Produces: `class AnimeDetailPage extends ConsumerStatefulWidget { final Work work; }`.

- [ ] **Step 1: Create the new detail page**

Create `lib/modules/anime/anime_detail_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/work.dart';
import 'anime_providers.dart';
import 'anime_search.dart';

class AnimeDetailPage extends ConsumerStatefulWidget {
  final Work work;
  const AnimeDetailPage({super.key, required this.work});

  @override
  ConsumerState<AnimeDetailPage> createState() => _AnimeDetailPageState();
}

class _AnimeDetailPageState extends ConsumerState<AnimeDetailPage> {
  Work _work;
  bool _loading = true;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _work = widget.work;
    _load();
  }

  Future<void> _load() async {
    try {
      final enriched = await ref.read(metadataServiceProvider).detail(widget.work);
      if (mounted) setState(() { _work = enriched; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final w = _work;
    final score = w.extra['score'] as num?;
    final episodes = w.extra['episodes'] as int?;
    final seasonYear = w.extra['seasonYear'] as int?;
    final format = w.extra['format'] as String?;
    final status = w.extra['status'] as String?;
    final banner = w.bannerUrl;
    final heroImage = (banner != null && banner.isNotEmpty) ? banner : w.coverUrl;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Column(
        children: [
          _header(w, cs),
          Expanded(
            child: CustomScrollView(
              slivers: [
                _heroImage(heroImage, cs),
                _infoSection(w, cs, score, episodes, seasonYear),
                if (w.tags.isNotEmpty) _tagsRow(w.tags),
                _summarySection(w.summary, cs),
                _playSection(w, cs),
                _metaSection(cs, format, status, seasonYear),
              ],
            ),
          ),
          _bottomBar(w),
        ],
      ),
    );
  }

  Widget _header(Work w, ColorScheme cs) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
            splashRadius: 20,
          ),
          Expanded(
            child: Text(
              w.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroImage(String? cover, ColorScheme cs) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 220,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (cover != null && cover.isNotEmpty)
              CachedNetworkImage(
                imageUrl: cover,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(color: cs.primary.withValues(alpha: 0.1)),
              )
            else
              Container(color: cs.primary.withValues(alpha: 0.1)),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, const Color(0xFFF2F2F7)],
                    stops: const [0.6, 1],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoSection(Work w, ColorScheme cs, num? score, int? episodes, int? seasonYear) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 110,
                height: 154,
                child: w.coverUrl != null && w.coverUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: w.coverUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _coverPlaceholder(cs),
                      )
                    : _coverPlaceholder(cs),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    w.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.35),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (_loading)
                    SizedBox(
                      width: 100,
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                      ),
                    )
                  else ...[
                    if (score != null) _metaChip(Icons.star_rounded, score.toStringAsFixed(1), Colors.amber),
                    if (episodes != null) ...[
                      const SizedBox(height: 6),
                      _metaChip(Icons.live_tv_rounded, '$episodes 话', const Color(0xFF007AFF)),
                    ],
                    if (seasonYear != null) ...[
                      const SizedBox(height: 6),
                      _metaChip(Icons.calendar_today_rounded, '$seasonYear', const Color(0xFF5856D6)),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _coverPlaceholder(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary.withValues(alpha: 0.1), cs.tertiary.withValues(alpha: 0.05)],
        ),
      ),
      child: Center(child: Icon(Icons.image_outlined, size: 24, color: cs.primary.withValues(alpha: 0.2))),
    );
  }

  Widget _tagsRow(List<String> tags) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: tags
              .map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFE8F0FE), borderRadius: BorderRadius.circular(20)),
                    child: Text(t, style: const TextStyle(fontSize: 11, color: Color(0xFF007AFF), fontWeight: FontWeight.w500)),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _summarySection(String? summary, ColorScheme cs) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('简介', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface)),
            const SizedBox(height: 8),
            if (_loading)
              SizedBox(
                width: 100,
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                ),
              )
            else if (summary == null || summary.isEmpty)
              Text('暂无简介数据', style: TextStyle(fontSize: 13.5, color: cs.onSurface.withValues(alpha: 0.35)))
            else
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Text(
                  summary,
                  maxLines: _expanded ? null : 4,
                  overflow: _expanded ? null : TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, height: 1.65, color: cs.onSurface.withValues(alpha: 0.7)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _playSection(Work w, ColorScheme cs) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('播放', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    final kw = w.extra['keyword'] as String? ?? w.title;
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AnimeSearchPage(initialKeyword: kw)),
                    );
                  },
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('搜索播放资源'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metaSection(ColorScheme cs, String? format, String? status, int? seasonYear) {
    final rows = <MapEntry<String, String>>[
      if (format != null) MapEntry('类型', format),
      if (status != null) MapEntry('状态', _statusLabel(status)),
      if (seasonYear != null) MapEntry('年份', '$seasonYear'),
    ];
    if (rows.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('详细信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface)),
                const SizedBox(height: 12),
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 64,
                          child: Text(row.key, style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.45))),
                        ),
                        Expanded(child: Text(row.value, style: TextStyle(fontSize: 13, color: cs.onSurface))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
        'RELEASING' => '连载中',
        'FINISHED' => '已完结',
        'NOT_YET_RELEASED' => '未播出',
        'CANCELLED' => '已取消',
        'HIATUS' => '停更',
        _ => status,
      };

  Widget _bottomBar(Work w) {
    final anilistId = w.anilistId;
    final malId = w.malId;
    final hasLink = anilistId != null || malId != null;
    final label = anilistId != null ? '在 AniList 查看' : '在 MyAnimeList 查看';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        border: Border(top: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton.icon(
          onPressed: hasLink
              ? () async {
                  final uri = anilistId != null
                      ? Uri.parse('https://anilist.co/anime/$anilistId')
                      : Uri.parse('https://myanimelist.net/anime/$malId');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              : null,
          icon: const Icon(Icons.open_in_new_rounded, size: 20),
          label: Text(label),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Delete the old page**

Run: `Remove-Item -LiteralPath "D:\ACGNhub\lib\modules\anime\bangumi_detail_page.dart"`

- [ ] **Step 3: Update imports and class names**

In `lib/modules/anime/anime_home.dart`, replace:
- `import 'bangumi_detail_page.dart';` → `import 'anime_detail_page.dart';`
- every `BangumiDetailPage(` → `AnimeDetailPage(`

In `lib/modules/anime/anime_search.dart`, replace:
- `import 'bangumi_detail_page.dart';` → `import 'anime_detail_page.dart';`
- every `BangumiDetailPage(` → `AnimeDetailPage(`

- [ ] **Step 4: Verify build**

Run: `flutter analyze lib`
Expected: No errors.

- [ ] **Step 5: Commit (only if user asked)**

```bash
git add lib/modules/anime/anime_detail_page.dart lib/modules/anime/anime_home.dart lib/modules/anime/anime_search.dart
git rm lib/modules/anime/bangumi_detail_page.dart
git commit -m "feat(anime): rename detail page and drive it from metadata service"
```

---

### Task 9: Remove Bangumi entirely

**Files:**
- Delete: `lib/modules/anime/bangumi_service.dart`
- Delete: `assets/bangumi_calendar.json`
- Modify: `lib/modules/anime/anime_providers.dart`
- Modify: `pubspec.yaml`

**Interfaces:**
- Removes: `trendingAnimeProvider`, `bangumiServiceProvider`, `BangumiService`.

- [ ] **Step 1: Delete the service and asset**

Run:
```powershell
Remove-Item -LiteralPath "D:\ACGNhub\lib\modules\anime\bangumi_service.dart"
Remove-Item -LiteralPath "D:\ACGNhub\assets\bangumi_calendar.json"
```

- [ ] **Step 2: Remove Bangumi providers**

In `lib/modules/anime/anime_providers.dart`:
- Remove `import 'bangumi_service.dart';`
- Remove the `_stableCoverUrl` helper
- Remove the entire `trendingAnimeProvider` definition
- Remove the `bangumiServiceProvider` definition

Keep `sourceManagerProvider`, `animeSourceListProvider`, `metadataServiceProvider`, `animeFeedProvider`.

The file should end up as:

```dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../core/metadata/metadata_provider.dart';
import '../../core/metadata/metadata_service.dart';
import '../../core/source/source_manager.dart';
import '../../core/models/work.dart';
import 'anime_source.dart';
import 'anime_rule.dart';

final sourceManagerProvider = Provider<SourceManager>((ref) {
  return SourceManager();
});

final animeSourceListProvider = FutureProvider<List<AnimeSource>>((ref) async {
  final manager = ref.read(sourceManagerProvider);
  final manifestJson = await rootBundle.loadString('AssetManifest.json');
  final manifest = json.decode(manifestJson) as Map<String, dynamic>;
  final ruleFiles = manifest.keys.where((k) => k.startsWith('assets/rules/') && k.endsWith('.json')).toList();
  for (final file in ruleFiles) {
    final jsonString = await rootBundle.loadString(file);
    final rule = AnimeRule.fromJsonString(jsonString);
    manager.register(AnimeSource(rule));
  }
  return manager.getByType(WorkType.anime).cast<AnimeSource>();
});

final metadataServiceProvider = Provider<MetadataService>((ref) => MetadataService());

final animeFeedProvider = FutureProvider.family<List<Work>, AnimeFeed>((ref, feed) {
  return ref.watch(metadataServiceProvider).feed(feed);
});
```

- [ ] **Step 3: Remove the asset from pubspec**

In `pubspec.yaml`, remove the line `    - assets/bangumi_calendar.json` under `assets:`.

- [ ] **Step 4: Verify no references remain**

Run: `flutter analyze lib`
Expected: No errors and no references to `bangumi`.

Also run: `git grep -i bangumi -- lib` (expected: no output).

- [ ] **Step 5: Commit (only if user asked)**

```bash
git add -A
git commit -m "chore: remove Bangumi metadata integration"
```

---

### Task 10: Final verification

**Files:** none (verification only).

- [ ] **Step 1: Analyze**

Run: `flutter analyze lib`
Expected: `No issues found!`

- [ ] **Step 2: Run the full test suite**

Run: `flutter test`
Expected: All tests pass (existing + the 3 new metadata test files + the extended Work test).

- [ ] **Step 3: Build**

Run: `flutter build windows --debug`
Expected: `Built build\windows\x64\runner\Debug\acgnhub.exe`

- [ ] **Step 4: Smoke-run (manual)**

Run: `flutter run -d windows`
Expected: Home shows 热门推荐 (AniList down → Jikan data), pills switch feeds, search returns results, detail shows summary/tags/meta, CTA opens AniList/MAL. No exceptions in console.

---

## Self-Review

- **Spec coverage:** interface + AnimeFeed (Task 2), AniList queries/mapping (Task 3), Jikan endpoints/mapping (Task 2), fallback + 10-min disable + 5-min cache (Task 4), Work getters (Task 1), providers (Task 5), home pills + infinite scroll (Task 6), search (Task 7), detail rename + CTA + banner (Task 8), Bangumi removal (Task 9), tests + analyze + build (Tasks 1–4, 10). All spec sections covered.
- **Placeholders:** none.
- **Type consistency:** `MetadataProvider.feed/search/detail`, `AnimeFeed`, `MetadataService` constructor params, `AniListProvider.parsePage/parseAiring/parseMedia`, `JikanProvider.parseList/parseItem`, `Work.anilistId/malId/bannerUrl` are used consistently across tasks.
