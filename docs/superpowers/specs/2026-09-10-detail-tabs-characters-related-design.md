# Detail Page Tabs: Characters & Related — Design

> Date: 2026-09-10
> Status: Approved (design)
> Scope: Anime detail page extra info (characters + voice actors, related works) and a tabbed layout.

## 1. Goal

Add main characters (with their voice actors) and related works to the anime detail page, organized into three tabs — **概览** (summary + playback + tags), **角色** (characters), **关联** (related) — switchable by clicking the tab buttons or swiping the lower area.

## 2. Data models

New file `lib/core/models/anime_extra.dart`:

```dart
class AnimeActor {
  final String name;
  final String? image;
  const AnimeActor({required this.name, this.image});
}

class AnimeCharacter {
  final String name;
  final String? relation; // e.g. 主角 / 配角
  final String? image;
  final List<AnimeActor> actors;
  const AnimeCharacter({required this.name, this.relation, this.image, this.actors = const []});
}

class RelatedWork {
  final int bangumiId;
  final String title;
  final String? relation; // e.g. 续集 / 游戏
  final String? image;
  const RelatedWork({required this.bangumiId, required this.title, this.relation, this.image});
}
```

## 3. BangumiProvider additions

In `lib/core/metadata/bangumi_provider.dart`:
- `Future<List<AnimeCharacter>> characters(int id)` → `GET /v0/subjects/{id}/characters`.
  - Each item: `name`, `relation`, `images.grid`/`images.medium` → `image`, `actors[]` → `AnimeActor(name, images.grid)`.
- `Future<List<RelatedWork>> related(int id)` → `GET /v0/subjects/{id}/subjects`.
  - Each item: `id`, `name_cn` (fallback `name`) → `title`, `relation`, `images.grid`/`medium` → `image`.
- Static `@visibleForTesting` parsers: `parseCharacters(dynamic data)`, `parseRelated(dynamic data)`. Cover/image URLs are `http→https`.

## 4. MetadataService additions

In `lib/core/metadata/metadata_service.dart`:
- `Future<List<AnimeCharacter>> characters(Work work)`: if `work.bangumiId == null` return `const []`; else call `BangumiProvider.characters(id)` (via a `_bangumi` reference or a cast of the first provider). On error, return `const []` (non-fatal — the tab shows an empty state).
- `Future<List<RelatedWork>> related(Work work)`: same shape.

`MetadataService` holds `MetadataProvider bangumi` (defaulting to `BangumiProvider`). The new methods use it concretely:

```dart
Future<List<AnimeCharacter>> characters(Work work) async {
  final id = work.bangumiId;
  final provider = bangumi;
  if (id == null || provider is! BangumiProvider) return const [];
  try {
    return await provider.characters(id);
  } catch (_) {
    return const [];
  }
}
```
`related(Work)` is identical in shape. Non-Bangumi works (Jikan/AniList) therefore return empty and the tab shows its empty state.

## 5. Detail page — tabs

`lib/modules/anime/anime_detail_page.dart` restructures to:

```
Column(
  _header,                     // existing title bar
  _infoSection,                // existing cover + title + meta chips (fixed)
  TabBar[概览, 角色, 关联],     // styled to the app theme
  Expanded(TabBarView[ overview, characters, related ]),
)
```

- Wrap the tab area in a `DefaultTabController(length: 3)`.
- **overview**: a `CustomScrollView`/`ListView` with the existing tags row, summary card, and play card (unchanged content).
- **characters**: on first build, `metadataService.characters(work)`; a vertical `ListView` of rows — character image (56×56, rounded), name, a relation chip, and `CV: <actor name>` with a small actor avatar; a loading spinner, and an empty state "暂无角色信息".
- **related**: `metadataService.related(work)`; a vertical list — cover (56×80), title, relation chip; tapping pushes `AnimeDetailPage` for a `Work` built from the related `bangumiId`/title/cover; empty state "暂无关联作品".
- Tab switching via `TabBar` (click) and `TabBarView` (swipe). State is fetched once and cached in the page state.

## 6. Testing

- `test/core/metadata/bangumi_provider_test.dart`: add fixtures for `parseCharacters` (name, relation, image, actor name/image) and `parseRelated` (id, title via `name_cn`, relation, image).
- Re-run `flutter analyze lib test`, `flutter test`, `flutter build windows --debug`.
- Manual: tab switching (click + swipe), character list, related navigation.

## 7. Files

**New**
- `lib/core/models/anime_extra.dart`

**Modified**
- `lib/core/metadata/bangumi_provider.dart`
- `lib/core/metadata/metadata_service.dart`
- `lib/modules/anime/anime_detail_page.dart`
- `test/core/metadata/bangumi_provider_test.dart`

## 8. Out of scope

- Staff/制作人员 tab.
- Character detail pages.
- AniList/Jikan character/related sources (Bangumi only; empty for non-Bangumi works).
- Comments/danmaku tabs.
