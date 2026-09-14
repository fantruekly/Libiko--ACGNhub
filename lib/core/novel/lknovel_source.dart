import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'models.dart';
import 'novel_source.dart';

const String lknovelBaseUrl = 'https://www.lightnovel.fun';
const String lknovelUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

typedef LkPoster = Future<Map<String, dynamic>> Function(
    String endpoint, Map<String, dynamic> body);

Map<String, dynamic> lkData(Map<String, dynamic> json) =>
    (json['data'] as Map?)?.cast<String, dynamic>() ?? const {};

int? _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

bool _asBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final t = v.toLowerCase();
    return t == '1' || t == 'true';
  }
  return false;
}

String? _nonEmpty(dynamic v) {
  final s = v?.toString();
  return (s == null || s.isEmpty) ? null : s;
}

String? _imageUrl(dom.Element el) {
  final raw = el.attributes['data-src'] ?? el.attributes['src'];
  if (raw == null || raw.isEmpty) return null;
  if (raw.startsWith('http')) return raw;
  if (raw.startsWith('//')) return 'https:$raw';
  return raw.startsWith('/') ? '$lknovelBaseUrl$raw' : '$lknovelBaseUrl/$raw';
}

List<String> _stringList(dynamic raw) {
  if (raw is List) {
    return [
      for (final e in raw)
        if (e != null && e.toString().isNotEmpty) e.toString(),
    ];
  }
  return const [];
}

Novel parseLkBook(Map<String, dynamic> json) {
  final tags = <String>[
    ..._stringList(json['visible_tags']),
    ..._stringList(json['tags']),
  ];
  final seen = <String>{};
  final uniq = [for (final t in tags) if (seen.add(t)) t];
  final rank = _asInt(json['rank_position']);
  return Novel(
    id: (json['book_id'] ?? json['id'])?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    author: _nonEmpty(json['author_name']),
    coverUrl: _nonEmpty(json['cover_url']),
    tags: uniq,
    summary: _nonEmpty(json['summary']) ?? _nonEmpty(json['summary_short']),
    extra: {
      if (rank != null && rank > 0) 'rank': rank,
    },
  );
}

List<Novel> parseLkList(Map<String, dynamic> data) {
  final raw = data['list'] ?? data['cards'];
  if (raw is! List) return const [];
  return [
    for (final e in raw)
      if (e is Map) parseLkBook(e.cast<String, dynamic>()),
  ];
}

bool lkHasMore(Map<String, dynamic> data, int page) {
  final p = data['pagination'];
  if (p is Map) {
    final pageCount = _asInt(p['page_count']);
    if (pageCount != null) return page < pageCount;
    final flag = p['has_more'] ?? p['hasMore'];
    if (flag != null) return _asBool(flag);
  }
  final info = data['page_info'];
  if (info is Map) {
    final next = _asInt(info['next']);
    if (next != null) return next > 0;
    final flag = info['has_next'] ?? info['hasNext'];
    if (flag != null) return _asBool(flag);
  }
  return parseLkList(data).length >= 30;
}

List<NovelVolume> parseLkVolumes(Map<String, dynamic> data) {
  final raw = data['volumes'] ?? data['list'];
  if (raw is! List) return const [];
  final out = <NovelVolume>[];
  for (final e in raw) {
    if (e is! Map) continue;
    final v = e.cast<String, dynamic>();
    out.add(NovelVolume(
      id: (v['volume_id'] ?? v['id'])?.toString(),
      title: v['title']?.toString() ?? '',
    ));
  }
  return out;
}

List<NovelChapterRef> parseLkVolumeChapters(Map<String, dynamic> data) {
  final raw = data['list'];
  if (raw is! List) return const [];
  final out = <NovelChapterRef>[];
  for (final e in raw) {
    if (e is! Map) continue;
    final c = e.cast<String, dynamic>();
    final id = (c['chapter_id'] ?? c['id'])?.toString() ?? '';
    if (id.isEmpty) continue;
    out.add(NovelChapterRef(id: id, title: c['title']?.toString() ?? ''));
  }
  return out;
}

NovelChapter parseLkChapter(Map<String, dynamic> data, String fallbackTitle) {
  final title = _nonEmpty(data['title']) ?? fallbackTitle;
  final snapshot = data['body_snapshot'];
  final html =
      (snapshot is Map ? snapshot['body_html'] : null)?.toString() ?? '';
  final blocks = <NovelBlock>[];
  if (html.isNotEmpty) {
    final doc = html_parser.parse(html);
    for (final el in doc.querySelectorAll('p, img')) {
      if (el.localName == 'p') {
        final t = el.text.trim();
        if (t.isNotEmpty) blocks.add(NovelText(t));
      } else {
        final url = _imageUrl(el);
        if (url != null) blocks.add(NovelImage(url));
      }
    }
  }
  return NovelChapter(title: title, blocks: blocks);
}

class LknovelSource implements NovelSource {
  LknovelSource({Dio? dio, LkPoster? poster})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: lknovelBaseUrl,
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 20),
              headers: {
                'User-Agent': lknovelUserAgent,
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                'Referer': '$lknovelBaseUrl/',
              },
            )),
        _poster = poster;

  final Dio _dio;
  final LkPoster? _poster;

  @override
  String get id => 'lknovel';

  @override
  String get name => '轻之国度';

  @override
  String get baseUrl => lknovelBaseUrl;

  static const Set<String> rankingKeys = {
    'weekly_hot',
    'daily_hot',
    'daily_fresh',
    'weekly_fresh',
  };

  static const Map<String, String> feedEndpoints = {
    'lightnovel': 'bff/home-lightnovel-feed-v1',
    'original': 'bff/home-original-feed-v1',
    'fanfic': 'bff/home-fanfic-feed-v1',
    'recent_updates': 'bff/home-recent-updates-feed-v1',
    'new_books': 'bff/home-feed-v1',
  };

  @override
  List<NovelBrowseGroup> get browseGroups => const [
        NovelBrowseGroup(label: '排行', options: [
          NovelBrowseOption(key: 'weekly_hot', label: '综合热度'),
          NovelBrowseOption(key: 'daily_hot', label: '日热度'),
          NovelBrowseOption(key: 'daily_fresh', label: '日新书'),
          NovelBrowseOption(key: 'weekly_fresh', label: '周新书'),
        ]),
        NovelBrowseGroup(label: '分类', options: [
          NovelBrowseOption(key: 'lightnovel', label: '轻小说'),
          NovelBrowseOption(key: 'original', label: '原创'),
          NovelBrowseOption(key: 'fanfic', label: '同人'),
          NovelBrowseOption(key: 'recent_updates', label: '最近更新'),
          NovelBrowseOption(key: 'new_books', label: '新书'),
        ]),
      ];

  Future<Map<String, dynamic>> _post(
      String endpoint, Map<String, dynamic> body) {
    final poster = _poster;
    if (poster != null) return poster(endpoint, body);
    return _httpPost(endpoint, body);
  }

  Future<Map<String, dynamic>> _httpPost(
      String endpoint, Map<String, dynamic> body) async {
    final res =
        await _dio.post<dynamic>('/api/pc-proxy/api/$endpoint', data: body);
    final raw = res.data;
    if (raw is! Map) throw Exception('lknovel 响应格式错误：$endpoint');
    final map = raw.cast<String, dynamic>();
    if (_asInt(map['code']) != 0) {
      throw Exception('lknovel 请求失败：$endpoint (code=${map['code']})');
    }
    return map;
  }

  @override
  Future<NovelHome> home() async {
    const feeds = [
      ('轻小说', 'bff/home-lightnovel-feed-v1'),
      ('原创', 'bff/home-original-feed-v1'),
      ('同人', 'bff/home-fanfic-feed-v1'),
      ('最近更新', 'bff/home-recent-updates-feed-v1'),
    ];
    final sections = await Future.wait(feeds.map((f) async {
      try {
        final json =
            await _post(f.$2, {'page': 1, 'page_size': 20, 'pageSize': 20});
        return NovelSection(title: f.$1, items: parseLkList(lkData(json)));
      } catch (_) {
        return NovelSection(title: f.$1, items: const []);
      }
    }));
    final nonEmpty = [for (final s in sections) if (s.items.isNotEmpty) s];
    if (nonEmpty.isEmpty) throw Exception('lknovel 首页解析为空');
    return NovelHome(sections: nonEmpty);
  }

  @override
  Future<NovelList> browse(String optionKey, {int page = 1}) async {
    final Map<String, dynamic> json;
    if (rankingKeys.contains(optionKey)) {
      json = await _post('bff/book-rank-list-v1', {
        'rank_scene': optionKey,
        'page': page,
        'page_size': 30,
        'pageSize': 30,
      });
    } else {
      final endpoint = feedEndpoints[optionKey];
      if (endpoint == null) {
        throw ArgumentError('unknown browse option: $optionKey');
      }
      json = await _post(
          endpoint, {'page': page, 'page_size': 30, 'pageSize': 30});
    }
    final data = lkData(json);
    return NovelList(
      items: parseLkList(data),
      page: page,
      hasMore: lkHasMore(data, page),
    );
  }

  @override
  Future<List<Novel>> search(String keyword, {int page = 1}) =>
      throw UnimplementedError();

  @override
  Future<NovelDetail> detail(String id) async {
    final json = await _post(
        'new-content-read/get-book-detail', {'book_id': id, 'with_volumes': 1});
    final data = lkData(json);
    final novel = parseLkBook(data);
    final metas = parseLkVolumes(data);
    const batchSize = 12;
    final volumes = <NovelVolume>[];
    for (var i = 0; i < metas.length; i += batchSize) {
      final end = (i + batchSize).clamp(0, metas.length);
      final batch = metas.sublist(i, end);
      final loaded = await Future.wait(batch.map((v) async {
        try {
          final chapters = await _volumeChapters(id, v.id ?? '');
          return NovelVolume(id: v.id, title: v.title, chapters: chapters);
        } catch (_) {
          return NovelVolume(id: v.id, title: v.title, chapters: const []);
        }
      }));
      volumes.addAll(loaded);
    }
    return NovelDetail(novel: novel, volumes: volumes);
  }

  Future<List<NovelChapterRef>> _volumeChapters(
      String bookId, String volumeId) async {
    final out = <NovelChapterRef>[];
    var page = 1;
    while (true) {
      final json = await _post('new-content-read/get-volume-chapters', {
        'book_id': bookId,
        'volume_id': volumeId,
        'page': page,
        'page_size': 50,
        'pageSize': 50,
      });
      final data = lkData(json);
      out.addAll(parseLkVolumeChapters(data));
      if (!lkHasMore(data, page) || page >= 100) break;
      page++;
    }
    return out;
  }

  @override
  Future<NovelChapter> chapter(String novelId, String chapterId) async {
    final json = await _post('new-content-read/get-chapter-detail',
        {'book_id': novelId, 'chapter_id': chapterId});
    return parseLkChapter(lkData(json), '');
  }
}
