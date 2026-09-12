### Task 4: `AccountApi` + models — sync/follow/history endpoints

**Files:**
- Modify: `lib/core/account/account_models.dart`
- Modify: `lib/core/account/account_api.dart`
- Test: `test/core/account/account_api_test.dart`

**Interfaces:**
- Produces: `SyncPage{follows, history, nextSeq}`, `FollowItem{work, updatedAt, deleted}`, `HistoryItem{work, episodeTitle, episodeIndex, watchedAt, updatedAt, deleted}`; `AccountApi.sync(String token, int sinceSeq)`, `putFollow(String token, Map<String,dynamic> work, int updatedAt)`, `deleteFollow(String token, String workId, int updatedAt)`, `putHistory(String token, Map<String,dynamic> work, String episodeTitle, int episodeIndex, int watchedAt, int updatedAt)`, `clearHistory(String token, int updatedAt)`.

- [ ] **Step 1: Add the failing tests**

Append to `test/core/account/account_api_test.dart` (inside `main`):

```dart
  test('sync parses the page and sends sinceSeq', () async {
    final adapter = _FakeAdapter(
      200,
      jsonEncode({
        'follows': [
          {'work': {'id': 'w1'}, 'updatedAt': 5, 'deleted': false}
        ],
        'history': [
          {
            'work': {'id': 'w1'},
            'episodeTitle': '第3集',
            'episodeIndex': 2,
            'watchedAt': 9,
            'updatedAt': 9,
            'deleted': false,
          }
        ],
        'nextSeq': 4,
      }),
    );
    final page = await _api(adapter).sync('tok', 3);

    expect(page.nextSeq, 4);
    expect(page.follows.single.work['id'], 'w1');
    expect(page.history.single.episodeTitle, '第3集');
    expect(adapter.last!.uri.queryParameters['sinceSeq'], '3');
    expect(adapter.last!.headers['authorization'], 'Bearer tok');
  });

  test('putFollow posts the work and updatedAt', () async {
    final adapter = _FakeAdapter(200, jsonEncode({'work': {}, 'updatedAt': 5}));
    await _api(adapter).putFollow('tok', {'id': 'w1'}, 5);
    expect(adapter.last!.method, 'PUT');
    expect(adapter.last!.uri.path, '/api/follows');
    expect(adapter.last!.data, {'work': {'id': 'w1'}, 'updatedAt': 5});
  });

  test('deleteFollow sends workId and updatedAt as a query parameter', () async {
    final adapter = _FakeAdapter(200, jsonEncode({'workId': 'w1'}));
    await _api(adapter).deleteFollow('tok', 'w1', 7);
    expect(adapter.last!.method, 'DELETE');
    expect(adapter.last!.uri.path, '/api/follows/w1');
    expect(adapter.last!.uri.queryParameters['updatedAt'], '7');
  });

  test('putHistory posts the episode fields', () async {
    final adapter = _FakeAdapter(200, jsonEncode({}));
    await _api(adapter).putHistory('tok', {'id': 'w1'}, '第3集', 2, 9, 9);
    expect(adapter.last!.uri.path, '/api/history');
    expect(adapter.last!.data, {
      'work': {'id': 'w1'},
      'episodeTitle': '第3集',
      'episodeIndex': 2,
      'watchedAt': 9,
      'updatedAt': 9,
    });
  });

  test('clearHistory deletes with updatedAt', () async {
    final adapter = _FakeAdapter(200, jsonEncode({'deleted': 2}));
    await _api(adapter).clearHistory('tok', 11);
    expect(adapter.last!.method, 'DELETE');
    expect(adapter.last!.uri.path, '/api/history');
    expect(adapter.last!.uri.queryParameters['updatedAt'], '11');
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/account/account_api_test.dart`
Expected: FAIL — `sync`/`putFollow`/... undefined.

- [ ] **Step 3: Add the models to `lib/core/account/account_models.dart`**

```dart
class FollowItem {
  final Map<String, dynamic> work;
  final int updatedAt;
  final bool deleted;
  const FollowItem(
      {required this.work, required this.updatedAt, required this.deleted});

  factory FollowItem.fromJson(Map<String, dynamic> json) => FollowItem(
        work: json['work'] as Map<String, dynamic>? ?? const {},
        updatedAt: json['updatedAt'] as int? ?? 0,
        deleted: json['deleted'] as bool? ?? false,
      );
}

class HistoryItem {
  final Map<String, dynamic> work;
  final String episodeTitle;
  final int episodeIndex;
  final int watchedAt;
  final int updatedAt;
  final bool deleted;
  const HistoryItem({
    required this.work,
    required this.episodeTitle,
    required this.episodeIndex,
    required this.watchedAt,
    required this.updatedAt,
    required this.deleted,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
        work: json['work'] as Map<String, dynamic>? ?? const {},
        episodeTitle: json['episodeTitle'] as String? ?? '',
        episodeIndex: json['episodeIndex'] as int? ?? 0,
        watchedAt: json['watchedAt'] as int? ?? 0,
        updatedAt: json['updatedAt'] as int? ?? 0,
        deleted: json['deleted'] as bool? ?? false,
      );
}

class SyncPage {
  final List<FollowItem> follows;
  final List<HistoryItem> history;
  final int nextSeq;
  const SyncPage(
      {required this.follows, required this.history, required this.nextSeq});

  factory SyncPage.fromJson(Map<String, dynamic> json) => SyncPage(
        follows: (json['follows'] as List<dynamic>? ?? const [])
            .map((e) => FollowItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        history: (json['history'] as List<dynamic>? ?? const [])
            .map((e) => HistoryItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        nextSeq: json['nextSeq'] as int? ?? 0,
      );
}
```

- [ ] **Step 4: Add the endpoints to `lib/core/account/account_api.dart`**

```dart
  Future<SyncPage> sync(String token, int sinceSeq) async {
    final json = await _request(() => _dio.get(
          '$baseUrl/api/sync?sinceSeq=$sinceSeq',
          options: Options(headers: {'authorization': 'Bearer $token'}),
        ));
    return SyncPage.fromJson(json);
  }

  Future<void> putFollow(
      String token, Map<String, dynamic> work, int updatedAt) async {
    await _request(() => _dio.put('$baseUrl/api/follows',
        data: {'work': work, 'updatedAt': updatedAt},
        options: Options(headers: {'authorization': 'Bearer $token'})));
  }

  Future<void> deleteFollow(String token, String workId, int updatedAt) async {
    await _request(() => _dio.delete(
          '$baseUrl/api/follows/$workId?updatedAt=$updatedAt',
          options: Options(headers: {'authorization': 'Bearer $token'}),
        ));
  }

  Future<void> putHistory(String token, Map<String, dynamic> work,
      String episodeTitle, int episodeIndex, int watchedAt, int updatedAt) async {
    await _request(() => _dio.put('$baseUrl/api/history',
        data: {
          'work': work,
          'episodeTitle': episodeTitle,
          'episodeIndex': episodeIndex,
          'watchedAt': watchedAt,
          'updatedAt': updatedAt,
        },
        options: Options(headers: {'authorization': 'Bearer $token'})));
  }

  Future<void> clearHistory(String token, int updatedAt) async {
    await _request(() => _dio.delete(
          '$baseUrl/api/history?updatedAt=$updatedAt',
          options: Options(headers: {'authorization': 'Bearer $token'}),
        ));
  }
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/account/account_api_test.dart`
Expected: PASS.

- [ ] **Step 6: Analyze and run the full suite**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test` → `No issues found!`
Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test` → all pass.

- [ ] **Step 7: Commit**

```bash
git add lib/core/account/account_models.dart lib/core/account/account_api.dart test/core/account/account_api_test.dart
git commit -m "feat(sync): add sync/follow/history endpoints to AccountApi"
```

---
