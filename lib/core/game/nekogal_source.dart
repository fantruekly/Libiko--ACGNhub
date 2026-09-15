import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'game_paging.dart';
import 'game_source.dart';
import 'models.dart';

const String nekogalBaseUrl = 'https://www.nekogal.com';
const String nekogalUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
const int nekogalSourcePageSize = 12;

const Map<String, String> _nekogalCategoryPaths = {
  'pcgame': '/archives/category/pcgame',
  'hhzy': '/archives/category/pcgame/hhzy',
  'srzy': '/archives/category/pcgame/srzy',
  'pegame': '/archives/category/pegame',
};

final RegExp _postHref = RegExp(r'/archives/(\d+)');

String? nekogalIdFromHref(String? href) {
  if (href == null) return null;
  return _postHref.firstMatch(href)?.group(1);
}

String _absUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  if (url.startsWith('http')) return url;
  if (url.startsWith('//')) return 'https:$url';
  return url.startsWith('/') ? '$nekogalBaseUrl$url' : '$nekogalBaseUrl/$url';
}

String _textOf(dom.Element? el) => el?.text.trim() ?? '';

int? parseNekogalCount(String raw) {
  final s = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (s.isEmpty) return null;
  return int.tryParse(s);
}

String nekogalBrowsePath(String optionKey, int page) {
  final path = _nekogalCategoryPaths[optionKey];
  if (path == null) {
    throw ArgumentError('unknown nekogal browse option: $optionKey');
  }
  return page <= 1 ? path : '$path/page/$page';
}

Game? _gameFromItem(dom.Element item) {
  final titleA = item.querySelector('.item-heading a');
  final id = nekogalIdFromHref(titleA?.attributes['href']);
  if (titleA == null || id == null) return null;
  final img = item.querySelector('.item-thumbnail img');
  final cover = _absUrl(img?.attributes['data-src'] ?? img?.attributes['src']);
  final summary = _textOf(item.querySelector('.item-excerpt'));
  final dateRaw = item.querySelector('.meta-author span')?.attributes['title'];
  return Game(
    id: id,
    title: _textOf(titleA),
    coverUrl: cover.isEmpty ? null : cover,
    summary: summary.isEmpty ? null : summary,
    publishedAt: dateRaw == null ? null : DateTime.tryParse(dateRaw),
    views: parseNekogalCount(_textOf(item.querySelector('item.meta-view'))),
    extra: {'url': '$nekogalBaseUrl/archives/$id'},
  );
}

List<Game> parseNekogalList(String html) {
  final doc = html_parser.parse(html);
  final out = <Game>[];
  for (final item in doc.querySelectorAll('posts.posts-item')) {
    final g = _gameFromItem(item);
    if (g != null) out.add(g);
  }
  return out;
}

bool parseNekogalHasNext(String html, {required int itemCount}) {
  final doc = html_parser.parse(html);
  if (doc.querySelector('a.next.page-numbers') != null) return true;
  if (doc.querySelector('.page-numbers') != null) return false;
  return itemCount >= 12;
}

DateTime? _parseChineseDate(String raw) {
  final m = RegExp(r'(\d{4})年(\d{2})月(\d{2})日').firstMatch(raw);
  if (m == null) return DateTime.tryParse(raw);
  return DateTime(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
  );
}

GameDetail parseNekogalDetail(String html, String sourceUrl) {
  final doc = html_parser.parse(html);
  final id = nekogalIdFromHref(sourceUrl) ?? '';
  final title = _textOf(doc.querySelector('h1.article-title'));
  final img = doc.querySelector('.single-cover img');
  final cover = _absUrl(img?.attributes['data-src'] ?? img?.attributes['src']);

  String? category;
  final tags = <String>[];
  for (final a in doc.querySelectorAll('.article-tags a')) {
    final href = a.attributes['href'] ?? '';
    final text = _textOf(a);
    if (text.isEmpty) continue;
    if (href.contains('/archives/tag/')) {
      tags.add(text.startsWith('#') ? text.substring(1).trim() : text);
    } else if (category == null && a.classes.contains('c-blue')) {
      category = text;
    }
  }

  final dateRaw = doc.querySelector('.article-header span')?.attributes['title'];

  final paragraphs = <String>[];
  final screenshots = <String>[];
  final content = doc.querySelector('.article-content .wp-posts-content') ??
      doc.querySelector('.article-content');
  if (content != null) {
    final ps = content.querySelectorAll('p');
    if (ps.isEmpty) {
      final t = _textOf(content);
      if (t.isNotEmpty) paragraphs.add(t);
    } else {
      for (final p in ps) {
        final t = _textOf(p);
        if (t.isNotEmpty) paragraphs.add(t);
      }
    }
    final seen = <String>{};
    for (final im in content.querySelectorAll('img')) {
      final raw = im.attributes['data-src'] ?? im.attributes['src'];
      if (raw == null || raw.isEmpty || raw.startsWith('data:')) continue;
      final src = _absUrl(raw);
      if (cover.isNotEmpty && src == cover) continue;
      if (seen.add(src)) screenshots.add(src);
    }
  }

  final game = Game(
    id: id,
    title: title,
    coverUrl: cover.isEmpty ? null : cover,
    category: category,
    tags: tags,
    publishedAt: dateRaw == null ? null : _parseChineseDate(dateRaw),
    views: parseNekogalCount(
        _textOf(doc.querySelector('.post-metas item.meta-view'))),
    extra: {'url': sourceUrl},
  );

  return GameDetail(
    game: game,
    paragraphs: paragraphs,
    screenshots: screenshots,
    sourceUrl: sourceUrl,
  );
}

class NekogalSource implements GameSource {
  NekogalSource({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: nekogalBaseUrl,
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 20),
              headers: {
                'User-Agent': nekogalUserAgent,
                'Accept':
                    'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
                'Referer': '$nekogalBaseUrl/',
              },
            ));

  final Dio _dio;

  @override
  String get id => 'nekogal';

  @override
  String get name => 'NekoGAL';

  @override
  String get baseUrl => nekogalBaseUrl;

  @override
  List<GameBrowseOption> get browseOptions => const [
        GameBrowseOption(key: 'pcgame', label: 'PC资源'),
        GameBrowseOption(key: 'hhzy', label: '汉化资源'),
        GameBrowseOption(key: 'srzy', label: '生肉资源'),
        GameBrowseOption(key: 'pegame', label: '模拟器资源'),
      ];

  @override
  Future<GameList> browse(String optionKey, {int page = 1}) {
    return buildGamePage(
      page: page,
      sourcePageSize: nekogalSourcePageSize,
      fetch: (serverPage) async {
        final html = await _get(nekogalBrowsePath(optionKey, serverPage));
        final items = parseNekogalList(html);
        return GameSourcePage(
          items: items,
          hasMore: parseNekogalHasNext(html, itemCount: items.length),
        );
      },
    );
  }

  @override
  Future<GameDetail> detail(String id) async {
    final html = await _get('/archives/$id');
    return parseNekogalDetail(html, '$nekogalBaseUrl/archives/$id');
  }

  Future<String> _get(String path) async {
    final res = await _dio.get<String>(
      path,
      options: Options(responseType: ResponseType.plain),
    );
    final data = res.data;
    if (res.statusCode != 200 || data == null) {
      throw Exception('nekogal 请求失败：$path (${res.statusCode})');
    }
    return data;
  }
}
