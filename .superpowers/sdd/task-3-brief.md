### Task 3: 聚合搜索 Provider

**Files:**
- Modify: `lib/modules/novel/novel_providers.dart`
- Test: `test/modules/novel/novel_search_provider_test.dart`

**Interfaces:**
- Consumes: `NovelSource.search`（Task 1/2）、`novelSourceManagerProvider`、`Novel`。
- Produces:
  - `class NovelSearchResult { final Novel novel; final String sourceKey; const NovelSearchResult({required this.novel, required this.sourceKey}); }`
  - `final novelSearchProvider = FutureProvider.family<List<NovelSearchResult>, String>((ref, keyword) async {...});`

- [ ] **Step 1: 写失败测试**

创建 `test/modules/novel/novel_search_provider_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:acgnhub/core/novel/models.dart';
import 'package:acgnhub/core/novel/novel_source.dart';
import 'package:acgnhub/modules/novel/novel_providers.dart';

class _SearchSource extends NovelSource {
  _SearchSource(this.id, this.results, {this.throws = false});
  @override
  final String id;
  final List<Novel> results;
  final bool throws;
  @override
  String get name => id;
  @override
  String get baseUrl => 'https://x';
  @override
  List<NovelBrowseGroup> get browseGroups => const [];
  @override
  Future<NovelHome> home() async => const NovelHome(sections: []);
  @override
  Future<NovelList> browse(String optionKey, {int page = 1}) async =>
      NovelList(items: const [], page: page, hasMore: false);
  @override
  Future<List<Novel>> search(String keyword, {int page = 1}) async {
    if (throws) throw Exception('boom');
    return results;
  }

  @override
  Future<NovelDetail> detail(String id) async =>
      const NovelDetail(novel: Novel(id: 'x', title: 'x'), volumes: []);
  @override
  Future<NovelChapter> chapter(String novelId, String chapterId) async =>
      const NovelChapter(title: 't', blocks: []);
}

ProviderContainer _container(List<NovelSource> sources) {
  final c = ProviderContainer(overrides: [
    novelSourceManagerProvider
        .overrideWithValue(NovelSourceManager(sources: sources)),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('aggregates across sources and dedupes by title', () async {
    final c = _container([
      _SearchSource('a', const [Novel(id: '1', title: 'X'), Novel(id: '2', title: 'Y')]),
      _SearchSource('b', const [Novel(id: '3', title: 'X'), Novel(id: '4', title: 'Z')]),
    ]);
    final results = await c.read(novelSearchProvider('k').future);
    expect(results.map((r) => r.novel.title), ['X', 'Y', 'Z']);
    expect(results.first.sourceKey, 'a');
    expect(results.last.sourceKey, 'b');
  });

  test('skips a failing source', () async {
    final c = _container([
      _SearchSource('a', const [], throws: true),
      _SearchSource('b', const [Novel(id: '4', title: 'Z')]),
    ]);
    final results = await c.read(novelSearchProvider('k').future);
    expect(results.single.novel.title, 'Z');
  });

  test('throws when every source fails', () async {
    final c = _container([_SearchSource('a', const [], throws: true)]);
    await expectLater(c.read(novelSearchProvider('k').future), throwsA(isA<StateError>()));
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_search_provider_test.dart`
Expected: 编译失败（`NovelSearchResult` / `novelSearchProvider` 未定义）。

- [ ] **Step 3: 实现**

在 `lib/modules/novel/novel_providers.dart` 末尾新增：

```dart
class NovelSearchResult {
  final Novel novel;
  final String sourceKey;
  const NovelSearchResult({required this.novel, required this.sourceKey});
}

final novelSearchProvider =
    FutureProvider.family<List<NovelSearchResult>, String>((ref, keyword) async {
  final k = keyword.trim();
  if (k.isEmpty) return const [];
  final sources = ref.watch(novelSourceManagerProvider).sources;
  final out = <NovelSearchResult>[];
  final seen = <String>{};
  Object? lastError;
  var succeeded = 0;
  for (final source in sources) {
    try {
      for (final novel in await source.search(k)) {
        if (seen.add(novel.title.trim())) {
          out.add(NovelSearchResult(novel: novel, sourceKey: source.id));
        }
      }
      succeeded++;
    } catch (e) {
      lastError = e;
    }
  }
  if (succeeded == 0) {
    throw StateError('所有轻小说源搜索失败：$lastError');
  }
  return out;
});
```

- [ ] **Step 4: 运行测试确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/modules/novel/novel_search_provider_test.dart`
Expected: 全部通过。

- [ ] **Step 5: 静态检查与全量测试**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test`
Expected: 全绿。

- [ ] **Step 6: 提交**

```bash
git add lib/modules/novel/novel_providers.dart test/modules/novel/novel_search_provider_test.dart
git commit -m "feat(novel): aggregate search provider"
git push origin dev
```

---
