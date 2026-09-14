### Task 5: providers

**Files:**
- Create: `lib/modules/novel/novel_providers.dart`

**Interfaces:**
- Consumes: Task 1/2/4。
- Produces:
  - `final novelSourceManagerProvider = Provider<NovelSourceManager>((ref) => NovelSourceManager(sources: [LinovelibSource()]));`
  - `final novelSourcesProvider = FutureProvider<List<NovelSource>>((ref) async => ref.watch(novelSourceManagerProvider).sources);`
  - `final novelHomeProvider = FutureProvider.family<NovelHome, String>((ref, sourceId) async { ... });`
  - `final novelBrowseProvider = FutureProvider.family<NovelList, (String, NovelBrowseKind, String, int)>((ref, key) async { ... });`
  - `List<Novel> flattenHome(NovelHome home)` — 合并去重（按 `id`）。

- [ ] **Step 1: 写失败测试（`flattenHome` 纯函数）**

`test/modules/novel/novel_providers_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/novel/models.dart';
import 'package:acgnhub/modules/novel/novel_providers.dart';

void main() {
  test('flattenHome merges sections and dedupes by id', () {
    const home = NovelHome(sections: [
      NovelSection(title: 'a', items: [Novel(id: '1', title: 'A'), Novel(id: '2', title: 'B')]),
      NovelSection(title: 'b', items: [Novel(id: '2', title: 'B'), Novel(id: '3', title: 'C')]),
    ]);
    final flat = flattenHome(home);
    expect(flat.map((n) => n.id), ['1', '2', '3']);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_providers_test.dart`
Expected: FAIL（文件不存在）

- [ ] **Step 3: 实现 `lib/modules/novel/novel_providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/novel/linovelib_source.dart';
import '../../core/novel/models.dart';
import '../../core/novel/novel_source.dart';

final novelSourceManagerProvider = Provider<NovelSourceManager>(
  (ref) => NovelSourceManager(sources: [LinovelibSource()]),
);

final novelSourcesProvider = FutureProvider<List<NovelSource>>(
  (ref) async => ref.watch(novelSourceManagerProvider).sources,
);

/// 合并首页各书单并按 id 去重。
List<Novel> flattenHome(NovelHome home) {
  final seen = <String>{};
  final out = <Novel>[];
  for (final section in home.sections) {
    for (final novel in section.items) {
      if (seen.add(novel.id)) out.add(novel);
    }
  }
  return out;
}

final novelHomeProvider =
    FutureProvider.family<NovelHome, String>((ref, sourceId) async {
  final source = ref.watch(novelSourceManagerProvider).byId(sourceId);
  if (source == null) throw StateError('novel source $sourceId not found');
  return source.home();
});

final novelBrowseProvider =
    FutureProvider.family<NovelList, (String, NovelBrowseKind, String, int)>(
        (ref, key) async {
  final (sourceId, kind, browseKey, page) = key;
  final source = ref.watch(novelSourceManagerProvider).byId(sourceId);
  if (source == null) throw StateError('novel source $sourceId not found');
  return source.browse(NovelBrowse(kind, browseKey), page: page);
});
```

- [ ] **Step 4: 运行测试确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_providers_test.dart`
Expected: PASS（1 test）

- [ ] **Step 5: 提交**

```bash
git add lib/modules/novel/novel_providers.dart test/modules/novel/novel_providers_test.dart
git commit -m "feat(novel): add novel providers"
git push
```

---
