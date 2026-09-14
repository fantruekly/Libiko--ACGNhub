### Task 2: `LknovelSource` 客户端 + 解析器 + 首页/浏览 + 注册

新增 lknovel 书源的 JSON 客户端、纯解析函数、`home`/`browse`/`browseGroups`，并注册到 `NovelSourceManager`。`detail`/`chapter` 本任务先用 `UnimplementedError` 占位（Task 3 实现）。

**Files:**
- Create: `lib/core/novel/lknovel_source.dart`
- Modify: `lib/modules/novel/novel_providers.dart`
- Test: `test/core/novel/lknovel_source_test.dart`

**Interfaces:**
- Consumes: `NovelBrowseOption`、`NovelBrowseGroup`、`NovelSource`、`NovelHome`、`NovelList`、`Novel`、`NovelSection`（Task 1）。
- Produces:
  - `const String lknovelBaseUrl`
  - `typedef LkPoster = Future<Map<String, dynamic>> Function(String endpoint, Map<String, dynamic> body);`
  - `Map<String, dynamic> lkData(Map<String, dynamic> json)`
  - `Novel parseLkBook(Map<String, dynamic> json)`
  - `List<Novel> parseLkList(Map<String, dynamic> data)`
  - `bool lkHasMore(Map<String, dynamic> data, int page)`
  - `List<NovelVolume> parseLkVolumes(Map<String, dynamic> data)`
  - `List<NovelChapterRef> parseLkVolumeChapters(Map<String, dynamic> data)`
  - `NovelChapter parseLkChapter(Map<String, dynamic> data, String fallbackTitle)`
  - `class LknovelSource implements NovelSource`，构造 `LknovelSource({Dio? dio, LkPoster? poster})`，`id: 'lknovel'`，`name: '轻之国度'`
  - `LknovelSource.rankingKeys`、`LknovelSource.feedEndpoints`

- [ ] **Step 1: 写解析器与源的失败测试**

创建 `test/core/novel/lknovel_source_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/novel/lknovel_source.dart';
import 'package:acgnhub/core/novel/models.dart';

const _bookJson = {
  'book_id': 1338,
  'title': '败犬女主太多了！',
  'author_name': '雨森たきび',
  'cover_url': 'https://api.lightnovel.fun/x.jpg',
  'summary': '简介',
  'tags': ['轻小说', '校园'],
  'visible_tags': ['轻小说', '校园', '恋爱'],
  'chapter_count': 91,
  'volume_count': 13,
  'rank_position': 1,
};

const _feedData = {
  'scene': 'lightnovel_books',
  'list': [_bookJson],
  'pagination': {'page': 1, 'page_size': 30, 'total': 560, 'page_count': 19},
};

const _rankData = {
  'scene': 'weekly_hot',
  'list': [_bookJson],
  'pagination': {'page': 1, 'page_size': 30, 'total': 30, 'page_count': 2},
};

const _detailData = {
  'book_id': 1338,
  'title': '败犬女主太多了！',
  'author_name': '雨森たきび',
  'cover_url': 'https://api.lightnovel.fun/x.jpg',
  'summary': '简介',
  'tags': ['轻小说'],
  'volumes': [
    {'volume_id': 36754, 'title': '1卷', 'chapter_count': 2},
    {'volume_id': 36746, 'title': '1卷特典', 'chapter_count': 1},
  ],
};

const _chapterData = {
  'title': '一败目 专业青梅竹马',
  'body_snapshot': {
    'body_html':
        '<p class="ln-paragraph">第一段</p><img src="https://api.lightnovel.fun/a.jpg" /><p>第二段</p>',
  },
};

void main() {
  test('parseLkBook maps fields and dedupes tags', () {
    final n = parseLkBook(_bookJson);
    expect(n.id, '1338');
    expect(n.title, '败犬女主太多了！');
    expect(n.author, '雨森たきび');
    expect(n.coverUrl, 'https://api.lightnovel.fun/x.jpg');
    expect(n.tags, ['轻小说', '校园', '恋爱']);
    expect(n.summary, '简介');
    expect(n.extra['rank'], 1);
  });

  test('parseLkList reads data.list and data.cards', () {
    expect(parseLkList(_feedData).single.id, '1338');
    expect(parseLkList(const {'cards': [_bookJson]}).single.title, '败犬女主太多了！');
  });

  test('lkHasMore uses pagination.page_count', () {
    expect(lkHasMore(_feedData, 1), isTrue);
    expect(lkHasMore(_feedData, 19), isFalse);
  });

  test('parseLkVolumes reads volume ids and titles', () {
    final vols = parseLkVolumes(_detailData);
    expect(vols.map((v) => v.id), ['36754', '36746']);
    expect(vols.map((v) => v.title), ['1卷', '1卷特典']);
  });

  test('parseLkVolumeChapters reads chapter refs', () {
    final refs = parseLkVolumeChapters(const {
      'list': [
        {'chapter_id': 276838, 'title': '一败目'},
        {'chapter_id': 276839, 'title': '间章'},
      ],
    });
    expect(refs.map((c) => c.id), ['276838', '276839']);
    expect(refs.last.title, '间章');
  });

  test('parseLkChapter parses paragraphs and illustrations', () {
    final chapter = parseLkChapter(_chapterData, '');
    expect(chapter.title, '一败目 专业青梅竹马');
    expect(chapter.blocks.whereType<NovelText>().map((b) => b.text),
        ['第一段', '第二段']);
    expect(chapter.blocks.whereType<NovelImage>().single.url,
        'https://api.lightnovel.fun/a.jpg');
  });

  test('home builds sections from feeds', () async {
    final source = LknovelSource(poster: (endpoint, body) async {
      if (endpoint.contains('feed')) {
        return {'code': 0, 'data': _feedData};
      }
      throw Exception('unexpected endpoint: $endpoint');
    });
    final home = await source.home();
    expect(home.sections, isNotEmpty);
    expect(home.sections.first.items.single.title, '败犬女主太多了！');
  });

  test('browse ranking sends rank_scene', () async {
    Map<String, dynamic>? seen;
    final source = LknovelSource(poster: (endpoint, body) async {
      expect(endpoint, 'bff/book-rank-list-v1');
      seen = body;
      return {'code': 0, 'data': _rankData};
    });
    final list = await source.browse('weekly_hot', page: 1);
    expect(seen!['rank_scene'], 'weekly_hot');
    expect(list.items.single.id, '1338');
    expect(list.hasMore, isTrue);
  });

  test('browse category sends feed endpoint', () async {
    String? seenEndpoint;
    final source = LknovelSource(poster: (endpoint, body) async {
      seenEndpoint = endpoint;
      return {'code': 0, 'data': _feedData};
    });
    await source.browse('lightnovel', page: 2);
    expect(seenEndpoint, 'bff/home-lightnovel-feed-v1');
  });

  test('source identity and browse groups', () {
    final s = LknovelSource();
    expect(s.id, 'lknovel');
    expect(s.name, '轻之国度');
    expect(s.baseUrl, lknovelBaseUrl);
    expect(s.browseGroups.map((g) => g.label), ['排行', '分类']);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/lknovel_source_test.dart`
Expected: 编译失败（`lknovel_source.dart` 不存在 / `parseLkBook` 未定义）。

- [ ] **Step 3: 实现 `lib/core/novel/lknovel_source.dart`**

创建文件，内容如下（`detail`/`chapter` 暂为占位）：

```dart
import 'package:dio/dio.dart';
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
    summary: _nonEmpty(json['summary_short']) ?? _nonEmpty(json['summary']),
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
        final src = el.attributes['src'] ?? el.attributes['data-src'];
        if (src != null && src.isNotEmpty) blocks.add(NovelImage(src));
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

  static const List<String> rankingKeys = [
    'weekly_hot',
    'daily_hot',
    'daily_fresh',
    'weekly_fresh',
  ];

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
    if (map['code'] != 0) {
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
  Future<NovelDetail> detail(String id) => throw UnimplementedError();

  @override
  Future<NovelChapter> chapter(String novelId, String chapterId) =>
      throw UnimplementedError();
}
```

- [ ] **Step 4: 注册书源**

编辑 `lib/modules/novel/novel_providers.dart`：加入 import

```dart
import '../../core/novel/lknovel_source.dart';
```

并把 `novelSourceManagerProvider` 改为：

```dart
final novelSourceManagerProvider = Provider<NovelSourceManager>(
  (ref) => NovelSourceManager(sources: [LinovelibSource(), LknovelSource()]),
);
```

- [ ] **Step 5: 运行静态检查与测试**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib test`
Expected: `No issues found!`

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter test test/core/novel/lknovel_source_test.dart`
Expected: 全部通过。

- [ ] **Step 6: 提交**

```bash
git add lib/core/novel/lknovel_source.dart lib/modules/novel/novel_providers.dart test/core/novel/lknovel_source_test.dart
git commit -m "feat(novel): add lknovel source with home and browse"
git push origin dev
```

---
