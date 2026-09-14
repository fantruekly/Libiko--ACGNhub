### Task 4: `LinovelibSource`（HTTP + URL 拼接）

**Files:**
- Modify: `lib/core/novel/linovelib_source.dart`（在 Task 3 的解析函数之后追加）
- Test: `test/core/novel/linovelib_source_test.dart`

**Interfaces:**
- Consumes: Task 1/2/3。
- Produces:
  - `class LinovelibSource implements NovelSource`：`id == 'linovelib'`、`name == '哔哩轻小说'`、`baseUrl == linovelibBaseUrl`；`home()`、`browse(...)` 实现；`search/detail/chapter` 抛 `UnimplementedError`。
  - `static String LinovelibSource.rankPath(String key, int page)` → `/top/<key>/<page>.html`（`key == 'allvisit'` 时 → `/top.html`）。
  - `static String LinovelibSource.bunkoPath(String key, int page)` → `/wenku/<key>/<page>.html`。

- [ ] **Step 1: 写失败测试**

`test/core/novel/linovelib_source_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/novel/linovelib_source.dart';
import 'package:acgnhub/core/novel/models.dart';

void main() {
  test('rankPath builds the ranking url', () {
    expect(LinovelibSource.rankPath('monthvote', 1), '/top/monthvote/1.html');
    expect(LinovelibSource.rankPath('allvisit', 1), '/top.html');
  });

  test('bunkoPath builds the bunko url', () {
    expect(LinovelibSource.bunkoPath('dengekibunko', 2), '/wenku/dengekibunko/2.html');
  });

  test('source identity', () {
    final s = LinovelibSource();
    expect(s.id, 'linovelib');
    expect(s.name, '哔哩轻小说');
    expect(s.baseUrl, linovelibBaseUrl);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_source_test.dart`
Expected: FAIL（`LinovelibSource` 未定义）

- [ ] **Step 3: 实现 `LinovelibSource`**

在 `lib/core/novel/linovelib_source.dart` 追加（顶部补 `import 'package:dio/dio.dart';` 与 `import 'novel_source.dart';`）：

```dart
class LinovelibSource implements NovelSource {
  LinovelibSource({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: linovelibBaseUrl,
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 20),
              headers: {
                'User-Agent': linovelibUserAgent,
                'Referer': '$linovelibBaseUrl/',
              },
            ));

  final Dio _dio;

  @override
  String get id => 'linovelib';

  @override
  String get name => '哔哩轻小说';

  @override
  String get baseUrl => linovelibBaseUrl;

  static String rankPath(String key, int page) =>
      key == 'allvisit' ? '/top.html' : '/top/$key/$page.html';

  static String bunkoPath(String key, int page) => '/wenku/$key/$page.html';

  Future<String> _get(String path) async {
    final res = await _dio.get<String>(
      path,
      options: Options(responseType: ResponseType.plain),
    );
    final data = res.data;
    if (res.statusCode != 200 || data == null) {
      throw Exception('linovelib 请求失败：$path (${res.statusCode})');
    }
    return data;
  }

  @override
  Future<NovelHome> home() async {
    final html = await _get('/');
    final sections = parseHome(html);
    if (sections.isEmpty) throw Exception('linovelib 首页解析为空');
    return NovelHome(sections: sections);
  }

  @override
  Future<NovelList> browse(NovelBrowse browse, {int page = 1}) async {
    final path = browse.kind == NovelBrowseKind.ranking
        ? rankPath(browse.key, page)
        : bunkoPath(browse.key, page);
    final html = await _get(path);
    final items = browse.kind == NovelBrowseKind.ranking
        ? parseRankRows(html)
        : parseBookList(html);
    return NovelList(items: items, page: page, hasMore: items.isNotEmpty && hasNextPage(html));
  }

  @override
  Future<List<Novel>> search(String keyword, {int page = 1}) =>
      throw UnimplementedError();

  @override
  Future<NovelDetail> detail(String id) => throw UnimplementedError();

  @override
  Future<NovelChapter> chapter(String novelId, String chapterId) =>
      throw UnimplementedError();
}
```

> 注意：`home()` 用 `/` 时，`Dio` 的 `baseUrl` 是 `https://www.linovelib.com`，`path` 用 `'/'`；若解析不到 `div.tab-lists`，先手动 `flutter run` 确认页面结构未变。

- [ ] **Step 4: 运行测试确认通过**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/linovelib_source_test.dart`
Expected: PASS（3 tests）

- [ ] **Step 5: 提交**

```bash
git add lib/core/novel/linovelib_source.dart test/core/novel/linovelib_source_test.dart
git commit -m "feat(novel): add LinovelibSource with http + url building"
git push
```

---
