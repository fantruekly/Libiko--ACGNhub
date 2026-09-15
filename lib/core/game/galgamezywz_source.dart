import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'game_source.dart';
import 'models.dart';

const String galgameZywzBaseUrl = 'https://game.galgamezywz.org';
const String galgameZywzUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

const Map<String, String> gameImageHeaders = {
  'Referer': '$galgameZywzBaseUrl/',
};

const int galgameZywzPageSize = 48;
const int galgameZywzSourcePageSize = 12;

const Map<String, String> _categorySlugs = {
  'wanjiareping': 'wanjiareping',
  'galgame': 'galgame',
  'haoyoutuijian': 'haoyoutuijian',
  'wanjiazuiai': 'wanjiazuiai',
};

final RegExp _gameHref = RegExp(r'/game/([0-9A-Za-z]+)');

String? gameIdFromHref(String? href) {
  if (href == null) return null;
  return _gameHref.firstMatch(href)?.group(1);
}

String _absUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  if (url.startsWith('http')) return url;
  if (url.startsWith('//')) return 'https:$url';
  return url.startsWith('/') ? '$galgameZywzBaseUrl$url' : '$galgameZywzBaseUrl/$url';
}

String _textOf(dom.Element? el) => el?.text.trim() ?? '';

/// 解析预格式化计数（'6.2K' -> 6200，'1.2M' -> 1200000，'664' -> 664）。
int? parseCount(String raw) {
  final s = raw.replaceAll(RegExp(r'[^0-9KkMm.]'), '').trim();
  if (s.isEmpty) return null;
  final m = RegExp(r'^([0-9]+(?:\.[0-9]+)?)([KkMm]?)$').firstMatch(s);
  if (m == null) return null;
  final value = double.tryParse(m.group(1)!);
  if (value == null) return null;
  final suffix = m.group(2)?.toLowerCase();
  final factor = suffix == 'k' ? 1000 : (suffix == 'm' ? 1000000 : 1);
  return (value * factor).round();
}

/// 分区选项 -> 相对路径（相对 galgameZywzBaseUrl）。
String galgameZywzBrowsePath(String optionKey, int page) {
  if (optionKey == 'latest') {
    return page <= 1 ? '/' : '/page/$page';
  }
  final slug = _categorySlugs[optionKey];
  if (slug == null) {
    throw ArgumentError('unknown game browse option: $optionKey');
  }
  return page <= 1 ? '/lm/$slug' : '/lm/$slug/page/$page';
}

dom.Element? _firstPostsWarp(dom.Document doc) =>
    doc.querySelector('div.posts-warp');

/// 从列表容器向上找分页所在的 section.container / .home-widget。
dom.Element _paginationScope(dom.Element warp) {
  dom.Element? node = warp.parent;
  while (node != null) {
    if (node.classes.contains('home-widget')) return node;
    if (node.localName == 'section' && node.classes.contains('container')) {
      return node;
    }
    node = node.parent;
  }
  return warp;
}

Game? _gameFromItem(dom.Element item) {
  final titleA = item.querySelector('.entry-title a');
  final id = gameIdFromHref(titleA?.attributes['href']);
  if (titleA == null || id == null) return null;
  final media = item.querySelector('a.media-img');
  final cover = _absUrl(media?.attributes['data-bg'] ??
      media?.attributes['data-src'] ??
      media?.attributes['src']);
  final summary = _textOf(item.querySelector('.entry-desc'));
  final category = _textOf(item.querySelector('.entry-cat-dot a'));
  final dateRaw = item.querySelector('time.pub-date')?.attributes['datetime'];
  return Game(
    id: id,
    title: _textOf(titleA),
    coverUrl: cover.isEmpty ? null : cover,
    summary: summary.isEmpty ? null : summary,
    category: category.isEmpty ? null : category,
    publishedAt: dateRaw == null ? null : DateTime.tryParse(dateRaw),
    views: parseCount(_textOf(item.querySelector('.meta-views'))),
    extra: {'url': '$galgameZywzBaseUrl/game/$id'},
  );
}

List<Game> parseGameList(String html) {
  final doc = html_parser.parse(html);
  final scope = _firstPostsWarp(doc) ?? doc.documentElement;
  final out = <Game>[];
  if (scope == null) return out;
  for (final item in scope.querySelectorAll('article.post-item')) {
    final g = _gameFromItem(item);
    if (g != null) out.add(g);
  }
  return out;
}

bool parseHasNextPage(String html, {required int itemCount}) {
  final doc = html_parser.parse(html);
  final warp = _firstPostsWarp(doc);
  final scoped = warp == null ? null : _paginationScope(warp);
  final nav =
      (scoped ?? doc).querySelector('nav.page-nav') ?? doc.querySelector('nav.page-nav');
  if (nav != null) {
    return nav.querySelector('a.page-link.page-next') != null;
  }
  return itemCount >= 12;
}

String _valueAfterColon(String text) {
  final ascii = text.indexOf(':');
  final wide = text.indexOf('：');
  final cut = ascii >= 0 ? ascii : wide;
  if (cut < 0) return text.trim();
  return text.substring(cut + 1).trim();
}

DateTime? _dateAfterColon(String text) =>
    DateTime.tryParse(_valueAfterColon(text));

GameDetail parseGameDetail(String html, String sourceUrl) {
  final doc = html_parser.parse(html);
  final id = gameIdFromHref(sourceUrl) ?? '';
  final title = _textOf(doc.querySelector('h1.post-title'));
  final titleFallback = _textOf(doc.querySelector('.entry-title'));
  final img = doc.querySelector('.archive-shop .img-box img');
  final cover = _absUrl(img?.attributes['src'] ?? img?.attributes['data-src']);

  String? category;
  int? views;
  DateTime? publishedAt;
  DateTime? updatedAt;
  String? size;
  String? platform;
  for (final li
      in doc.querySelectorAll('.archive-shop .info-box .article-meta li')) {
    final text = _textOf(li);
    if (text.contains('资源分类')) {
      final a = _textOf(li.querySelector('a'));
      category = a.isNotEmpty ? a : _valueAfterColon(text);
    } else if (text.contains('浏览热度')) {
      views = parseCount(text);
    } else if (text.contains('发布时间')) {
      publishedAt = _dateAfterColon(text);
    } else if (text.contains('最近更新')) {
      updatedAt = _dateAfterColon(text);
    } else if (text.contains('游戏大小')) {
      size = _valueAfterColon(text);
    } else if (text.contains('游戏平台')) {
      platform = _valueAfterColon(text);
    }
  }

  final tags = <String>[
    for (final a in doc.querySelectorAll('.entry-tags a[rel="tag"]'))
      if (_textOf(a).isNotEmpty) _textOf(a),
  ];

  final paragraphs = <String>[];
  final screenshots = <String>[];
  final content = doc.querySelector('article.post-content');
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
      final raw = im.attributes['src'] ?? im.attributes['data-src'];
      if (raw == null || raw.isEmpty || raw.startsWith('data:')) continue;
      final src = _absUrl(raw);
      if (cover.isNotEmpty && src == cover) continue;
      if (seen.add(src)) screenshots.add(src);
    }
  }

  final game = Game(
    id: id,
    title: title.isNotEmpty ? title : titleFallback,
    coverUrl: cover.isEmpty ? null : cover,
    category: (category == null || category.isEmpty) ? null : category,
    tags: tags,
    publishedAt: publishedAt,
    views: views,
    extra: {'url': sourceUrl},
  );

  return GameDetail(
    game: game,
    size: (size == null || size.isEmpty) ? null : size,
    platform: (platform == null || platform.isEmpty) ? null : platform,
    updatedAt: updatedAt,
    paragraphs: paragraphs,
    screenshots: screenshots,
    sourceUrl: sourceUrl,
  );
}

class GalgameZywzSource implements GameSource {
  GalgameZywzSource({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: galgameZywzBaseUrl,
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 20),
              headers: {
                'User-Agent': galgameZywzUserAgent,
                'Accept':
                    'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
                'Referer': '$galgameZywzBaseUrl/',
              },
            ));

  final Dio _dio;

  @override
  String get id => 'galgamezywz';

  @override
  String get name => 'galgame大玩家';

  @override
  String get baseUrl => galgameZywzBaseUrl;

  @override
  List<GameBrowseOption> get browseOptions => const [
        GameBrowseOption(key: 'latest', label: '最近更新'),
        GameBrowseOption(key: 'wanjiareping', label: '玩家热评'),
        GameBrowseOption(key: 'galgame', label: '资源推荐'),
        GameBrowseOption(key: 'haoyoutuijian', label: '好游推荐'),
        GameBrowseOption(key: 'wanjiazuiai', label: '玩家最爱'),
      ];

  @override
  Future<GameList> browse(String optionKey, {int page = 1}) async {
    final pagesPerApp =
        (galgameZywzPageSize / galgameZywzSourcePageSize).ceil();
    final startServer = (page - 1) * pagesPerApp + 1;
    final items = <Game>[];
    var hasMore = false;
    for (var i = 0; i < pagesPerApp; i++) {
      final serverPage = startServer + i;
      final String html;
      try {
        html = await _get(galgameZywzBrowsePath(optionKey, serverPage));
      } catch (_) {
        if (i == 0) rethrow;
        break;
      }
      final pageItems = parseGameList(html);
      if (pageItems.isEmpty) {
        hasMore = false;
        break;
      }
      items.addAll(pageItems);
      hasMore = parseHasNextPage(html, itemCount: pageItems.length);
      if (!hasMore) break;
    }
    final trimmed = items.length > galgameZywzPageSize
        ? items.sublist(0, galgameZywzPageSize)
        : items;
    return GameList(items: trimmed, page: page, hasMore: hasMore);
  }

  @override
  Future<GameDetail> detail(String id) async {
    final html = await _get('/game/$id');
    return parseGameDetail(html, '$galgameZywzBaseUrl/game/$id');
  }

  Future<String> _get(String path) async {
    final res = await _dio.get<String>(
      path,
      options: Options(responseType: ResponseType.plain),
    );
    final data = res.data;
    if (res.statusCode != 200 || data == null) {
      throw Exception('galgamezywz 请求失败：$path (${res.statusCode})');
    }
    return data;
  }
}
