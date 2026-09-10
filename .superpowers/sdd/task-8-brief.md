### Task 8: Create XPath rule model and parser

**Files:**
- Create: `lib/modules/anime/anime_rule.dart`
- Create: `test/modules/anime/anime_rule_test.dart`

**Interfaces:**
- Consumes: `xml`, `html` packages
- Produces: `AnimeRule` model with JSON parsing, `XPathParser` utility class

- [ ] **Step 1: Create directories**

```bash
mkdir -p lib\modules\anime
mkdir -p test\modules\anime
```

- [ ] **Step 2: Write AnimeRule model**

Create `lib/modules/anime/anime_rule.dart`:

```dart
import 'dart:convert';

class RuleSection {
  final String url;
  final String list;
  final String title;
  final String cover;
  final String link;
  final String? nextPage;

  const RuleSection({
    required this.url,
    required this.list,
    required this.title,
    required this.cover,
    required this.link,
    this.nextPage,
  });

  factory RuleSection.fromJson(Map<String, dynamic> json) => RuleSection(
        url: json['url'] as String,
        list: json['list'] as String,
        title: json['title'] as String,
        cover: json['cover'] as String,
        link: json['link'] as String,
        nextPage: json['nextPage'] as String?,
      );
}

class DetailRule {
  final String summary;
  final String? tags;
  final String? cover;
  final String? author;
  final String chapters;
  final String chapterTitle;
  final String chapterLink;

  const DetailRule({
    required this.summary,
    this.tags,
    this.cover,
    this.author,
    required this.chapters,
    required this.chapterTitle,
    required this.chapterLink,
  });

  factory DetailRule.fromJson(Map<String, dynamic> json) => DetailRule(
        summary: json['summary'] as String,
        tags: json['tags'] as String?,
        cover: json['cover'] as String?,
        author: json['author'] as String?,
        chapters: json['chapters'] as String,
        chapterTitle: json['chapterTitle'] as String,
        chapterLink: json['chapterLink'] as String,
      );
}

class VideoRule {
  final String playUrl;
  final String? resolutions;

  const VideoRule({required this.playUrl, this.resolutions});

  factory VideoRule.fromJson(Map<String, dynamic> json) => VideoRule(
        playUrl: json['playUrl'] as String,
        resolutions: json['resolutions'] as String?,
      );
}

class AnimeRule {
  final String name;
  final String baseUrl;
  final RuleSection search;
  final DetailRule detail;
  final VideoRule video;

  const AnimeRule({
    required this.name,
    required this.baseUrl,
    required this.search,
    required this.detail,
    required this.video,
  });

  factory AnimeRule.fromJson(Map<String, dynamic> json) => AnimeRule(
        name: json['name'] as String,
        baseUrl: json['baseUrl'] as String,
        search: RuleSection.fromJson(json['search'] as Map<String, dynamic>),
        detail: DetailRule.fromJson(json['detail'] as Map<String, dynamic>),
        video: VideoRule.fromJson(json['video'] as Map<String, dynamic>),
      );

  factory AnimeRule.fromJsonString(String jsonString) {
    return AnimeRule.fromJson(json.decode(jsonString) as Map<String, dynamic>);
  }

  String toJsonString() {
    return json.encode({
      'name': name,
      'baseUrl': baseUrl,
      'search': {
        'url': search.url,
        'list': search.list,
        'title': search.title,
        'cover': search.cover,
        'link': search.link,
        if (search.nextPage != null) 'nextPage': search.nextPage,
      },
      'detail': {
        'summary': detail.summary,
        if (detail.tags != null) 'tags': detail.tags,
        if (detail.cover != null) 'cover': detail.cover,
        if (detail.author != null) 'author': detail.author,
        'chapters': detail.chapters,
        'chapterTitle': detail.chapterTitle,
        'chapterLink': detail.chapterLink,
      },
      'video': {
        'playUrl': video.playUrl,
        if (video.resolutions != null) 'resolutions': video.resolutions,
      },
    });
  }
}

class XPathParser {
  /// Extract text from HTML node using XPath-like selector.
  /// Supports: //tag[@attr='value']/text(), .//tag/text(), //tag/@attr
  static String? extractText(
    dynamic node,
    String xpath,
  ) {
    if (node == null) return null;
    // Use xml package for XPath evaluation
    return null; // Stub - implemented in Task 9
  }

  /// Find all nodes matching XPath selector
  static List<dynamic> findNodes(dynamic root, String xpath) {
    // Stub - implemented in Task 9
    return [];
  }
}
```

- [ ] **Step 3: Write tests**

Create `test/modules/anime/anime_rule_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/modules/anime/anime_rule.dart';

void main() {
  group('AnimeRule', () {
    final json = {
      'name': 'TestSource',
      'baseUrl': 'https://test.com',
      'search': {
        'url': '/search?keyword={keyword}&page={page}',
        'list': '//div[@class="list"]/div',
        'title': './/h3/text()',
        'cover': './/img/@src',
        'link': './/a/@href',
      },
      'detail': {
        'summary': '//div[@class="desc"]/text()',
        'tags': '//span[@class="tag"]/text()',
        'chapters': '//ul[@class="ep"]/li',
        'chapterTitle': './/a/text()',
        'chapterLink': './/a/@href',
      },
      'video': {
        'playUrl': '//video/source/@src',
        'resolutions': '//select[@class="res"]/option/@value',
      },
    };

    test('fromJson parses correctly', () {
      final rule = AnimeRule.fromJson(json);
      expect(rule.name, 'TestSource');
      expect(rule.baseUrl, 'https://test.com');
      expect(rule.search.title, './/h3/text()');
      expect(rule.detail.summary, '//div[@class="desc"]/text()');
      expect(rule.video.playUrl, '//video/source/@src');
    });

    test('toJsonString and fromJsonString roundtrip', () {
      final rule = AnimeRule.fromJson(json);
      final rule2 = AnimeRule.fromJsonString(rule.toJsonString());
      expect(rule2.name, rule.name);
      expect(rule2.baseUrl, rule.baseUrl);
    });

    test('optional fields are null when missing', () {
      final minimalJson = {
        'name': 'Minimal',
        'baseUrl': 'https://min.com',
        'search': {
          'url': '/s',
          'list': '//div',
          'title': './/h3/text()',
          'cover': './/img/@src',
          'link': './/a/@href',
        },
        'detail': {
          'summary': '//div/text()',
          'chapters': '//li',
          'chapterTitle': './/a/text()',
          'chapterLink': './/a/@href',
        },
        'video': {
          'playUrl': '//video/@src',
        },
      };
      final rule = AnimeRule.fromJson(minimalJson);
      expect(rule.search.nextPage, isNull);
      expect(rule.detail.tags, isNull);
      expect(rule.video.resolutions, isNull);
    });
  });
}
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/modules/anime/anime_rule_test.dart
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/modules/anime/anime_rule.dart test/modules/anime/anime_rule_test.dart
git commit -m "feat(anime): add AnimeRule model and XPathParser stub"
```

---


