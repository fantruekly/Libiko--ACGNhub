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
