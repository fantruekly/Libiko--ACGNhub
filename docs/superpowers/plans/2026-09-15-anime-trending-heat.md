# 动漫「热门推荐」改为 Bangumi 热度榜 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把动漫页「热门推荐」从"当季放送日历按评分排序"改为 Bangumi 全部动画按热度（heat）排序的榜单，并支持滚动加载更多。

**Architecture:** `BangumiProvider.feed(AnimeFeed.trending)` 改调 Bangumi v0 `POST /v0/search/subjects`（`sort=heat`、`type=[2]`、`nsfw=false`，每页 20、按 `offset` 分页）；`parseSearch` 扩展为同时兼容 v0 的 `{data:[...]}` 与旧接口的 `{list:[...]}`；`_FeedView._perPage` 由 25 调到 20，让"每页 20"的热度榜在滚到底时继续加载。本季新番 / 今日放送 / 降级源（AniList、Jikan）不变。

**Tech Stack:** Flutter/Dart 3.6、Riverpod、Dio、Bangumi API v0。

## Global Constraints

- 运行环境：Flutter 在 `C:\flutter\bin`；命令前缀 `$env:Path = "C:\flutter\bin;$env:Path";`；工作目录 `D:\ACGNhub`。
- 每个任务结束必须：`flutter analyze lib test` 无问题 + `flutter test` 全绿。
- 每个任务结束提交并推送：`git add <精确文件>` → `git commit` → `git push origin dev`。
- 不新增依赖；不改 `pubspec.yaml`。
- 不加代码注释（与现有风格一致者除外）。中文 UI 文案。
- Bangumi 请求固定：`POST /v0/search/subjects`，query `limit=20`、`offset=(page-1)*20`，body `{keyword:'', sort:'heat', filter:{type:[2], nsfw:false}}`，`Content-Type: application/json`。
- 每页固定 20（接口上限）；结果集上限 1000。
- 不改 `MetadataService` 的缓存/限流/重试/熔断；不改 AniList、Jikan 的 `feed`。

---

### Task 1: Bangumi 热门推荐改为热度榜（含分页）

**Files:**
- Modify: `lib/core/metadata/bangumi_provider.dart`
- Modify: `lib/modules/anime/anime_home.dart:88`
- Test: `test/core/metadata/bangumi_provider_test.dart`

**Interfaces:**
- Consumes: 现有 `_dio`、`_parseItem`、`BangumiProvider.parseSearch`、`AnimeFeed`（`lib/core/metadata/metadata_provider.dart:3`）。
- Produces: `BangumiProvider.feed(AnimeFeed.trending, {int page = 1})` 走 v0 搜索接口；`parseSearch(dynamic)` 兼容 `{data: [...]}` 与 `{list: [...]}`。签名不变。

- [ ] **Step 1: 写失败测试**

编辑 `test/core/metadata/bangumi_provider_test.dart`。

(a) 在 `_FakeAdapter` 类之后新增一个会记录请求的适配器：

```dart
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.data);
  final dynamic data;
  late RequestOptions last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
```

(b) 把 `parseSearch reads data.list` 这个测试：

```dart
  test('parseSearch reads data.list', () {
    final works = BangumiProvider.parseSearch({
      'list': [calendarItem]
    });
    expect(works.single.id, 'bangumi_456080');
  });
```

替换为：

```dart
  test('parseSearch reads data.list and data.data', () {
    expect(
        BangumiProvider.parseSearch({
          'list': [calendarItem]
        }).single.id,
        'bangumi_456080');
    expect(
        BangumiProvider.parseSearch({
          'data': [calendarItem]
        }).single.id,
        'bangumi_456080');
  });
```

(c) 把 `feed(today) filters ... trending sorts by score` 这个测试：

```dart
  test(
      'feed(today) filters to the injected weekday; page>1 is empty; trending sorts by score',
      () async {
    final days = [
      {
        'weekday': {'id': 4},
        'items': [
          {
            'id': 1,
            'name': 'A',
            'name_cn': '甲',
            'rating': {'score': 8.0}
          }
        ]
      },
      {
        'weekday': {'id': 5},
        'items': [
          {
            'id': 2,
            'name': 'B',
            'name_cn': '乙',
            'rating': {'score': 9.0}
          }
        ]
      },
    ];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.bgm.tv'))
      ..httpClientAdapter = _FakeAdapter(days);
    final provider = BangumiProvider(
        dio: dio, now: () => DateTime(2026, 9, 10)); // Thursday = weekday 4

    final today = await provider.feed(AnimeFeed.today);
    expect(today.single.id, 'bangumi_1');

    expect(await provider.feed(AnimeFeed.season, page: 2), isEmpty);

    final trending = await provider.feed(AnimeFeed.trending);
    expect(trending.first.id, 'bangumi_2'); // 9.0 before 8.0
  });
```

替换为（去掉 trending 断言）：

```dart
  test('feed(today) filters to the injected weekday; page>1 is empty', () async {
    final days = [
      {
        'weekday': {'id': 4},
        'items': [
          {
            'id': 1,
            'name': 'A',
            'name_cn': '甲',
            'rating': {'score': 8.0}
          }
        ]
      },
      {
        'weekday': {'id': 5},
        'items': [
          {
            'id': 2,
            'name': 'B',
            'name_cn': '乙',
            'rating': {'score': 9.0}
          }
        ]
      },
    ];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.bgm.tv'))
      ..httpClientAdapter = _FakeAdapter(days);
    final provider = BangumiProvider(
        dio: dio, now: () => DateTime(2026, 9, 10)); // Thursday = weekday 4

    final today = await provider.feed(AnimeFeed.today);
    expect(today.single.id, 'bangumi_1');

    expect(await provider.feed(AnimeFeed.season, page: 2), isEmpty);
  });
```

(d) 在 `main()` 内新增热度榜测试：

```dart
  test('feed(trending) posts to v0 search sorted by heat, paged by offset',
      () async {
    final subject = {
      'id': 8,
      'name': 'STEINS;GATE',
      'name_cn': '命运石之门',
      'summary': '秋叶原。',
      'date': '2011-04-06',
      'eps': 24,
      'rating': {'score': 9.0, 'rank': 1, 'total': 100},
      'images': {'large': 'http://lain.bgm.tv/pic/cover/l/x.jpg'},
    };
    final adapter = _RecordingAdapter({
      'data': [subject],
      'total': 1000,
      'limit': 20,
      'offset': 20,
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://api.bgm.tv'))
      ..httpClientAdapter = adapter;
    final provider = BangumiProvider(dio: dio);

    final works = await provider.feed(AnimeFeed.trending, page: 2);

    expect(adapter.last.path, '/v0/search/subjects');
    expect(adapter.last.queryParameters['limit'], 20);
    expect(adapter.last.queryParameters['offset'], 20);
    final rawBody = adapter.last.data;
    final body = (rawBody is String ? jsonDecode(rawBody) : rawBody)
        as Map<String, dynamic>;
    expect(body['keyword'], '');
    expect(body['sort'], 'heat');
    expect(body['filter'], {'type': [2], 'nsfw': false});
    final w = works.single;
    expect(w.id, 'bangumi_8');
    expect(w.title, '命运石之门');
    expect(w.extra['bangumiId'], 8);
    expect(w.extra['score'], closeTo(9.0, 0.001));
    expect(w.extra['airDate'], '2011-04-06');
    expect(w.extra['episodes'], 24);
  });
```

- [ ] **Step 2: 运行测试确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/metadata/bangumi_provider_test.dart`
Expected: 失败——`feed(trending)` 仍走 `/calendar`，请求路径不是 `/v0/search/subjects`（断言 `adapter.last.path` 失败）；`parseSearch({'data': [...]})` 返回空（断言失败）。

- [ ] **Step 3: 实现 provider 改动**

编辑 `lib/core/metadata/bangumi_provider.dart`。

(a) 在 `BangumiProvider` 内新增常量（放在 `static const _base = ...` 之后）：

```dart
  static const _heatPerPage = 20;
```

(b) 把整个 `feed` 方法：

```dart
  @override
  Future<List<Work>> feed(AnimeFeed feed, {int page = 1}) async {
    if (page > 1) return const [];
    final res = await _dio.get('/calendar');
    final days = res.data as List<dynamic>;
    switch (feed) {
      case AnimeFeed.today:
        return parseCalendar(days, onlyWeekday: _now().weekday);
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
```

替换为：

```dart
  @override
  Future<List<Work>> feed(AnimeFeed feed, {int page = 1}) async {
    if (feed == AnimeFeed.trending) {
      final res = await _dio.post(
        '/v0/search/subjects',
        queryParameters: {
          'limit': _heatPerPage,
          'offset': (page - 1) * _heatPerPage,
        },
        data: {
          'keyword': '',
          'sort': 'heat',
          'filter': {
            'type': [2],
            'nsfw': false,
          },
        },
        options: Options(contentType: Headers.jsonContentType),
      );
      return parseSearch(res.data);
    }
    if (page > 1) return const [];
    final res = await _dio.get('/calendar');
    final days = res.data as List<dynamic>;
    return feed == AnimeFeed.today
        ? parseCalendar(days, onlyWeekday: _now().weekday)
        : parseCalendar(days);
  }
```

(c) 把 `parseSearch`：

```dart
  @visibleForTesting
  static List<Work> parseSearch(dynamic data) {
    final list = ((data is Map ? data['list'] : data) as List<dynamic>?) ?? [];
    return list
        .map((e) => _parseItem(e as Map<String, dynamic>))
        .whereType<Work>()
        .toList();
  }
```

替换为：

```dart
  @visibleForTesting
  static List<Work> parseSearch(dynamic data) {
    final list =
        ((data is Map ? (data['list'] ?? data['data']) : data) as List<dynamic>?) ??
            [];
    return list
        .map((e) => _parseItem(e as Map<String, dynamic>))
        .whereType<Work>()
        .toList();
  }
```

- [ ] **Step 4: 运行测试确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/metadata/bangumi_provider_test.dart`
Expected: 全部通过。

- [ ] **Step 5: 调整 `_FeedView` 每页阈值**

编辑 `lib/modules/anime/anime_home.dart:88`，把：

```dart
  static const _perPage = 25;
```

替换为：

```dart
  static const _perPage = 20;
```

原因：`_loadMore` 用 `_hasMore = next.length >= _perPage` 判断是否还有下一页（`anime_home.dart:120`）。Bangumi 热度榜每页固定 20，阈值必须 ≤20 才能继续加载；AniList/Jikan 每页 25（`anilist_provider.dart:7`、`jikan_provider.dart:7`），阈值 20 对它们仍成立（满页 25 ≥ 20 继续，末页不足 20 停止）；本季新番/今日放送的 `page > 1` 返回空 → 立即停止，行为不变。

- [ ] **Step 6: 静态检查与全量测试**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: 全绿。

- [ ] **Step 7: 提交**

```bash
git add lib/core/metadata/bangumi_provider.dart lib/modules/anime/anime_home.dart test/core/metadata/bangumi_provider_test.dart
git commit -m "feat(anime): 热门推荐 uses Bangumi all-anime heat ranking"
git push origin dev
```

---

## 验证（任务完成后）

1. `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` 全绿。
2. `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug` 成功。
3. 启动应用 → 动漫 → 热门推荐：
   - 首屏是热度榜（应能看到 STEINS;GATE、ぼっち・ざ・ろっく！、葬送のフリーレン 这类高热度作品）。
   - 滚到底会自动加载下一页（共 20 条/页）。
   - 本季新番、今日放送行为与之前一致。

## 已知取舍

- 结果集上限 1000、每页固定 20（Bangumi 接口限制）。
- 过滤 `nsfw: false`（不含 R18）。
- v0 条目无顶层 `rank`，`extra['rank']` 为 null；代码中无人使用。
- 未给 `_FeedView` 的分页加 widget 测试（`_FeedView` 为私有、滚动触发依赖布局尺寸）；以全量测试 + 构建 + 手动滚动验证覆盖。
