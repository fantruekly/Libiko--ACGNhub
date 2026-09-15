import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/metadata/bangumi_provider.dart';
import 'package:acgnhub/core/metadata/metadata_provider.dart';

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.data);
  final dynamic data;
  late RequestOptions last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  final calendarItem = {
    'id': 456080,
    'name': '転校先の清楚可憐な美少女が、昔男子と思って一緒に遊んだ幼馴染だった件',
    'name_cn': '转学后班上的清纯可爱美少女',
    'summary': '幼かった夏の終わり。',
    'air_date': '2026-07-06',
    'air_weekday': 1,
    'rating': {'score': 5.6, 'total': 100},
    'rank': 3000,
    'images': {
      'large': 'http://lain.bgm.tv/pic/cover/l/ce/e2/456080_C4q4C.jpg'
    },
  };

  test('parseCalendar maps items to Work with the Chinese name and https cover',
      () {
    final days = [
      {
        'weekday': {'id': 1, 'cn': '星期一'},
        'items': [calendarItem],
      },
    ];

    final works = BangumiProvider.parseCalendar(days);

    expect(works, hasLength(1));
    final w = works.first;
    expect(w.id, 'bangumi_456080');
    expect(w.title, '转学后班上的清纯可爱美少女');
    expect(w.coverUrl,
        'https://images.weserv.nl/?url=https%3A%2F%2Flain.bgm.tv%2Fpic%2Fcover%2Fl%2Fce%2Fe2%2F456080_C4q4C.jpg&w=300');
    expect(w.summary, '幼かった夏の終わり。');
    expect(w.extra['bangumiId'], 456080);
    expect(w.extra['score'], closeTo(5.6, 0.001));
    expect(w.extra['airDate'], '2026-07-06');
  });

  test('parseCalendar onlyWeekday filters days', () {
    final days = [
      {
        'weekday': {'id': 1},
        'items': [calendarItem]
      },
      {
        'weekday': {'id': 3},
        'items': [calendarItem]
      },
    ];
    expect(BangumiProvider.parseCalendar(days, onlyWeekday: 3), hasLength(1));
    expect(BangumiProvider.parseCalendar(days, onlyWeekday: 2), isEmpty);
  });

  test('parseSearch reads data.list and data.data', () {
    expect(
        BangumiProvider.parseSearch({
          'list': [calendarItem]
        }).single.id,
        'bangumi_456080');
    expect(
        BangumiProvider.parseSearch({
          'data': [calendarItem]
        }).single.id,
        'bangumi_456080');
  });

  test('parseDetail reads tags and falls back to name when name_cn is empty',
      () {
    final w = BangumiProvider.parseDetail({
      'id': 1,
      'name': 'Sousou no Frieren',
      'name_cn': '',
      'summary': 'A mage.',
      'date': '2023-09-29',
      'eps': 28,
      'rating': {'score': 8.9},
      'images': {'large': 'http://lain.bgm.tv/x.jpg'},
      'tags': [
        {'name': '奇幻'},
        {'name': '冒险'},
      ],
    });
    expect(w.title, 'Sousou no Frieren');
    expect(w.tags, ['奇幻', '冒险']);
    expect(w.extra['episodes'], 28);
    expect(w.extra['score'], closeTo(8.9, 0.001));
  });

  test('feed(today) filters to the injected weekday; page>1 is empty', () async {
    final days = [
      {
        'weekday': {'id': 4},
        'items': [
          {
            'id': 1,
            'name': 'A',
            'name_cn': '甲',
            'rating': {'score': 8.0}
          }
        ]
      },
      {
        'weekday': {'id': 5},
        'items': [
          {
            'id': 2,
            'name': 'B',
            'name_cn': '乙',
            'rating': {'score': 9.0}
          }
        ]
      },
    ];
    final adapter = _RecordingAdapter(days);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.bgm.tv'))
      ..httpClientAdapter = adapter;
    final provider = BangumiProvider(
        dio: dio, now: () => DateTime(2026, 9, 10)); // Thursday = weekday 4

    final today = await provider.feed(AnimeFeed.today);
    expect(today.single.id, 'bangumi_1');
    expect(adapter.last.path, '/calendar');
    expect(adapter.last.method, 'GET');

    expect(await provider.feed(AnimeFeed.season, page: 2), isEmpty);
  });

  test('feed(trending) posts to v0 search sorted by heat, paged by offset',
      () async {
    final subject = {
      'id': 8,
      'name': 'STEINS;GATE',
      'name_cn': '命运石之门',
      'summary': '秋叶原。',
      'date': '2011-04-06',
      'eps': 24,
      'rating': {'score': 9.0, 'rank': 1, 'total': 100},
      'images': {'large': 'http://lain.bgm.tv/pic/cover/l/x.jpg'},
    };
    final adapter = _RecordingAdapter({
      'data': [subject],
      'total': 1000,
      'limit': 20,
      'offset': 20,
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://api.bgm.tv'))
      ..httpClientAdapter = adapter;
    final provider = BangumiProvider(dio: dio);

    final works = await provider.feed(AnimeFeed.trending, page: 2);

    expect(adapter.last.path, '/v0/search/subjects');
    expect(adapter.last.method, 'POST');
    expect(adapter.last.contentType, Headers.jsonContentType);
    expect(adapter.last.queryParameters['limit'], 20);
    expect(adapter.last.queryParameters['offset'], 20);
    final rawBody = adapter.last.data;
    final body = (rawBody is String ? jsonDecode(rawBody) : rawBody)
        as Map<String, dynamic>;
    expect(body['keyword'], '');
    expect(body['sort'], 'heat');
    expect(body['filter'], {'type': [2], 'nsfw': false});
    final w = works.single;
    expect(w.id, 'bangumi_8');
    expect(w.title, '命运石之门');
    expect(w.extra['bangumiId'], 8);
    expect(w.extra['score'], closeTo(9.0, 0.001));
    expect(w.extra['airDate'], '2011-04-06');
    expect(w.extra['episodes'], 24);
  });

  test('parseCharacters maps name, relation, image and actors', () {
    final data = [
      {
        'id': 1,
        'name': 'ルルーシュ',
        'relation': '主角',
        'images': {'grid': 'http://lain.bgm.tv/crt/g/1.jpg'},
        'actors': [
          {
            'id': 2,
            'name': '福山润',
            'images': {'grid': 'http://lain.bgm.tv/prsn/g/2.jpg'}
          },
        ],
      },
    ];

    final chars = BangumiProvider.parseCharacters(data);
    expect(chars, hasLength(1));
    expect(chars.first.name, 'ルルーシュ');
    expect(chars.first.relation, '主角');
    expect(chars.first.image, 'https://lain.bgm.tv/crt/g/1.jpg');
    expect(chars.first.actors.single.name, '福山润');
    expect(
        chars.first.actors.single.image, 'https://lain.bgm.tv/prsn/g/2.jpg');
  });

  test('parseRelated prefers name_cn and keeps relation', () {
    final data = [
      {
        'id': 231989,
        'name': 'スーパーロボット大戦 X',
        'name_cn': '超级机器人大战X',
        'relation': '游戏',
        'images': {'grid': 'http://lain.bgm.tv/cover/g/231989.jpg'},
      },
    ];

    final rel = BangumiProvider.parseRelated(data);
    expect(rel, hasLength(1));
    expect(rel.first.bangumiId, 231989);
    expect(rel.first.title, '超级机器人大战X');
    expect(rel.first.relation, '游戏');
    expect(rel.first.image, 'https://lain.bgm.tv/cover/g/231989.jpg');
  });
}
