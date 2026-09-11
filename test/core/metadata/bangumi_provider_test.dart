import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/metadata/bangumi_provider.dart';
import 'package:acgnhub/core/metadata/metadata_provider.dart';

class _FakeAdapter implements HttpClientAdapter {
  final dynamic data;
  _FakeAdapter(this.data);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
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

  test('parseSearch reads data.list', () {
    final works = BangumiProvider.parseSearch({
      'list': [calendarItem]
    });
    expect(works.single.id, 'bangumi_456080');
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

  test(
      'feed(today) filters to the injected weekday; page>1 is empty; trending sorts by score',
      () async {
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
    final dio = Dio(BaseOptions(baseUrl: 'https://api.bgm.tv'))
      ..httpClientAdapter = _FakeAdapter(days);
    final provider = BangumiProvider(
        dio: dio, now: () => DateTime(2026, 9, 10)); // Thursday = weekday 4

    final today = await provider.feed(AnimeFeed.today);
    expect(today.single.id, 'bangumi_1');

    expect(await provider.feed(AnimeFeed.season, page: 2), isEmpty);

    final trending = await provider.feed(AnimeFeed.trending);
    expect(trending.first.id, 'bangumi_2'); // 9.0 before 8.0
  });
}
