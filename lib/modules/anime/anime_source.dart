import 'package:flutter/foundation.dart';
import '../../core/source/source_adapter.dart';
import '../../core/models/work.dart';
import '../../core/models/chapter.dart';
import '../../core/models/search_result.dart';
import '../../core/services/http_client.dart';
import 'anime_rule.dart';

class AnimeSource extends SourceAdapter {
  final AnimeRule rule;
  final HttpClient _http = HttpClient();

  AnimeSource(this.rule);

  @override
  String get id => 'anime_${rule.name.hashCode}';

  @override
  String get name => rule.name;

  @override
  WorkType get type => WorkType.anime;

  @override
  String get baseUrl => rule.baseUrl;

  @visibleForTesting
  String buildUrl(String template, {String keyword = '', int page = 1}) {
    return template
        .replaceAll('{keyword}', Uri.encodeComponent(keyword))
        .replaceAll('{page}', page.toString());
  }

  @override
  Future<SearchResult> search(String keyword, {int page = 1}) async {
    final url =
        baseUrl + buildUrl(rule.search.url, keyword: keyword, page: page);
    final document = await _http.getHtml(url);
    final nodes = XPathParser.findNodes(document, rule.search.list);

    final works = <Work>[];
    for (final node in nodes) {
      final title = XPathParser.extractText(node, rule.search.title) ?? '';
      final cover = XPathParser.extractText(node, rule.search.cover);
      final link = XPathParser.extractText(node, rule.search.link) ?? '';
      if (title.isEmpty) continue;

      final resolvedCover = cover != null ? resolveUrl(cover) : null;

      final workId = link.replaceAll(RegExp(r'[^\w]'), '_');
      works.add(Work(
        id: '$id-$workId',
        sourceId: id,
        sourceName: name,
        type: WorkType.anime,
        title: title,
        coverUrl: resolvedCover,
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
    final link = workId.contains('|') ? workId.split('|').last : '';
    final url = baseUrl + link;
    final document = await _http.getHtml(url);

    final summary =
        XPathParser.extractText(document, rule.detail.summary) ?? '';
    final tagsText = rule.detail.tags != null
        ? XPathParser.extractText(document, rule.detail.tags!)
        : null;
    final coverUrl = rule.detail.cover != null
        ? XPathParser.extractText(document, rule.detail.cover!)
        : null;
    final author = rule.detail.author != null
        ? XPathParser.extractText(document, rule.detail.author!)
        : null;

    final titleEl = document.querySelector('title');
    final pageTitle = titleEl?.text.trim() ?? '';

    return Work(
      id: workId,
      sourceId: id,
      sourceName: name,
      type: WorkType.anime,
      title: pageTitle,
      coverUrl: coverUrl != null ? resolveUrl(coverUrl) : null,
      summary: summary,
      tags: tagsText != null
          ? tagsText
              .split(RegExp(r'[,\s]+'))
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty)
              .toList()
          : [],
      author: author,
      extra: {'link': link},
    );
  }

  @override
  Future<List<Chapter>> fetchChapters(String workId) async {
    final link = workId.contains('|') ? workId.split('|').last : '';
    final url = baseUrl + link;
    final document = await _http.getHtml(url);
    final nodes = XPathParser.findNodes(document, rule.detail.chapters);

    final chapters = <Chapter>[];
    for (var i = 0; i < nodes.length; i++) {
      final title =
          XPathParser.extractText(nodes[i], rule.detail.chapterTitle) ??
              '第${i + 1}集';
      final chLink =
          XPathParser.extractText(nodes[i], rule.detail.chapterLink) ?? '';
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
    return null;
  }

  @visibleForTesting
  String resolveUrl(String url) {
    if (url.startsWith('http')) return url;
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('/')) {
      final uri = Uri.parse(baseUrl);
      return '${uri.scheme}://${uri.host}$url';
    }
    return '$baseUrl/$url';
  }

  Future<List<Work>> browse({int page = 1}) async {
    if (rule.browse == null) return [];
    final url = baseUrl + buildUrl(rule.browse!.url, page: page);
    final document = await _http.getHtml(url);
    final nodes = XPathParser.findNodes(document, rule.browse!.list);

    final works = <Work>[];
    for (final node in nodes) {
      final title = XPathParser.extractText(node, rule.browse!.title) ?? '';
      final cover = XPathParser.extractText(node, rule.browse!.cover);
      final link = XPathParser.extractText(node, rule.browse!.link) ?? '';
      if (title.isEmpty) continue;

      final workId = '$id-${link.hashCode}';
      works.add(Work(
        id: workId,
        sourceId: id,
        sourceName: name,
        type: WorkType.anime,
        title: title,
        coverUrl: cover != null ? resolveUrl(cover) : null,
        extra: {'link': link},
      ));
    }
    return works;
  }
}
