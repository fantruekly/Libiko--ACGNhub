# Detail Page Tabs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add characters (+ voice actors) and related works to the anime detail page, organized into three swipeable/clickable tabs: 概览 (summary+playback+tags), 角色, 关联.

**Architecture:** New `AnimeExtra` models; `BangumiProvider` gains `characters(id)`/`related(id)` (Bangumi v0 endpoints); `MetadataService` exposes `characters(Work)`/`related(Work)` (Bangumi only, empty otherwise); the detail page restructures to a fixed info section + `TabBar`/`TabBarView`.

**Tech Stack:** Flutter 3.35, Dio, `html` n/a, `cached_network_image`, Material `TabBar`/`TabBarView`.

## Global Constraints

- Target platform: Windows first; light theme; accent `#007AFF`.
- Characters/related come from Bangumi only; non-Bangumi works return empty and show an empty state.
- Image URLs `http→https`.
- Commits: only run `git commit` steps if the user explicitly asks; otherwise treat them as checkpoints.

---

### Task 1: `AnimeExtra` models + BangumiProvider characters/related

**Files:**
- Create: `lib/core/models/anime_extra.dart`
- Modify: `lib/core/metadata/bangumi_provider.dart`
- Test: `test/core/metadata/bangumi_provider_test.dart`

**Interfaces:**
- Produces: `class AnimeActor { final String name; final String? image; }`
- Produces: `class AnimeCharacter { final String name; final String? relation; final String? image; final List<AnimeActor> actors; }`
- Produces: `class RelatedWork { final int bangumiId; final String title; final String? relation; final String? image; }`
- Produces: `BangumiProvider.characters(int id)`, `BangumiProvider.related(int id)`, and static `parseCharacters(dynamic)`, `parseRelated(dynamic)`.

- [ ] **Step 1: Write the failing tests**

Append to `test/core/metadata/bangumi_provider_test.dart` inside `main()`:

```dart
  test('parseCharacters maps name, relation, image and actors', () {
    final data = [
      {
        'id': 1,
        'name': 'ルルーシュ',
        'relation': '主角',
        'images': {'grid': 'http://lain.bgm.tv/crt/g/1.jpg'},
        'actors': [
          {'id': 2, 'name': '福山润', 'images': {'grid': 'http://lain.bgm.tv/prsn/g/2.jpg'}},
        ],
      },
    ];

    final chars = BangumiProvider.parseCharacters(data);
    expect(chars, hasLength(1));
    expect(chars.first.name, 'ルルーシュ');
    expect(chars.first.relation, '主角');
    expect(chars.first.image, 'https://lain.bgm.tv/crt/g/1.jpg');
    expect(chars.first.actors.single.name, '福山润');
    expect(chars.first.actors.single.image, 'https://lain.bgm.tv/prsn/g/2.jpg');
  });

  test('parseRelated prefers name_cn and keeps relation', () {
    final data = [
      {
        'id': 231989,
        'name': 'スーパーロボット大戦 X',
        'name_cn': '超级机器人大战X',
        'relation': '游戏',
        'images': {'grid': 'http://lain.bgm.tv/cover/g/231989.jpg'},
      },
    ];

    final rel = BangumiProvider.parseRelated(data);
    expect(rel, hasLength(1));
    expect(rel.first.bangumiId, 231989);
    expect(rel.first.title, '超级机器人大战X');
    expect(rel.first.relation, '游戏');
    expect(rel.first.image, 'https://lain.bgm.tv/cover/g/231989.jpg');
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/metadata/bangumi_provider_test.dart`
Expected: FAIL — `parseCharacters`/`parseRelated` not defined.

- [ ] **Step 3: Create `lib/core/models/anime_extra.dart`**

```dart
class AnimeActor {
  final String name;
  final String? image;

  const AnimeActor({required this.name, this.image});
}

class AnimeCharacter {
  final String name;
  final String? relation;
  final String? image;
  final List<AnimeActor> actors;

  const AnimeCharacter({required this.name, this.relation, this.image, this.actors = const []});
}

class RelatedWork {
  final int bangumiId;
  final String title;
  final String? relation;
  final String? image;

  const RelatedWork({required this.bangumiId, required this.title, this.relation, this.image});
}
```

- [ ] **Step 4: Add methods to `BangumiProvider`**

In `lib/core/metadata/bangumi_provider.dart`, add the import:
```dart
import '../models/anime_extra.dart';
```
Add these methods to `BangumiProvider` (after `detail`):
```dart
  Future<List<AnimeCharacter>> characters(int id) async {
    final res = await _dio.get('/v0/subjects/$id/characters');
    return parseCharacters(res.data);
  }

  Future<List<RelatedWork>> related(int id) async {
    final res = await _dio.get('/v0/subjects/$id/subjects');
    return parseRelated(res.data);
  }
```
Add these static parsers (next to the other `@visibleForTesting` parsers):
```dart
  @visibleForTesting
  static List<AnimeCharacter> parseCharacters(dynamic data) {
    final list = (data as List<dynamic>?) ?? [];
    final out = <AnimeCharacter>[];
    for (final e in list) {
      final m = e as Map<String, dynamic>;
      final name = (m['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) continue;
      final images = m['images'] as Map<String, dynamic>?;
      final actors = ((m['actors'] as List<dynamic>?) ?? [])
          .map((a) {
            final am = a as Map<String, dynamic>;
            final aimg = am['images'] as Map<String, dynamic>?;
            return AnimeActor(
              name: (am['name'] as String?)?.trim() ?? '',
              image: _https(aimg?['grid'] as String? ?? aimg?['medium'] as String?),
            );
          })
          .where((a) => a.name.isNotEmpty)
          .toList();
      out.add(AnimeCharacter(
        name: name,
        relation: m['relation'] as String?,
        image: _https(images?['grid'] as String? ?? images?['medium'] as String?),
        actors: actors,
      ));
    }
    return out;
  }

  @visibleForTesting
  static List<RelatedWork> parseRelated(dynamic data) {
    final list = (data as List<dynamic>?) ?? [];
    final out = <RelatedWork>[];
    for (final e in list) {
      final m = e as Map<String, dynamic>;
      final id = m['id'] as int?;
      if (id == null) continue;
      final nameCn = (m['name_cn'] as String?)?.trim() ?? '';
      final name = (m['name'] as String?)?.trim() ?? '';
      final title = nameCn.isNotEmpty ? nameCn : name;
      if (title.isEmpty) continue;
      final images = m['images'] as Map<String, dynamic>?;
      out.add(RelatedWork(
        bangumiId: id,
        title: title,
        relation: m['relation'] as String?,
        image: _https(images?['grid'] as String? ?? images?['medium'] as String?),
      ));
    }
    return out;
  }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/metadata/bangumi_provider_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit (only if user asked)**

```bash
git add lib/core/models/anime_extra.dart lib/core/metadata/bangumi_provider.dart test/core/metadata/bangumi_provider_test.dart
git commit -m "feat(metadata): Bangumi characters and related works"
```

---

### Task 2: `MetadataService.characters` / `related`

**Files:**
- Modify: `lib/core/metadata/metadata_service.dart`

**Interfaces:**
- Consumes: `BangumiProvider.characters/related` (Task 1), `AnimeCharacter`/`RelatedWork` (Task 1).
- Produces: `Future<List<AnimeCharacter>> characters(Work work)`, `Future<List<RelatedWork>> related(Work work)`.

- [ ] **Step 1: Add the import and methods**

In `lib/core/metadata/metadata_service.dart`, add:
```dart
import '../models/anime_extra.dart';
```
Add these methods to `MetadataService` (after `detail`):
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

  Future<List<RelatedWork>> related(Work work) async {
    final id = work.bangumiId;
    final provider = bangumi;
    if (id == null || provider is! BangumiProvider) return const [];
    try {
      return await provider.related(id);
    } catch (_) {
      return const [];
    }
  }
```

- [ ] **Step 2: Verify**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib/core/metadata/metadata_service.dart`
Expected: No issues found.

- [ ] **Step 3: Commit (only if user asked)**

```bash
git add lib/core/metadata/metadata_service.dart
git commit -m "feat(metadata): expose characters and related via MetadataService"
```

---

### Task 3: Detail page — tab structure + 概览 tab

**Files:**
- Modify: `lib/modules/anime/anime_detail_page.dart`

**Interfaces:**
- Produces: a 3-tab layout; `_overviewTab(Work, ColorScheme)` containing the existing tags/summary/play content.

- [ ] **Step 1: Restructure `build`**

Replace the `build` method's body (the `Scaffold`) so the info section is fixed above a `TabBar`/`TabBarView`:
```dart
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Column(
        children: [
          _header(w, cs),
          Expanded(
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  _infoSection(w, cs, score, episodes, seasonYear, format, status),
                  const TabBar(
                    labelColor: Color(0xFF007AFF),
                    unselectedLabelColor: Color(0xFF8E8E93),
                    indicatorColor: Color(0xFF007AFF),
                    dividerColor: Color(0xFFE5E5EA),
                    tabs: [Tab(text: '概览'), Tab(text: '角色'), Tab(text: '关联')],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _overviewTab(w, cs),
                        _charactersTab(cs),
                        _relatedTab(cs),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
```

- [ ] **Step 2: Add `_overviewTab` and remove the old sliver list**

The previous `build` had a `CustomScrollView` with slivers `[_infoSection, _tagsRow, _summarySection, _playSection]`. The info section is now outside. Add:
```dart
  Widget _overviewTab(Work w, ColorScheme cs) {
    return CustomScrollView(
      slivers: [
        if (w.tags.isNotEmpty) _tagsRow(w.tags),
        _summarySection(w.summary, cs),
        _playSection(w, cs),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
```
(`_tagsRow`, `_summarySection`, `_playSection` stay as-is.)

- [ ] **Step 3: Add temporary stub tabs**

Add stubs so the file compiles (replaced in Task 4):
```dart
  Widget _charactersTab(ColorScheme cs) => const Center(child: Text('角色'));
  Widget _relatedTab(ColorScheme cs) => const Center(child: Text('关联'));
```

- [ ] **Step 4: Verify**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib`
Expected: `No issues found!`

- [ ] **Step 5: Commit (only if user asked)**

```bash
git add lib/modules/anime/anime_detail_page.dart
git commit -m "feat(anime): tabbed detail page (overview/characters/related)"
```

---

### Task 4: Detail page — 角色 and 关联 tabs

**Files:**
- Modify: `lib/modules/anime/anime_detail_page.dart`

**Interfaces:**
- Consumes: `metadataServiceProvider.characters/related` (Task 2), `AnimeCharacter`/`AnimeActor`/`RelatedWork` (Task 1).

- [ ] **Step 1: Add state + fetching**

Add imports:
```dart
import '../../core/models/anime_extra.dart';
```
Add fields to `_AnimeDetailPageState`:
```dart
  List<AnimeCharacter>? _characters;
  List<RelatedWork>? _related;
  bool _loadingExtras = false;
```
In `_load()` (after the detail fetch), add:
```dart
    _loadExtras();
```
and add the method:
```dart
  Future<void> _loadExtras() async {
    setState(() => _loadingExtras = true);
    final svc = ref.read(metadataServiceProvider);
    final chars = await svc.characters(_work);
    final rel = await svc.related(_work);
    if (mounted) {
      setState(() {
        _characters = chars;
        _related = rel;
        _loadingExtras = false;
      });
    }
  }
```

- [ ] **Step 2: Implement `_charactersTab`**

Replace the stub:
```dart
  Widget _charactersTab(ColorScheme cs) {
    if (_loadingExtras) return const Center(child: CircularProgressIndicator());
    final chars = _characters ?? const <AnimeCharacter>[];
    if (chars.isEmpty) {
      return Center(child: Text('暂无角色信息', style: TextStyle(fontSize: 14, color: cs.onSurface.withValues(alpha: 0.4))));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: chars.length,
      itemBuilder: (context, i) {
        final c = chars[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(width: 56, height: 56, child: _image(c.image, cs)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (c.relation != null && c.relation!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(c.relation!, style: TextStyle(fontSize: 11, color: cs.primary)),
                          ),
                      ],
                    ),
                    for (final a in c.actors)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            ClipOval(child: SizedBox(width: 24, height: 24, child: _image(a.image, cs))),
                            const SizedBox(width: 8),
                            Text('CV: ${a.name}', style: TextStyle(fontSize: 12.5, color: cs.onSurface.withValues(alpha: 0.6))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
```

- [ ] **Step 3: Implement `_relatedTab`**

Replace the stub:
```dart
  Widget _relatedTab(ColorScheme cs) {
    if (_loadingExtras) return const Center(child: CircularProgressIndicator());
    final rel = _related ?? const <RelatedWork>[];
    if (rel.isEmpty) {
      return Center(child: Text('暂无关联作品', style: TextStyle(fontSize: 14, color: cs.onSurface.withValues(alpha: 0.4))));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rel.length,
      itemBuilder: (context, i) {
        final r = rel[i];
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AnimeDetailPage(
                work: Work(
                  id: 'bangumi_${r.bangumiId}',
                  sourceId: 'bangumi',
                  sourceName: 'Bangumi',
                  type: WorkType.anime,
                  title: r.title,
                  coverUrl: r.image,
                  extra: {'bangumiId': r.bangumiId},
                ),
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(width: 56, height: 80, child: _image(r.image, cs)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.35)),
                      if (r.relation != null && r.relation!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(r.relation!, style: TextStyle(fontSize: 12, color: cs.primary)),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: cs.onSurface.withValues(alpha: 0.2)),
              ],
            ),
          ),
        );
      },
    );
  }
```

- [ ] **Step 4: Add the image helper**

Add a helper used by both tabs:
```dart
  Widget _image(String? url, ColorScheme cs) {
    if (url == null || url.isEmpty) {
      return Container(color: cs.primary.withValues(alpha: 0.08));
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: cs.primary.withValues(alpha: 0.06)),
      errorWidget: (_, __, ___) => Container(color: cs.primary.withValues(alpha: 0.08)),
    );
  }
```

- [ ] **Step 5: Verify**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib`
Expected: `No issues found!`

- [ ] **Step 6: Commit (only if user asked)**

```bash
git add lib/modules/anime/anime_detail_page.dart
git commit -m "feat(anime): character and related tabs"
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
Expected: a detail page with 概览/角色/关联 tabs; clicking and swiping switch them; 角色 lists characters with `CV:` voice actors; 关联 lists related works and tapping one opens its detail page.

---

## Self-Review

- **Spec coverage:** models (§2) → Task 1; BangumiProvider (§3) → Task 1; MetadataService (§4) → Task 2; tab layout + overview (§5) → Task 3; characters/related tabs (§5) → Task 4; tests (§6) → Tasks 1, 5. All spec sections covered.
- **Placeholders:** none.
- **Type consistency:** `AnimeActor{name,image}`, `AnimeCharacter{name,relation,image,actors}`, `RelatedWork{bangumiId,title,relation,image}`, `BangumiProvider.characters/related(int)`, `MetadataService.characters/related(Work)`, `_overviewTab/_charactersTab/_relatedTab(ColorScheme)`, `_image(String?, ColorScheme)` are consistent across tasks.
