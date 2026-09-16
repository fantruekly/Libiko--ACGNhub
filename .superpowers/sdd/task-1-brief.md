## Task 1: GameSource.search

**Files:**
- Modify: `lib/core/game/game_source.dart`
- Modify: `lib/core/game/galgamezywz_source.dart`
- Modify: `lib/core/game/nekogal_source.dart`
- Modify: `test/core/game/game_source_test.dart`（假源补 search）
- Modify: `test/modules/game/game_home_test.dart`（两个假源补 search）
- Modify: `test/modules/game/game_providers_test.dart`（假源补 search）
- Test: `test/core/game/galgamezywz_source_test.dart`
- Test: `test/core/game/nekogal_source_test.dart`

**Interfaces:**
- Produces: `Future<List<Game>> GameSource.search(String keyword)`。

### Step 1: 写源搜索测试（先失败）

在 `test/core/game/galgamezywz_source_test.dart` 的 `main()` 内追加：

```dart
  test('search requests the keyword and parses results', () async {
    final dio = Dio(BaseOptions(baseUrl: galgameZywzBaseUrl));
    final adapter = _FakeAdapter({
      '/?s=%E9%AD%94%E5%A5%B3': _listHtmlWith(2, idBase: 100),
    });
    dio.httpClientAdapter = adapter;
    final source = GalgameZywzSource(dio: dio);

    final results = await source.search('魔女');
    expect(adapter.requested, ['/?s=%E9%AD%94%E5%A5%B3']);
    expect(results.map((g) => g.id), ['100', '101']);
  });

  test('search returns empty without a request for a blank keyword', () async {
    final dio = Dio(BaseOptions(baseUrl: galgameZywzBaseUrl));
    final adapter = _FakeAdapter({});
    dio.httpClientAdapter = adapter;
    final source = GalgameZywzSource(dio: dio);

    expect(await source.search('   '), isEmpty);
    expect(adapter.requested, isEmpty);
  });
```

在 `test/core/game/nekogal_source_test.dart` 的 `main()` 内追加：

```dart
  test('search requests the keyword and parses results', () async {
    final dio = Dio(BaseOptions(baseUrl: nekogalBaseUrl));
    final adapter = _FakeAdapter({
      '/?s=%E9%AD%94%E5%A5%B3': _listPageHtml(2, base: 100),
    });
    dio.httpClientAdapter = adapter;
    final source = NekogalSource(dio: dio);

    final results = await source.search('魔女');
    expect(adapter.requested, ['/?s=%E9%AD%94%E5%A5%B3']);
    expect(results.map((g) => g.id), ['100', '101']);
  });
```

Run:
- `C:\flutter\bin\flutter.bat test test/core/game/galgamezywz_source_test.dart`
- `C:\flutter\bin\flutter.bat test test/core/game/nekogal_source_test.dart`
Expected: FAIL（`search` 未定义 / 编译错误）。

### Step 2: 接口 + 两源实现

`lib/core/game/game_source.dart`：在 `detail` 之后加入：

```dart
  /// 关键词搜索（仅第一页）。
  Future<List<Game>> search(String keyword);
```

`lib/core/game/galgamezywz_source.dart`：在 `GalgameZywzSource` 内（`detail` 之前或之后）加入：

```dart
  @override
  Future<List<Game>> search(String keyword) async {
    final k = keyword.trim();
    if (k.isEmpty) return const [];
    final html = await _get('/?s=${Uri.encodeQueryComponent(k)}');
    return parseGameList(html);
  }
```

`lib/core/game/nekogal_source.dart`：在 `NekogalSource` 内加入：

```dart
  @override
  Future<List<Game>> search(String keyword) async {
    final k = keyword.trim();
    if (k.isEmpty) return const [];
    final html = await _get('/?s=${Uri.encodeQueryComponent(k)}');
    return parseNekogalList(html);
  }
```

### Step 3: 给所有假源补 search

在这三处 `_FakeSource`（`test/core/game/game_source_test.dart`、`test/modules/game/game_home_test.dart`、`test/modules/game/game_providers_test.dart`）以及 `test/modules/game/game_home_test.dart` 的 `_NekoFakeSource` 中，各加入：

```dart
  @override
  Future<List<Game>> search(String keyword) async => const [];
```

（`game_providers_test.dart` 的假源后续在 Task 3 会改成返回结果；此处先补 `const []` 让其编译。）

### Step 4: 运行测试

Run:
- `C:\flutter\bin\flutter.bat test test/core/game/galgamezywz_source_test.dart`
- `C:\flutter\bin\flutter.bat test test/core/game/nekogal_source_test.dart`
- `C:\flutter\bin\flutter.bat test test/core/game/game_source_test.dart`
- `C:\flutter\bin\flutter.bat test test/modules/game/game_home_test.dart`
- `C:\flutter\bin\flutter.bat test test/modules/game/game_providers_test.dart`
- `C:\flutter\bin\flutter.bat analyze`
Expected: 均 PASS；analyze `No issues found!`。

### Step 5: 提交

```bash
git add lib/core/game/game_source.dart lib/core/game/galgamezywz_source.dart lib/core/game/nekogal_source.dart test/core/game/galgamezywz_source_test.dart test/core/game/nekogal_source_test.dart test/core/game/game_source_test.dart test/modules/game/game_home_test.dart test/modules/game/game_providers_test.dart
git commit -m "feat(game): add keyword search to both game sources"
```

---

