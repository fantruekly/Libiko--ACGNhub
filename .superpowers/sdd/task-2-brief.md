### Task 2: Create core data models

**Files:**
- Create: `lib/core/models/work.dart`
- Create: `lib/core/models/chapter.dart`
- Create: `lib/core/models/source.dart`
- Create: `lib/core/models/search_result.dart`
- Create: `test/core/models/work_test.dart`

**Interfaces:**
- Produces: `Work`, `Chapter`, `SourceInfo`, `SearchResult` classes with `fromJson`/`toJson`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p lib\core\models
mkdir -p test\core\models
```

- [ ] **Step 2: Write Work model**

Create `lib/core/models/work.dart`:

```dart
enum WorkType { anime, comic, novel, game }

class Work {
  final String id;
  final String sourceId;
  final String sourceName;
  final WorkType type;
  final String title;
  final String? coverUrl;
  final String? summary;
  final List<String> tags;
  final String? author;
  final Map<String, dynamic> extra;

  const Work({
    required this.id,
    required this.sourceId,
    required this.sourceName,
    required this.type,
    required this.title,
    this.coverUrl,
    this.summary,
    this.tags = const [],
    this.author,
    this.extra = const {},
  });

  factory Work.fromJson(Map<String, dynamic> json) => Work(
        id: json['id'] as String,
        sourceId: json['sourceId'] as String,
        sourceName: json['sourceName'] as String,
        type: WorkType.values.byName(json['type'] as String),
        title: json['title'] as String,
        coverUrl: json['coverUrl'] as String?,
        summary: json['summary'] as String?,
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        author: json['author'] as String?,
        extra: json['extra'] as Map<String, dynamic>? ?? {},
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceId': sourceId,
        'sourceName': sourceName,
        'type': type.name,
        'title': title,
        'coverUrl': coverUrl,
        'summary': summary,
        'tags': tags,
        'author': author,
        'extra': extra,
      };
}
```

- [ ] **Step 3: Write Chapter model**

Create `lib/core/models/chapter.dart`:

```dart
class Chapter {
  final String id;
  final String workId;
  final String title;
  final int index;
  final String? url;
  final Map<String, dynamic> extra;

  const Chapter({
    required this.id,
    required this.workId,
    required this.title,
    required this.index,
    this.url,
    this.extra = const {},
  });

  factory Chapter.fromJson(Map<String, dynamic> json) => Chapter(
        id: json['id'] as String,
        workId: json['workId'] as String,
        title: json['title'] as String,
        index: json['index'] as int,
        url: json['url'] as String?,
        extra: json['extra'] as Map<String, dynamic>? ?? {},
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'workId': workId,
        'title': title,
        'index': index,
        'url': url,
        'extra': extra,
      };
}
```

- [ ] **Step 4: Write SourceInfo model**

Create `lib/core/models/source.dart`:

```dart
import 'work.dart';

class SourceInfo {
  final String id;
  final String name;
  final WorkType type;
  final String baseUrl;
  final String? description;

  const SourceInfo({
    required this.id,
    required this.name,
    required this.type,
    required this.baseUrl,
    this.description,
  });
}
```

- [ ] **Step 5: Write SearchResult model**

Create `lib/core/models/search_result.dart`:

```dart
import 'work.dart';

class SearchResult {
  final List<Work> works;
  final int totalPages;
  final int currentPage;
  final bool hasMore;

  const SearchResult({
    required this.works,
    required this.totalPages,
    required this.currentPage,
  }) : hasMore = currentPage < totalPages;
}
```

- [ ] **Step 6: Write tests**

Create `test/core/models/work_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/models/work.dart';

void main() {
  group('Work', () {
    test('fromJson and toJson roundtrip', () {
      final json = {
        'id': 'test_1',
        'sourceId': 'src_1',
        'sourceName': 'TestSource',
        'type': 'anime',
        'title': 'Test Anime',
        'coverUrl': 'https://example.com/cover.jpg',
        'summary': 'A test anime',
        'tags': ['action', 'comedy'],
        'author': 'Test Author',
        'extra': {'year': 2024},
      };
      final work = Work.fromJson(json);
      expect(work.toJson(), json);
    });

    test('default values', () {
      final work = Work(
        id: '1',
        sourceId: 's1',
        sourceName: 'S',
        type: WorkType.anime,
        title: 'T',
      );
      expect(work.tags, isEmpty);
      expect(work.extra, isEmpty);
      expect(work.coverUrl, isNull);
    });
  });
}
```

- [ ] **Step 7: Run tests**

```bash
flutter test test/core/models/work_test.dart
```

Expected: All tests pass.

- [ ] **Step 8: Commit**

```bash
git add lib/core/models/ test/core/models/
git commit -m "feat(core): add data models Work, Chapter, SourceInfo, SearchResult"
```

---


