### Task 1: 模型 `models.dart`

**Files:**
- Create: `lib/core/novel/models.dart`
- Test: `test/core/novel/models_test.dart`

**Interfaces:**
- Produces:
  - `Novel { String id; String title; String? author; String? coverUrl; List<String> tags; String? summary; Map<String,dynamic> extra; }`，构造 `const Novel({required id, required title, author, coverUrl, tags = const [], summary, extra = const {}})`；`Novel.fromJson(Map<String,dynamic>)` / `Map<String,dynamic> toJson()`。
  - `NovelSection { String title; List<Novel> items; }`，`const NovelSection({required title, required items})`。
  - `NovelHome { List<NovelSection> sections; }`，`const NovelHome({required sections})`。
  - `NovelList { List<Novel> items; int page; bool hasMore; }`，`const NovelList({required items, required page, required hasMore})`。
  - `enum NovelBrowseKind { ranking, bunko }`。
  - `NovelBrowse { NovelBrowseKind kind; String key; }`，`const NovelBrowse(this.kind, this.key)`。
  - `NovelDetail { Novel novel; Map<String,String> chapters; }`，`const NovelDetail({required novel, required chapters})`。
  - `NovelChapter { String title; String content; }`，`const NovelChapter({required title, required content})`。

- [ ] **Step 1: 写失败测试**

`test/core/novel/models_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/novel/models.dart';

void main() {
  test('Novel round-trips through JSON', () {
    const novel = Novel(
      id: '2059',
      title: '安达与岛村',
      author: '入间人间',
      coverUrl: 'https://x/2059s.jpg',
      tags: ['电击文库'],
      summary: '简介',
      extra: {'url': '/novel/2059.html'},
    );
    final restored = Novel.fromJson(
      json.decode(json.encode(novel.toJson())) as Map<String, dynamic>,
    );
    expect(restored.id, '2059');
    expect(restored.title, '安达与岛村');
    expect(restored.author, '入间人间');
    expect(restored.coverUrl, 'https://x/2059s.jpg');
    expect(restored.tags, ['电击文库']);
    expect(restored.summary, '简介');
    expect(restored.extra['url'], '/novel/2059.html');
  });

  test('Novel.fromJson tolerates missing optional fields', () {
    final n = Novel.fromJson(const {'id': '1', 'title': 'T'});
    expect(n.author, isNull);
    expect(n.coverUrl, isNull);
    expect(n.tags, isEmpty);
    expect(n.extra, isEmpty);
  });

  test('NovelBrowse holds kind and key', () {
    const b = NovelBrowse(NovelBrowseKind.bunko, 'dengekibunko');
    expect(b.kind, NovelBrowseKind.bunko);
    expect(b.key, 'dengekibunko');
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/models_test.dart`
Expected: FAIL（`models.dart` 不存在 / 类未定义）

- [ ] **Step 3: 实现 `lib/core/novel/models.dart`**

```dart
List<String> _stringList(dynamic raw) {
  if (raw is List) {
    return raw.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
  }
  return const [];
}

class Novel {
  final String id;
  final String title;
  final String? author;
  final String? coverUrl;
  final List<String> tags;
  final String? summary;
  final Map<String, dynamic> extra;

  const Novel({
    required this.id,
    required this.title,
    this.author,
    this.coverUrl,
    this.tags = const [],
    this.summary,
    this.extra = const {},
  });

  factory Novel.fromJson(Map<String, dynamic> json) => Novel(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        author: json['author']?.toString(),
        coverUrl: json['coverUrl']?.toString(),
        tags: _stringList(json['tags']),
        summary: json['summary']?.toString(),
        extra: (json['extra'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (author != null) 'author': author,
        if (coverUrl != null) 'coverUrl': coverUrl,
        if (tags.isNotEmpty) 'tags': tags,
        if (summary != null) 'summary': summary,
        if (extra.isNotEmpty) 'extra': extra,
      };
}

class NovelSection {
  final String title;
  final List<Novel> items;
  const NovelSection({required this.title, required this.items});
}

class NovelHome {
  final List<NovelSection> sections;
  const NovelHome({required this.sections});
}

class NovelList {
  final List<Novel> items;
  final int page;
  final bool hasMore;
  const NovelList({required this.items, required this.page, required this.hasMore});
}

enum NovelBrowseKind { ranking, bunko }

class NovelBrowse {
  final NovelBrowseKind kind;
  final String key;
  const NovelBrowse(this.kind, this.key);
}

class NovelDetail {
  final Novel novel;
  final Map<String, String> chapters;
  const NovelDetail({required this.novel, required this.chapters});
}

class NovelChapter {
  final String title;
  final String content;
  const NovelChapter({required this.title, required this.content});
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/models_test.dart`
Expected: PASS（3 tests）

- [ ] **Step 5: 提交**

```bash
git add lib/core/novel/models.dart test/core/novel/models_test.dart
git commit -m "feat(novel): add novel models"
git push
```

---
