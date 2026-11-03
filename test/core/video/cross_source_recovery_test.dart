import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/models/work.dart';
import 'package:libiko/core/video/cancellation.dart';
import 'package:libiko/core/video/cross_source_recovery.dart';
import 'package:libiko/core/video/video_source.dart';

class _Source implements VideoSource {
  _Source(this.id, this.load);
  @override
  final String id;
  final Future<List<VideoEpisode>> Function(CancellationToken?) load;
  @override
  String get name => id;
  @override
  String get baseUrl => 'https://source.test';
  @override
  Future<List<VideoItem>> search(String keyword,
          {CancellationToken? cancel}) async =>
      [];
  @override
  Future<List<VideoEpisode>> episodes(String detailUrl,
          {CancellationToken? cancel}) =>
      load(cancel);
}

const _item = VideoItem(id: 'detail', title: 'Test', detailUrl: '/detail');
const _current = VideoEpisode(
    id: 'a',
    title: '1',
    index: 0,
    playUrl: 'https://a/play',
    sourceId: 'a',
    lineId: '1',
    episodeKey: 'episode:1');
VideoEpisode _ep(String source, String key, {String line = '1'}) =>
    VideoEpisode(
        id: '$source/$key',
        title: key,
        index: 0,
        playUrl: 'https://$source/play',
        sourceId: source,
        lineId: line,
        episodeKey: key);
PlaybackRecoveryRequest _request({CancellationToken? cancel}) =>
    PlaybackRecoveryRequest(
        episode: _current,
        attemptedSources: const {'a'},
        cancel: cancel ?? CancellationToken());

void main() {
  test(
      'automatic matching rejects season conflicts, edition conflicts and ties',
      () {
    const work = Work(
        id: '1',
        sourceId: 'meta',
        sourceName: 'Meta',
        type: WorkType.anime,
        title: 'Test 第二季');
    const selected = VideoItem(id: '2', title: 'Test 第二季', detailUrl: '/2');
    expect(isUnambiguousRecoveryMatch(work, selected, [selected]), isTrue);
    expect(
        isUnambiguousRecoveryMatch(work,
            const VideoItem(id: '1', title: 'Test 第一季', detailUrl: '/1'), []),
        isFalse);
    expect(
        isUnambiguousRecoveryMatch(
            work,
            const VideoItem(id: '1', title: 'Test 第二季 剧场版', detailUrl: '/1'),
            []),
        isFalse);
    expect(
        isUnambiguousRecoveryMatch(work, selected, [
          selected,
          const VideoItem(id: '3', title: 'Test 第二季', detailUrl: '/3')
        ]),
        isFalse);
  });
  test('matches an exact episode key, never an array position or OVA',
      () async {
    final source = _Source(
        'b', (_) async => [_ep('b', 'title:ova'), _ep('b', 'episode:1')]);
    final result =
        await CrossSourceRecovery([PlaybackSourceCandidate(source, _item)])
            .find(_request());
    expect(result.alternative?.index, 1);
    expect(result.attemptedSources, {'b'});
  });
  test('duplicate episode identities require manual selection', () async {
    final source = _Source(
        'b', (_) async => [_ep('b', 'episode:1'), _ep('b', 'episode:1')]);
    final result =
        await CrossSourceRecovery([PlaybackSourceCandidate(source, _item)])
            .find(_request());
    expect(result.alternative, isNull);
  });
  test('at most two other sources are tried and each source only once',
      () async {
    final tried = <String>[];
    _Source source(String id) => _Source(id, (_) async {
          tried.add(id);
          return [];
        });
    final b = source('b');
    final result = await CrossSourceRecovery([
      PlaybackSourceCandidate(b, _item),
      PlaybackSourceCandidate(b, _item),
      PlaybackSourceCandidate(source('c'), _item),
      PlaybackSourceCandidate(source('d'), _item),
    ]).find(_request());
    expect(tried, ['b', 'c']);
    expect(result.attemptedSources, {'b', 'c'});
  });
  test('parent cancellation wakes and cancels an in-flight episode request',
      () async {
    final entered = Completer<void>();
    CancellationToken? borrowed;
    final source = _Source('b', (cancel) {
      borrowed = cancel;
      entered.complete();
      return Completer<List<VideoEpisode>>().future;
    });
    final cancel = CancellationToken();
    final pending =
        CrossSourceRecovery([PlaybackSourceCandidate(source, _item)])
            .find(_request(cancel: cancel));
    await entered.future;
    cancel.cancel();
    expect((await pending).alternative, isNull);
    expect(borrowed?.isCancelled, isTrue);
  });
  test('one total deadline bounds all source requests', () async {
    CancellationToken? borrowed;
    final source = _Source('b', (cancel) {
      borrowed = cancel;
      return Completer<List<VideoEpisode>>().future;
    });
    final result = await CrossSourceRecovery(
            [PlaybackSourceCandidate(source, _item)],
            timeout: const Duration(milliseconds: 25))
        .find(_request())
        .timeout(const Duration(milliseconds: 300));
    expect(result.alternative, isNull);
    expect(borrowed?.isCancelled, isTrue);
  });
}
