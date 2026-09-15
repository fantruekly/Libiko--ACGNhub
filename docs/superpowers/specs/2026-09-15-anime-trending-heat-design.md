# 动漫「热门推荐」改为 Bangumi 热度榜设计

日期：2026-09-15
状态：已与用户确认
前置：`docs/superpowers/specs/2026-09-10-anime-metadata-anilist.md`（元数据服务与三源降级）

## 背景与目标

动漫页三个 tab（本季新番 / 热门推荐 / 今日放送）当前都由 Bangumi 的 `GET /calendar`（每周放送日历）提供，只是筛选/排序不同：本季新番取全部、今日放送按今天 weekday 过滤、热门推荐取全部后按 `rating.score` 降序（`lib/core/metadata/bangumi_provider.dart:30-48`）。

本增量把**热门推荐**改为 **Bangumi 全部动画按热度（heat）排序**的榜单，并支持滚动加载更多；本季新番、今日放送不变。

## 非目标

- 不改本季新番、今日放送。
- 不改 AniList / Jikan 降级源（`TRENDING_DESC` / `top/anime?filter=bypopularity` 本身即热度/人气排序，语义一致）。
- 不改 `MetadataService` 的缓存、限流、重试、熔断机制。
- 不新增依赖。

## Bangumi 接口（实测）

```
POST https://api.bgm.tv/v0/search/subjects?limit=20&offset=<(page-1)*20>
Content-Type: application/json

{ "keyword": "", "sort": "heat", "filter": { "type": [2], "nsfw": false } }
```

- 响应：`{ "data": [Subject...], "total": 1000, "limit": 20, "offset": 0 }`。
- `sort: "heat"` 返回按热度排序的全站动画（实测前几名为 STEINS;GATE、ぼっち・ざ・ろっく！、葬送のフリーレン、魔法少女まどか☆マギカ、氷菓）。
- `limit` 传 20/25/50/100 都只返回 **20** 条（接口上限）；`total` 恒为 **1000**（Bangumi 结果集上限）；分页用 `offset`。
- `keyword` 可为空字符串。
- `filter.nsfw: false` 过滤 R18。
- Subject 结构含 `id` / `name` / `name_cn` / `images.{large,common,...}` / `rating.score` / `eps` / `tags[].name` / `summary` / `date`，与现有 `BangumiProvider._parseItem`（`bangumi_provider.dart:169-207`）兼容。

## 改动

### `lib/core/metadata/bangumi_provider.dart`

- `feed(AnimeFeed.trending)`：改为

  ```dart
  final res = await _dio.post('/v0/search/subjects',
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
      options: Options(contentType: Headers.jsonContentType));
  return parseSearch(res.data);
  ```

  其中 `static const _heatPerPage = 20;`。删除原"取 `/calendar` + 按 `score` 排序"分支。
- `season` / `today` 保持现状（`GET /calendar`）。
- `parseSearch` 扩展为兼容两种响应形状：

  ```dart
  final list = ((data is Map ? (data['list'] ?? data['data']) : data)
          as List<dynamic>?) ??
      [];
  ```

  旧接口 `search()` 返回 `{list: [...]}`，v0 返回 `{data: [...]}`，两者都能解析。
- `_parseItem` 不改（v0 Subject 缺顶层 `rank`，`extra['rank']` 为 null；代码中无人使用 `rank`）。

### `lib/modules/anime/anime_home.dart`

- `_FeedView._perPage` 由 `25` 改为 `20`（`anime_home.dart:88`）。`_loadMore` 用 `_hasMore = next.length >= _perPage`（`anime_home.dart:120`）判断是否还有下一页；Bangumi 热度榜每页 20，阈值必须 ≤20 才会继续加载。
- AniList / Jikan 每页 25（`anilist_provider.dart:7`、`jikan_provider.dart:7`），阈值 20 对它们仍成立（满页 25 ≥ 20 → 继续；最后一页不足 20 → 停止）。
- 本季新番（`/calendar` 返回 111 条）与今日放送（9 条）行为不变：`page > 1` 返回空 → `_hasMore` 变 false。

## 错误处理

沿用 `MetadataService.feed`：首选 Bangumi 失败时按 `[bangumi, anilist, jikan]` 降级；全失败读持久缓存，`page == 1` 再退回 `assets/anime_seed.json`。单页失败不影响已加载的页。

## 测试

- `test/core/metadata/bangumi_provider_test.dart`（扩展）：
  - `feed(AnimeFeed.trending, page: 2)` 会 `POST /v0/search/subjects`，query `limit=20`、`offset=20`，body `sort == 'heat'`、`filter.type == [2]`、`filter.nsfw == false`；用 `{data: [subject]}` 响应断言返回 1 条且 `extra['bangumiId']` 正确。
  - `parseSearch` 对 `{data: [...]}`（v0）与 `{list: [...]}`（旧）都能解析。
  - `feed(AnimeFeed.season)` / `feed(AnimeFeed.today)` 仍请求 `/calendar`（回归保护）。
- `test/core/metadata/metadata_service_test.dart` 如涉及 feed 形状需相应更新（当前用注入的 fake provider，不受影响）。
- 现有测试保持通过。

## 后续迭代

1. 若需要，可把「热门推荐」拆成"热度榜 / 评分榜"两个排序。
2. 本季新番/今日放送目前无分页（日历单页），如需分页可另做。
