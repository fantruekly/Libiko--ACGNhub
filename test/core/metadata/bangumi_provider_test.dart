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
    final body = data is String ? data as String : jsonEncode(data);
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [
          data is String ? 'text/html' : Headers.jsonContentType
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _browserHtml = '''
<ul id="browserItemList" class="browserFull browser-list">
<li id="item_633836" class="item odd clearit">
  <a href="/subject/633836" class="subjectCover cover ll coverPortrait"><span class="image"><img src="//lain.bgm.tv/r/400/pic/cover/l/43/ca/633836_ql0f3.jpg" class="cover" loading="lazy"></span></a>
  <div class="inner">
    <h3><a href="/subject/633836" class="l">Re：从零开始的异世界生活 第四季 夺还篇</a><small class="grey">Re:ゼロから始める異世界生活 4th season 奪還篇</small></h3>
    <span class="rank"><small>Rank </small>447</span>
    <p class="info tip"> 8话 / 2026年4月2日 / 篠原正寛 / 長月達平 </p>
    <p class="rateInfo"><span class="starstop-s"><span class="starlight stars8"></span></span> <small class="fade">7.8</small> <span class="tip_j">(1277人评分)</span></p>
  </div>
</li>
<li id="item_622206" class="item even clearit">
  <a href="/subject/622206" class="subjectCover cover ll coverPortrait"><span class="image"><img src="//lain.bgm.tv/r/400/pic/cover/l/6a/b3/622206_dpWcC.jpg" class="cover" loading="lazy"></span></a>
  <div class="inner">
    <h3><a href="/subject/622206" class="l">尼古喵喵</a><small class="grey">ヤニねこ</small></h3>
    <span class="rank"><small>Rank </small>1396</span>
    <p class="info tip"> 12话 / 2026年1月3日 / 木村 </p>
    <p class="rateInfo"><span class="starstop-s"><span class="starlight stars7"></span></span> <small class="fade">7.3</small> <span class="tip_j">(4043人评分)</span></p>
  </div>
</li>
</ul>
''';

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

  test('feed(trending) scrapes the website trends browser', () async {
    final adapter = _RecordingAdapter(_browserHtml);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.bgm.tv'))
      ..httpClientAdapter = adapter;
    final provider = BangumiProvider(dio: dio);

    final works = await provider.feed(AnimeFeed.trending, page: 2);

    expect(adapter.last.method, 'GET');
    expect(adapter.last.uri.host, 'bgm.tv');
    expect(adapter.last.uri.path, '/anime/browser');
    expect(adapter.last.queryParameters['sort'], 'trends');
    expect(adapter.last.queryParameters['page'], 2);
    expect(works, hasLength(2));
    final w = works.first;
    expect(w.id, 'bangumi_633836');
    expect(w.title, 'Re：从零开始的异世界生活 第四季 夺还篇');
    expect(w.extra['bangumiId'], 633836);
    expect(w.extra['score'], closeTo(7.8, 0.001));
    expect(w.extra['rank'], 447);
    expect(w.extra['episodes'], 8);
    expect(w.extra['airDate'], '2026-04-02');
  });

  test('parseBrowserList maps the trends browser HTML', () {
    final works = BangumiProvider.parseBrowserList(_browserHtml);
    expect(works, hasLength(2));
    final w = works.first;
    expect(w.id, 'bangumi_633836');
    expect(w.title, 'Re：从零开始的异世界生活 第四季 夺还篇');
    expect(w.coverUrl,
        'https://images.weserv.nl/?url=https%3A%2F%2Flain.bgm.tv%2Fr%2F400%2Fpic%2Fcover%2Fl%2F43%2Fca%2F633836_ql0f3.jpg&w=300');
    expect(w.extra['bangumiId'], 633836);
    expect(w.extra['score'], closeTo(7.8, 0.001));
    expect(w.extra['rank'], 447);
    expect(w.extra['episodes'], 8);
    expect(w.extra['airDate'], '2026-04-02');
    final second = works.last;
    expect(second.title, '尼古喵喵');
    expect(second.extra['episodes'], 12);
    expect(second.extra['airDate'], '2026-01-03');
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
