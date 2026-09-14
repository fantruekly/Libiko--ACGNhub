import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'models.dart';
import 'novel_source.dart';

const String linovelibBaseUrl = 'https://www.linovelib.com';
const String linovelibUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

final RegExp _novelHref = RegExp(r'/novel/(\d+)\.html');

String? novelIdFromHref(String? href) {
  if (href == null) return null;
  final m = _novelHref.firstMatch(href);
  return m?.group(1);
}

String _absUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  if (url.startsWith('http')) return url;
  if (url.startsWith('//')) return 'https:$url';
  return url.startsWith('/') ? '$linovelibBaseUrl$url' : '$linovelibBaseUrl/$url';
}

String _textOf(dom.Element? el) => el?.text.trim() ?? '';

Novel? _novelFromBookLi(dom.Element li) {
  final titleA = li.querySelector('a.title');
  final id = novelIdFromHref(titleA?.attributes['href']);
  if (titleA == null || id == null) return null;
  final img = li.querySelector('div.imgbox img');
  final cover = _absUrl(img?.attributes['data-original'] ?? img?.attributes['src']);
  final author = _textOf(li.querySelector('a.author'));
  final cate = _textOf(li.querySelector('a.cate'));
  final tags = <String>[];
  if (cate.isNotEmpty) {
    tags.add(cate.replaceAll('[', '').replaceAll(']', ''));
  }
  return Novel(
    id: id,
    title: _textOf(titleA),
    author: author.isEmpty ? null : author,
    coverUrl: cover.isEmpty ? null : cover,
    tags: tags,
    extra: {'url': '$linovelibBaseUrl/novel/$id.html'},
  );
}

List<Novel> parseBookList(String html) {
  final doc = html_parser.parse(html);
  final out = <Novel>[];
  for (final li in doc.querySelectorAll('div.lists ul li')) {
    final n = _novelFromBookLi(li);
    if (n != null) out.add(n);
  }
  return out;
}

List<NovelSection> parseHome(String html) {
  final doc = html_parser.parse(html);
  final sections = <NovelSection>[];
  for (final block in doc.querySelectorAll('div.tab-lists')) {
    final title = _textOf(block.querySelector('div.top-title .title'));
    final items = <Novel>[];
    for (final li in block.querySelectorAll('div.lists ul li')) {
      final n = _novelFromBookLi(li);
      if (n != null) items.add(n);
    }
    if (items.isNotEmpty) {
      sections.add(NovelSection(title: title.isEmpty ? '推荐' : title, items: items));
    }
  }
  return sections;
}

List<Novel> parseRankRows(String html) {
  final doc = html_parser.parse(html);
  final out = <Novel>[];
  for (final row in doc.querySelectorAll('div.rank_i_li')) {
    final bookA = row.querySelector('a.rank_i_l_a_book') ??
        row.querySelector('div.rank_i_bname a[href*="/novel/"]');
    final id = novelIdFromHref(bookA?.attributes['href']);
    if (bookA == null || id == null) continue;
    final img = row.querySelector('div.rank_i_bcount img');
    final cover = _absUrl(img?.attributes['data-original'] ?? img?.attributes['src']);
    final author = _textOf(row.querySelector('a.rank_i_l_a_author'));
    final rank = int.tryParse(_textOf(row.querySelector('div.rank_i_num')));
    final cate = _textOf(row.querySelector('a.rank_i_l_a_category'));
    final tags = <String>[];
    if (cate.isNotEmpty) {
      tags.add(cate.replaceAll('[', '').replaceAll(']', ''));
    }
    out.add(Novel(
      id: id,
      title: _textOf(bookA),
      author: author.isEmpty ? null : author,
      coverUrl: cover.isEmpty ? null : cover,
      tags: tags,
      extra: {
        'url': '$linovelibBaseUrl/novel/$id.html',
        if (rank != null) 'rank': rank,
      },
    ));
  }
  for (final row in doc.querySelectorAll('div.rank_d_list')) {
    final bookA = row.querySelector('div.rank_d_b_name a[href*="/novel/"]') ??
        row.querySelector('a[href*="/novel/"]');
    final id = novelIdFromHref(bookA?.attributes['href']);
    if (bookA == null || id == null) continue;
    final img = row.querySelector('div.rank_d_book_img img');
    final cover =
        _absUrl(img?.attributes['data-original'] ?? img?.attributes['src']);
    final author = _textOf(row.querySelector('div.rank_d_b_cate a'));
    final rank = int.tryParse(_textOf(row.querySelector('div.rank_d_b_num')));
    out.add(Novel(
      id: id,
      title: _textOf(bookA),
      author: author.isEmpty ? null : author,
      coverUrl: cover.isEmpty ? null : cover,
      extra: {
        'url': '$linovelibBaseUrl/novel/$id.html',
        if (rank != null) 'rank': rank,
      },
    ));
  }
  return out;
}

bool hasPaginationControl(String html) =>
    html_parser.parse(html).querySelector('div.pagination') != null;

bool hasNextPage(String html) {
  final container = html_parser.parse(html).querySelector('div.pagination');
  if (container == null) return false;
  for (final a in container.querySelectorAll('a')) {
    final t = a.text.trim();
    if (t.contains('下一页') || t.contains('下页')) return true;
  }
  return false;
}

final RegExp _chapterHref = RegExp(r'/novel/\d+/(\d+)\.html');

String? chapterIdFromHref(String? href) {
  if (href == null) return null;
  return _chapterHref.firstMatch(href)?.group(1);
}

String _metaContent(dom.Document doc, String property) {
  final el = doc.querySelector('meta[property="$property"]') ??
      doc.querySelector('meta[name="$property"]');
  return el?.attributes['content']?.trim() ?? '';
}

Novel parseNovelDetailHeader(String html, String id) {
  final doc = html_parser.parse(html);
  final title = _textOf(doc.querySelector('h1.book-name'));
  final img = doc.querySelector('div.book-img img');
  final cover =
      _absUrl(img?.attributes['data-original'] ?? img?.attributes['src']);
  final author = _metaContent(doc, 'og:novel:author');
  final tags = _metaContent(doc, 'og:novel:tags')
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .toList();
  final status = _metaContent(doc, 'og:novel:status');
  var summary = _textOf(doc.querySelector('div.book-dec'));
  if (summary.isEmpty) summary = _metaContent(doc, 'description');
  return Novel(
    id: id,
    title: title,
    author: author.isEmpty ? null : author,
    coverUrl: cover.isEmpty ? null : cover,
    tags: tags,
    summary: summary.isEmpty ? null : summary,
    extra: {
      'url': '$linovelibBaseUrl/novel/$id.html',
      if (status.isNotEmpty) 'status': status,
    },
  );
}

List<NovelVolume> parseCatalog(String html, String novelId) {
  final doc = html_parser.parse(html);
  final volumes = <NovelVolume>[];
  for (final vol in doc.querySelectorAll('div.volume-list div.volume')) {
    final titleA = vol.querySelector('h2.v-line a');
    final chapters = <NovelChapterRef>[];
    for (final a in vol.querySelectorAll('ul.chapter-list li a')) {
      final cid = chapterIdFromHref(a.attributes['href']);
      if (cid == null) continue;
      chapters.add(NovelChapterRef(id: cid, title: _textOf(a)));
    }
    volumes.add(NovelVolume(
      title: _textOf(titleA),
      url: titleA == null ? null : _absUrl(titleA.attributes['href']),
      chapters: chapters,
    ));
  }
  return volumes;
}

String? _imageUrl(dom.Element img) {
  final raw = img.attributes['data-src'] ?? img.attributes['src'];
  if (raw == null || raw.isEmpty) return null;
  if (raw.contains('sloading') || raw.endsWith('.svg')) return null;
  return _absUrl(raw);
}

NovelChapter parseChapter(String html, String fallbackTitle) {
  final doc = html_parser.parse(html);
  final title = _textOf(doc.querySelector('#mlfy_main_text h1'));
  final blocks = <NovelBlock>[];
  final content = doc.querySelector('div#TextContent');
  if (content != null) {
    for (final node in content.nodes) {
      if (node is! dom.Element) continue;
      switch (node.localName) {
        case 'p':
          final t = node.text.trim();
          if (t.isNotEmpty) blocks.add(NovelText(t));
        case 'img':
          final url = _imageUrl(node);
          if (url != null) blocks.add(NovelImage(url));
      }
    }
  }
  return NovelChapter(
      title: title.isEmpty ? fallbackTitle : title, blocks: blocks);
}

String? nextPageHref(String html, String novelId, String chapterId) {
  final doc = html_parser.parse(html);
  final prefix = '/novel/$novelId/${chapterId}_';
  for (final a in doc.querySelectorAll('div.mlfy_page a')) {
    if (a.text.trim() != '下一页') continue;
    final href = a.attributes['href'];
    if (href != null && href.startsWith(prefix) && href.endsWith('.html')) {
      return href;
    }
    return null;
  }
  return null;
}

Future<NovelChapter> fetchChapterPages({
  required String novelId,
  required String chapterId,
  required Future<String> Function(String path) fetch,
  int maxPages = 50,
}) async {
  final firstHtml = await fetch(LinovelibSource.chapterPath(novelId, chapterId));
  final first = parseChapter(firstHtml, '');
  final blocks = <NovelBlock>[...first.blocks];
  var next = nextPageHref(firstHtml, novelId, chapterId);
  var pages = 1;
  while (next != null && pages < maxPages) {
    final html = await fetch(next);
    blocks.addAll(parseChapter(html, '').blocks);
    next = nextPageHref(html, novelId, chapterId);
    pages++;
  }
  return NovelChapter(title: first.title, blocks: blocks);
}

class LinovelibSource implements NovelSource {
  LinovelibSource({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: linovelibBaseUrl,
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 20),
              headers: {
                'User-Agent': linovelibUserAgent,
                'Accept':
                    'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
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

  static bool isSinglePageRanking(NovelBrowse browse) =>
      browse.kind == NovelBrowseKind.ranking && browse.key == 'allvisit';

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
    final hasMore = isSinglePageRanking(browse)
        ? false
        : (hasPaginationControl(html)
            ? hasNextPage(html)
            : items.length >= 10);
    return NovelList(items: items, page: page, hasMore: hasMore);
  }

  @override
  Future<List<Novel>> search(String keyword, {int page = 1}) =>
      throw UnimplementedError();

  static String detailPath(String id) => '/novel/$id.html';

  static String catalogPath(String id) => '/novel/$id/catalog';

  @override
  Future<NovelDetail> detail(String id) async {
    final pages =
        await Future.wait([_get(detailPath(id)), _get(catalogPath(id))]);
    return NovelDetail(
      novel: parseNovelDetailHeader(pages[0], id),
      volumes: parseCatalog(pages[1], id),
    );
  }

  static String chapterPath(String novelId, String chapterId) =>
      '/novel/$novelId/$chapterId.html';

  @override
  Future<NovelChapter> chapter(String novelId, String chapterId) =>
      fetchChapterPages(novelId: novelId, chapterId: chapterId, fetch: _get);
}
