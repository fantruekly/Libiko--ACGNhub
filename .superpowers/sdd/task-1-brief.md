### Task 1: Models — `FollowRecord` + `WatchRecord` additions

**Files:**
- Create: `lib/core/models/follow_record.dart`
- Modify: `lib/core/models/watch_record.dart`
- Test: `test/core/models/follow_record_test.dart`, `test/core/models/watch_record_test.dart`

**Interfaces:**
- Produces: `FollowRecord{work, updatedAt, deleted, dirty}` + `fromJson`/`toJson`/`copyWith`; `WatchRecord{work, episodeTitle, episodeIndex, watchedAt, updatedAt, deleted, dirty}` + `copyWith`.

- [ ] **Step 1: Write the failing tests**

Create `test/core/models/follow_record_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/models/follow_record.dart';
import 'package:acgnhub/core/models/work.dart';

void main() {
  const work = Work(
    id: 'w1',
    sourceId: 'bangumi',
    sourceName: 'Bangumi',
    type: WorkType.anime,
    title: '葬送的芙莉莲',
    extra: {'bangumiId': 1},
  );

  test('round-trips through JSON including dirty/deleted', () {
    final record = FollowRecord(
      work: work,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      dirty: true,
    );
    final restored = FollowRecord.fromJson(record.toJson());
    expect(restored.work.id, 'w1');
    expect(restored.work.bangumiId, 1);
    expect(restored.updatedAt.millisecondsSinceEpoch, 1700000000000);
    expect(restored.deleted, isFalse);
    expect(restored.dirty, isTrue);
  });

  test('copyWith changes only the named flags', () {
    final record = FollowRecord(
        work: work, updatedAt: DateTime.fromMillisecondsSinceEpoch(1));
    final marked = record.copyWith(deleted: true, dirty: true);
    expect(marked.deleted, isTrue);
    expect(marked.dirty, isTrue);
    expect(marked.work.id, 'w1');
    expect(marked.updatedAt.millisecondsSinceEpoch, 1);
  });
}
```

Append to `test/core/models/watch_record_test.dart` (inside `main`):

```dart
  test('carries updatedAt/deleted/dirty with defaults', () {
    final record = WatchRecord(
      work: work,
      episodeTitle: '第1集',
      episodeIndex: 0,
      watchedAt: DateTime.fromMillisecondsSinceEpoch(100),
    );
    expect(record.updatedAt, record.watchedAt);
    expect(record.deleted, isFalse);
    expect(record.dirty, isFalse);

    final restored = WatchRecord.fromJson(record.copyWith(dirty: true).toJson());
    expect(restored.dirty, isTrue);
    expect(restored.updatedAt.millisecondsSinceEpoch, 100);
  });
```

(That test file already declares a `work` constant; reuse it.)

- [ ] **Step 2: Run the tests to verify they fail**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/models/follow_record_test.dart test/core/models/watch_record_test.dart`
Expected: FAIL — `follow_record.dart` not found / `copyWith` undefined.

- [ ] **Step 3: Create `lib/core/models/follow_record.dart`**

```dart
import 'work.dart';

class FollowRecord {
  final Work work;
  final DateTime updatedAt;
  final bool deleted;
  final bool dirty;

  const FollowRecord({
    required this.work,
    required this.updatedAt,
    this.deleted = false,
    this.dirty = false,
  });

  factory FollowRecord.fromJson(Map<String, dynamic> json) => FollowRecord(
        work: Work.fromJson(json['work'] as Map<String, dynamic>),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int? ?? 0),
        deleted: json['deleted'] as bool? ?? false,
        dirty: json['dirty'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'work': work.toJson(),
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'deleted': deleted,
        'dirty': dirty,
      };

  FollowRecord copyWith({DateTime? updatedAt, bool? deleted, bool? dirty}) =>
      FollowRecord(
        work: work,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
        dirty: dirty ?? this.dirty,
      );
}
```

- [ ] **Step 4: Extend `lib/core/models/watch_record.dart`**

Replace the class with:

```dart
class WatchRecord {
  final Work work;
  final String episodeTitle;
  final int episodeIndex;
  final DateTime watchedAt;
  final DateTime updatedAt;
  final bool deleted;
  final bool dirty;

  WatchRecord({
    required this.work,
    required this.episodeTitle,
    required this.episodeIndex,
    required this.watchedAt,
    DateTime? updatedAt,
    this.deleted = false,
    this.dirty = false,
  }) : updatedAt = updatedAt ?? watchedAt;

  factory WatchRecord.fromJson(Map<String, dynamic> json) {
    final watchedAt =
        DateTime.fromMillisecondsSinceEpoch(json['watchedAt'] as int? ?? 0);
    final updatedMs = json['updatedAt'] as int?;
    return WatchRecord(
      work: Work.fromJson(json['work'] as Map<String, dynamic>),
      episodeTitle: json['episodeTitle'] as String? ?? '',
      episodeIndex: json['episodeIndex'] as int? ?? 0,
      watchedAt: watchedAt,
      updatedAt: updatedMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(updatedMs),
      deleted: json['deleted'] as bool? ?? false,
      dirty: json['dirty'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'work': work.toJson(),
        'episodeTitle': episodeTitle,
        'episodeIndex': episodeIndex,
        'watchedAt': watchedAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'deleted': deleted,
        'dirty': dirty,
      };

  WatchRecord copyWith({
    String? episodeTitle,
    int? episodeIndex,
    DateTime? watchedAt,
    DateTime? updatedAt,
    bool? deleted,
    bool? dirty,
  }) =>
      WatchRecord(
        work: work,
        episodeTitle: episodeTitle ?? this.episodeTitle,
        episodeIndex: episodeIndex ?? this.episodeIndex,
        watchedAt: watchedAt ?? this.watchedAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
        dirty: dirty ?? this.dirty,
      );
}
```

(Keep the existing `import 'work.dart';`.)

- [ ] **Step 5: Run the tests to verify they pass**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/models/`
Expected: PASS.

- [ ] **Step 6: Analyze and run the full suite**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → all pass (the existing history tests still compile because the new fields are optional/defaulted).

- [ ] **Step 7: Commit**

```bash
git add lib/core/models/follow_record.dart lib/core/models/watch_record.dart test/core/models/
git commit -m "feat(sync): add FollowRecord and sync fields on WatchRecord"
```

---
