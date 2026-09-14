### Task 2: `NovelSource` 抽象与 `NovelSourceManager`

**Files:**
- Create: `lib/core/novel/novel_source.dart`
- Test: `test/core/novel/novel_source_test.dart`

**Interfaces:**
- Consumes: `lib/core/novel/models.dart`（Task 1）。
- Produces:
  - `abstract class NovelSource { String get id; String get name; String get baseUrl; Future<NovelHome> home(); Future<NovelList> browse(NovelBrowse browse, {int page = 1}); Future<List<Novel>> search(String keyword, {int page = 1}); Future<NovelDetail> detail(String id); Future<NovelChapter> chapter(String novelId, String chapterId); }`
  - `class NovelSourceManager { NovelSourceManager({List<NovelSource>? sources}); List<NovelSource> get sources; void register(NovelSource s); NovelSource? byId(String id); }`（`register` 对重复 id 抛 `ArgumentError`）

- [ ] **Step 1: 写失败测试**

`test/core/novel/novel_source_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/novel/models.dart';
import 'package:acgnhub/core/novel/novel_source.dart';

class _FakeSource extends NovelSource {
  @override
  String get id => 'fake';
  @override
  String get name => 'Fake';
  @override
  String get baseUrl => 'https://fake';
  @override
  Future<NovelHome> home() async => const NovelHome(sections: []);
  @override
  Future<NovelList> browse(NovelBrowse browse, {int page = 1}) async =>
      NovelList(items: const [], page: page, hasMore: false);
  @override
  Future<List<Novel>> search(String keyword, {int page = 1}) async => const [];
  @override
  Future<NovelDetail> detail(String id) async =>
      const NovelDetail(novel: Novel(id: 'x', title: 'x'), chapters: {});
  @override
  Future<NovelChapter> chapter(String novelId, String chapterId) async =>
      const NovelChapter(title: 't', content: 'c');
}

void main() {
  test('manager exposes registered sources', () {
    final m = NovelSourceManager(sources: [_FakeSource()]);
    expect(m.sources.map((s) => s.id), ['fake']);
    expect(m.byId('fake')!.name, 'Fake');
    expect(m.byId('nope'), isNull);
  });

  test('manager rejects duplicate ids', () {
    final m = NovelSourceManager(sources: [_FakeSource()]);
    expect(() => m.register(_FakeSource()), throwsArgumentError);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/novel_source_test.dart`
Expected: FAIL（`novel_source.dart` 不存在）

- [ ] **Step 3: 实现 `lib/core/novel/novel_source.dart`**

```dart
import 'models.dart';

abstract class NovelSource {
  String get id;
  String get name;
  String get baseUrl;

  /// 首页：若干带标题的书单。
  Future<NovelHome> home();

  /// 排行 / 文库分类，分页。
  Future<NovelList> browse(NovelBrowse browse, {int page = 1});

  // v1 仅声明，后续实现：
  Future<List<Novel>> search(String keyword, {int page = 1});
  Future<NovelDetail> detail(String id);
  Future<NovelChapter> chapter(String novelId, String chapterId);
}

class NovelSourceManager {
  NovelSourceManager({List<NovelSource>? sources}) {
    for (final s in sources ?? const <NovelSource>[]) {
      register(s);
    }
  }

  final List<NovelSource> _sources = [];

  List<NovelSource> get sources => List.unmodifiable(_sources);

  void register(NovelSource source) {
    if (_sources.any((s) => s.id == source.id)) {
      throw ArgumentError('duplicate novel source id: ${source.id}');
    }
    _sources.add(source);
  }

  NovelSource? byId(String id) {
    for (final s in _sources) {
      if (s.id == id) return s;
    }
    return null;
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/novel_source_test.dart`
Expected: PASS（2 tests）

- [ ] **Step 5: 提交**

```bash
git add lib/core/novel/novel_source.dart test/core/novel/novel_source_test.dart
git commit -m "feat(novel): add NovelSource interface and manager"
git push
```

---
