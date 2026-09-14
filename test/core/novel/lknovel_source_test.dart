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
