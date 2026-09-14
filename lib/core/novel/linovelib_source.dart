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

bool hasNextPage(String html) {
  final doc = html_parser.parse(html);
  for (final a in doc.querySelectorAll('a')) {
    final t = a.text.trim();
    if (t.contains('下一页') || t.contains('下页')) return true;
  }
  return false;
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
    return NovelList(
        items: items, page: page, hasMore: items.isNotEmpty && hasNextPage(html));
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
