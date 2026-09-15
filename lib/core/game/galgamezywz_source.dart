import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'models.dart';

const String galgameZywzBaseUrl = 'https://game.galgamezywz.org';
const String galgameZywzUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

const Map<String, String> gameImageHeaders = {
  'Referer': '$galgameZywzBaseUrl/',
};

const Map<String, String> _categorySlugs = {
  'wanjiareping': 'wanjiareping',
  'galgame': 'galgame',
  'haoyoutuijian': 'haoyoutuijian',
  'wanjiazuiai': 'wanjiazuiai',
};

final RegExp _gameHref = RegExp(r'/game/(\d+)');

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
