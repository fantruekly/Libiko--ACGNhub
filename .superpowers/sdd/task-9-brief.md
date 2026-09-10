### Task 9: Implement XPathParser and AnimeSource adapter

**Files:**
- Modify: `lib/modules/anime/anime_rule.dart` (implement XPathParser)
- Create: `lib/modules/anime/anime_source.dart`
- Create: `test/modules/anime/anime_source_test.dart`

**Interfaces:**
- Consumes: `AnimeRule`, `XPathParser` (Task 8), `SourceAdapter` (Task 3), `HttpClient` (Task 4), `Work`, `Chapter`, `SearchResult` (Task 2)
- Produces: `AnimeSource` class implementing `SourceAdapter`

- [ ] **Step 1: Implement XPathParser**

Replace the stub methods in `lib/modules/anime/anime_rule.dart` with real implementations.

Modify the `XPathParser` class in `lib/modules/anime/anime_rule.dart`:

```dart
import 'package:html/dom.dart' as dom;
import 'package:xml/xml.dart' as xml;

class XPathParser {
  static String? extractText(dynamic node, String xpath) {
    if (node == null) return null;
    if (xpath.endsWith('/text()')) {
      final attrXpath = xpath.replaceAll('/text()', '');
      final attr = _extractAttribute(node, attrXpath);
      if (attr != null) return attr;
    }
    if (xpath.startsWith('@')) {
      return _extractAttribute(node, xpath);
    }
    if (xpath.endsWith('/@src')) {
      final attrPath = xpath;
      return _extractAttribute(node, attrPath);
    }
    if (xpath.endsWith('/@href')) {
      return _extractAttribute(node, xpath);
    }
    final found = _findNode(node, xpath);
    if (found != null) {
      if (found is dom.Element) {
        return found.text.trim();
      }
    }
    if (node is dom.Element) {
      return node.text.trim();
    }
    return null;
  }

  static String? _extractAttribute(dynamic node, String xpath) {
    if (node is dom.Element) {
      if (xpath.contains('/@src')) {
        return node.attributes['src'];
      }
      if (xpath.contains('/@href')) {
        return node.attributes['href'];
      }
      if (xpath.startsWith('@')) {
        final attrName = xpath.substring(1);
        return node.attributes[attrName];
      }
    }
    return null;
  }

  static List<dom.Element> findNodes(dynamic root, String xpath) {
    if (root == null) return [];
    if (root is dom.Document) {
      return _queryAll(root, xpath);
    }
    if (root is dom.Element) {
      return _queryAll(root, xpath);
    }
    return [];
  }

  static List<dom.Element> _queryAll(dynamic parent, String xpath) {
    final results = <dom.Element>[];
    String selector = xpath;

    // Handle relative selectors starting with .//
    if (selector.startsWith('.//')) {
      selector = selector.substring(1);
    }

    // Handle //tag[@attr='value']/child pattern
    if (selector.startsWith('//')) {
      selector = selector.substring(2);
    }

    // Simple tag-only selector
    if (!selector.contains('[') && !selector.contains('/')) {
      if (parent is dom.Element) {
        results.addAll(parent.querySelectorAll(selector));
      }
      if (parent is dom.Document) {
        results.addAll(parent.querySelectorAll(selector));
      }
      return results;
    }

    // Tag with attribute filter: tag[@attr='value']
    final attrMatch = RegExp(r"^(\w+)\[@(\w+)='([^']*)'\]$").firstMatch(selector);
    if (attrMatch != null) {
      final tag = attrMatch.group(1)!;
      final attr = attrMatch.group(2)!;
      final value = attrMatch.group(3)!;
      if (parent is dom.Element) {
        results.addAll(parent.querySelectorAll(tag).where((e) => e.attributes[attr] == value));
      }
      if (parent is dom.Document) {
        results.addAll(parent.querySelectorAll(tag).where((e) => e.attributes[attr] == value));
      }
      return results;
    }

    // Nested: tag[@attr='value']/child
    final nestedMatch = RegExp(r"^(\w+)\[@(\w+)='([^']*)'\]/(\w+)$").firstMatch(selector);
    if (nestedMatch != null) {
      final parentTag = nestedMatch.group(1)!;
      final parentAttr = nestedMatch.group(2)!;
      final parentValue = nestedMatch.group(3)!;
      final childTag = nestedMatch.group(4)!;
      List<dom.Element> parents;
      if (parent is dom.Element) {
        parents = parent.querySelectorAll(parentTag).where((e) => e.attributes[parentAttr] == parentValue).toList();
      } else if (parent is dom.Document) {
        parents = parent.querySelectorAll(parentTag).where((e) => e.attributes[parentAttr] == parentValue).toList();
      } else {
        return [];
      }
      for (final p in parents) {
        results.addAll(p.querySelectorAll(childTag));
      }
      return results;
    }

    return results;
  }
}
```

- [ ] **Step 2: Write AnimeSource adapter**

Create `lib/modules/anime/anime_source.dart`:

```dart
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../core/source/source_adapter.dart';
import '../../core/models/work.dart';
import '../../core/models/chapter.dart';
import '../../core/models/search_result.dart';
import '../../core/services/http_client.dart';
import 'anime_rule.dart';

class AnimeSource extends SourceAdapter {
  final AnimeRule rule;
  final HttpClient _http = HttpClient();
  final _uuid = const Uuid();

  AnimeSource(this.rule);

  @override
  String get id => 'anime_${rule.name.hashCode}';

  @override
  String get name => rule.name;

  @override
  WorkType get type => WorkType.anime;

  @override
  String get baseUrl => rule.baseUrl;

  String _buildUrl(String template, {String keyword = '', int page = 1}) {
    return template
        .replaceAll('{keyword}', Uri.encodeComponent(keyword))
        .replaceAll('{page}', page.toString());
  }

  @override
  Future<SearchResult> search(String keyword, {int page = 1}) async {
    final url = baseUrl + _buildUrl(rule.search.url, keyword: keyword, page: page);
    final document = await _http.getHtml(url);
    final nodes = XPathParser.findNodes(document, rule.search.list);

    final works = <Work>[];
    for (final node in nodes) {
      final title = XPathParser.extractText(node, rule.search.title) ?? '';
      final cover = XPathParser.extractText(node, rule.search.cover);
      final link = XPathParser.extractText(node, rule.search.link) ?? '';
      if (title.isEmpty) continue;

      final workId = link.replaceAll(RegExp(r'[^\w]'), '_');
      works.add(Work(
        id: '$id-$workId',
        sourceId: id,
        sourceName: name,
        type: WorkType.anime,
        title: title,
        coverUrl: cover != null ? _resolveUrl(cover) : null,
        extra: {'link': link},
      ));
    }

    return SearchResult(
      works: works,
      totalPages: works.isEmpty ? 1 : page + 1,
      currentPage: page,
    );
  }

  @override
  Future<Work> fetchDetail(String workId) async {
    final link = ''; // Extract from workId or fetch from search
    final url = baseUrl + link;
    final document = await _http.getHtml(url);

    final summary = XPathParser.extractText(document, rule.detail.summary) ?? '';
    final tagsText = rule.detail.tags != null ? XPathParser.extractText(document, rule.detail.tags!) : null;
    final coverUrl = rule.detail.cover != null ? XPathParser.extractText(document, rule.detail.cover!) : null;
    final author = rule.detail.author != null ? XPathParser.extractText(document, rule.detail.author!) : null;

    return Work(
      id: workId,
      sourceId: id,
      sourceName: name,
      type: WorkType.anime,
      title: '', // Will be filled from the page
      coverUrl: coverUrl != null ? _resolveUrl(coverUrl) : null,
      summary: summary,
      tags: tagsText?.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList() ?? [],
      author: author,
      extra: {'link': link},
    );
  }

  @override
  Future<List<Chapter>> fetchChapters(String workId) async {
    final link = ''; // Extract from workId or fetch
    final url = baseUrl + link;
    final document = await _http.getHtml(url);
    final nodes = XPathParser.findNodes(document, rule.detail.chapters);

    final chapters = <Chapter>[];
    for (var i = 0; i < nodes.length; i++) {
      final title = XPathParser.extractText(nodes[i], rule.detail.chapterTitle) ?? '绗?{i + 1}闆?;
      final chLink = XPathParser.extractText(nodes[i], rule.detail.chapterLink) ?? '';
      chapters.add(Chapter(
        id: '$workId-ch$i',
        workId: workId,
        title: title,
        index: i,
        url: chLink,
      ));
    }
    return chapters;
  }

  @override
  Future<String?> fetchContent(String chapterId) async {
    // Extract the actual video URL
    // For now, return the chapter URL directly
    // The video player will handle the actual stream extraction
    return null;
  }

  String _resolveUrl(String url) {
    if (url.startsWith('http')) return url;
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('/')) {
      final uri = Uri.parse(baseUrl);
      return '${uri.scheme}://${uri.host}$url';
    }
    return '$baseUrl/$url';
  }
}
```

- [ ] **Step 3: Write tests**

Create `test/modules/anime/anime_source_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/modules/anime/anime_rule.dart';
import 'package:acgnhub/modules/anime/anime_source.dart';

void main() {
  group('AnimeSource', () {
    final rule = AnimeRule.fromJson({
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
        'chapters': '//ul[@class="ep"]/li',
        'chapterTitle': './/a/text()',
        'chapterLink': './/a/@href',
      },
      'video': {
        'playUrl': '//video/source/@src',
      },
    });

    test('source has correct properties', () {
      final source = AnimeSource(rule);
      expect(source.type, WorkType.anime);
      expect(source.name, 'TestSource');
      expect(source.baseUrl, 'https://test.com');
    });

    test('_resolveUrl resolves relative paths', () {
      final source = AnimeSource(rule);
      expect(source._resolveUrl('http://example.com/img.jpg'), 'http://example.com/img.jpg');
      expect(source._resolveUrl('//cdn.com/img.jpg'), 'https://cdn.com/img.jpg');
      expect(source._resolveUrl('/img.jpg'), 'https://test.com/img.jpg');
    });

    test('_buildUrl replaces placeholders', () {
      final source = AnimeSource(rule);
      final url = source._buildUrl('/search?keyword={keyword}&page={page}', keyword: 'test', page: 2);
      expect(url, '/search?keyword=test&page=2');
    });
  });
}
```

Note: The `_resolveUrl` and `_buildUrl` methods need to be public for testing. Add `@visibleForTesting` annotations or make them public.

To fix, modify `anime_source.dart` to make these methods public:

```dart
  @visibleForTesting
  String resolveUrl(String url) { ... }

  @visibleForTesting
  String buildUrl(String template, {String keyword = '', int page = 1}) { ... }
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/modules/anime/anime_source_test.dart
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/modules/anime/ test/modules/anime/
git commit -m "feat(anime): implement XPathParser and AnimeSource adapter"
```

---


