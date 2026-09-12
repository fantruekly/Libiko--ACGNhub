### Task 1: `SourceRule` model

**Files:**
- Create: `lib/core/video/source_rule.dart`
- Test: `test/core/video/source_rule_test.dart`

**Interfaces:**
- Produces: `class SourceRule` with fields `name`, `baseUrl`, `searchUrl`, `searchList`, `searchName`, `searchResult`, `chapterRoads`, `chapterResult`, `userAgent` (`String?`), a getter `String get id`, `factory SourceRule.fromJson(Map<String, dynamic>)`, `factory SourceRule.fromJsonString(String)`, and `String buildSearchUrl(String keyword)`.

- [ ] **Step 1: Write the failing test**

Create `test/core/video/source_rule_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/video/source_rule.dart';

void main() {
  const validJson = '''
  {
    "api": "4",
    "type": "anime",
    "name": "七色番",
    "version": "1.3",
    "muliSources": true,
    "useWebview": true,
    "useNativePlayer": true,
    "userAgent": "",
    "baseURL": "https://www.7sefun.top/",
    "searchURL": "https://www.7sefun.top/vodsearch/-------------.html?wd=@keyword",
    "searchList": "//div[2]/div[2]/div[2]/div[2]/div",
    "searchName": "//div[2]/text()",
    "searchResult": "//a",
    "chapterRoads": "//div[2]/div[2]/div[2]/div/div[2]/div[1]//div",
    "chapterResult": "//a"
  }''';

  test('fromJsonString parses a Kazumi plugin and ignores unknown keys', () {
    final rule = SourceRule.fromJsonString(validJson);
    expect(rule.name, '七色番');
    expect(rule.baseUrl, 'https://www.7sefun.top/');
    expect(rule.searchList, '//div[2]/div[2]/div[2]/div[2]/div');
    expect(rule.chapterResult, '//a');
    expect(rule.userAgent, isNull); // empty string -> null
    expect(rule.id, 'rule:七色番');
  });

  test('buildSearchUrl substitutes and URL-encodes @keyword', () {
    final rule = SourceRule.fromJsonString(validJson);
    expect(
      rule.buildSearchUrl('进击的巨人'),
      'https://www.7sefun.top/vodsearch/-------------.html?wd=%E8%BF%9B%E5%87%BB%E7%9A%84%E5%B7%A8%E4%BA%BA',
    );
  });

  test('fromJson throws FormatException on a missing required field', () {
    expect(
      () => SourceRule.fromJson({'name': 'x', 'baseURL': 'https://a/'}),
      throwsFormatException,
    );
  });

  test('fromJsonString throws FormatException on a non-object', () {
    expect(() => SourceRule.fromJsonString('[1,2,3]'), throwsFormatException);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/video/source_rule_test.dart`
Expected: FAIL — `source_rule.dart` not found.

- [ ] **Step 3: Create `lib/core/video/source_rule.dart`**

```dart
import 'dart:convert';

/// A Kazumi-compatible source rule: XPath selectors plus the URLs needed to
/// search a site and list its episodes. Unknown JSON keys are ignored so that
/// Kazumi plugin files import cleanly.
class SourceRule {
  final String name;
  final String baseUrl;
  final String searchUrl;
  final String searchList;
  final String searchName;
  final String searchResult;
  final String chapterRoads;
  final String chapterResult;
  final String? userAgent;

  const SourceRule({
    required this.name,
    required this.baseUrl,
    required this.searchUrl,
    required this.searchList,
    required this.searchName,
    required this.searchResult,
    required this.chapterRoads,
    required this.chapterResult,
    this.userAgent,
  });

  String get id => 'rule:$name';

  factory SourceRule.fromJson(Map<String, dynamic> json) {
    String req(String key) {
      final v = json[key];
      if (v is! String || v.trim().isEmpty) {
        throw FormatException('缺少或非法的字段: $key');
      }
      return v.trim();
    }

    final ua = json['userAgent'];
    return SourceRule(
      name: req('name'),
      baseUrl: req('baseURL'),
      searchUrl: req('searchURL'),
      searchList: req('searchList'),
      searchName: req('searchName'),
      searchResult: req('searchResult'),
      chapterRoads: req('chapterRoads'),
      chapterResult: req('chapterResult'),
      userAgent: (ua is String && ua.trim().isNotEmpty) ? ua.trim() : null,
    );
  }

  factory SourceRule.fromJsonString(String source) {
    final decoded = json.decode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('规则必须是 JSON 对象');
    }
    return SourceRule.fromJson(decoded);
  }

  String buildSearchUrl(String keyword) =>
      searchUrl.replaceAll('@keyword', Uri.encodeComponent(keyword));
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/video/source_rule_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/video/source_rule.dart test/core/video/source_rule_test.dart
git commit -m "feat(video): add Kazumi-compatible SourceRule model"
```

---
