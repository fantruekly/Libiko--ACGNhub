## Task 1: 游戏数据模型

**Files:**
- Create: `lib/core/game/models.dart`
- Test: `test/core/game/models_test.dart`

**Interfaces:**
- Consumes: 无。
- Produces: `Game`（字段 `id/title/coverUrl/summary/category/tags/publishedAt/views/extra`，`Game.fromJson`、`toJson`）、`GameBrowseOption(key,label)`、`GameList(items,page,hasMore)`、`GameDetail(game,size,platform,updatedAt,paragraphs,screenshots,sourceUrl)`。

- [ ] **Step 1: Write the failing test**

Create `test/core/game/models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/game/models.dart';

void main() {
  test('Game fromJson/toJson round-trips', () {
    final g = Game(
      id: '1207',
      title: '金辉恋曲四重奏',
      coverUrl: 'https://x/cover.jpg',
      summary: 'sum',
      category: '玩家热评游戏',
      tags: const ['汉化', 'PC'],
      publishedAt: DateTime.utc(2026, 9, 11),
      views: 4300,
      extra: const {'url': 'https://game.galgamezywz.org/game/1207'},
    );
    final back = Game.fromJson(g.toJson());
    expect(back.id, '1207');
    expect(back.title, '金辉恋曲四重奏');
    expect(back.coverUrl, 'https://x/cover.jpg');
    expect(back.summary, 'sum');
    expect(back.category, '玩家热评游戏');
    expect(back.tags, ['汉化', 'PC']);
    expect(back.publishedAt, DateTime.utc(2026, 9, 11));
    expect(back.views, 4300);
    expect(back.extra['url'], 'https://game.galgamezywz.org/game/1207');
  });

  test('Game.fromJson tolerates missing optional fields', () {
    final g = Game.fromJson(const {'id': '1', 'title': 'T'});
    expect(g.coverUrl, isNull);
    expect(g.summary, isNull);
    expect(g.category, isNull);
    expect(g.tags, isEmpty);
    expect(g.publishedAt, isNull);
    expect(g.views, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/game/models_test.dart`
Expected: FAIL（`Error: Couldn't resolve the package 'acgnhub/core/game/models.dart'` 或找不到 `Game`）。

- [ ] **Step 3: Write minimal implementation**

Create `lib/core/game/models.dart`:

```dart
List<String> _stringList(dynamic raw) {
  if (raw is List) {
    return raw
        .map((e) => e?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return const [];
}

class Game {
  final String id;
  final String title;
  final String? coverUrl;
  final String? summary;
  final String? category;
  final List<String> tags;
  final DateTime? publishedAt;
  final int? views;
  final Map<String, dynamic> extra;

  const Game({
    required this.id,
    required this.title,
    this.coverUrl,
    this.summary,
    this.category,
    this.tags = const [],
    this.publishedAt,
    this.views,
    this.extra = const {},
  });

  factory Game.fromJson(Map<String, dynamic> json) => Game(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        coverUrl: json['coverUrl']?.toString(),
        summary: json['summary']?.toString(),
        category: json['category']?.toString(),
        tags: _stringList(json['tags']),
        publishedAt: json['publishedAt'] == null
            ? null
            : DateTime.tryParse(json['publishedAt'].toString()),
        views: json['views'] is int
            ? json['views'] as int
            : int.tryParse('${json['views']}'),
        extra: (json['extra'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (coverUrl != null) 'coverUrl': coverUrl,
        if (summary != null) 'summary': summary,
        if (category != null) 'category': category,
        if (tags.isNotEmpty) 'tags': tags,
        if (publishedAt != null) 'publishedAt': publishedAt!.toIso8601String(),
        if (views != null) 'views': views,
        if (extra.isNotEmpty) 'extra': extra,
      };
}

class GameBrowseOption {
  final String key;
  final String label;
  const GameBrowseOption({required this.key, required this.label});
}

class GameList {
  final List<Game> items;
  final int page;
  final bool hasMore;
  const GameList({required this.items, required this.page, required this.hasMore});
}

class GameDetail {
  final Game game;
  final String? size;
  final String? platform;
  final DateTime? updatedAt;
  final List<String> paragraphs;
  final List<String> screenshots;
  final String sourceUrl;

  const GameDetail({
    required this.game,
    this.size,
    this.platform,
    this.updatedAt,
    this.paragraphs = const [],
    this.screenshots = const [],
    required this.sourceUrl,
  });
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/game/models_test.dart`
Expected: PASS（2 tests）。

- [ ] **Step 5: Commit**

```bash
git add lib/core/game/models.dart test/core/game/models_test.dart
git commit -m "feat(game): add game data models"
```

---

