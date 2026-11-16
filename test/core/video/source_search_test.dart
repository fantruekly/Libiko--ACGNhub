import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/video/cancellation.dart';
import 'package:libiko/core/video/source_search.dart';
import 'package:libiko/core/video/video_source.dart';

class _Source implements VideoSource {
  _Source(this.request);
  final Future<List<VideoItem>> Function(String, CancellationToken?) request;
  @override
  String get id => 'source';
  @override
  String get name => 'source';
  @override
  String get baseUrl => 'https://source.test';
  @override
  Future<List<VideoItem>> search(String keyword, {CancellationToken? cancel}) =>
      request(keyword, cancel);
  @override
  Future<List<VideoEpisode>> episodes(String detailUrl,
          {CancellationToken? cancel}) async =>
      [];
}

void main() {
  test('a timed out alias is cancelled without repeating the slow request',
      () async {
    CancellationToken? first;
    final queries = <String>[];
    final source = _Source((query, cancel) async {
      queries.add(query);
      if (query == 'primary') {
        first = cancel;
        return Completer<List<VideoItem>>().future;
      }
      return [];
    });
    final pending =
        const SourceSearch(attemptTimeout: Duration(milliseconds: 30)).run(
            source, ['primary', 'alias', 'unused'],
            cancel: CancellationToken(), matches: (items) => items.isNotEmpty);
    await expectLater(pending, throwsA(isA<TimeoutException>()));
    expect(queries, ['primary']);
    expect(first!.isCancelled, isTrue);
  });

  test(
      'parent cancellation releases the attempt and never starts another alias',
      () async {
    final started = Completer<void>();
    CancellationToken? request;
    var calls = 0;
    final source = _Source((query, cancel) {
      calls++;
      request = cancel;
      started.complete();
      return Completer<List<VideoItem>>().future;
    });
    final parent = CancellationToken();
    final pending = const SourceSearch()
        .run(source, ['one', 'two'], cancel: parent, matches: (_) => false);
    await started.future;
    parent.cancel();
    expect(await pending, isEmpty);
    expect(request!.isCancelled, isTrue);
    expect(calls, 1);
  });

  test('partial results arrive before remaining aliases finish and are deduped',
      () async {
    final gate = Completer<List<VideoItem>>();
    const item = VideoItem(id: 'item', title: 'Candidate', detailUrl: 'detail');
    final partial = Completer<List<VideoItem>>();
    final source =
        _Source((query, _) async => query == 'one' ? [item] : gate.future);
    final pending = const SourceSearch().run(source, ['one', 'two'],
        cancel: CancellationToken(),
        matches: (_) => false,
        onResults: (items) {
          if (!partial.isCompleted) partial.complete(items);
        });
    expect(await partial.future, [item]);
    gate.complete([item]);
    expect(await pending, [item]);
  });

  test('queue and request failures retain their type for the status display',
      () async {
    final source = _Source((_, __) async => throw TimeoutException('slow'));
    await expectLater(
        const SourceSearch().run(source, ['one'],
            cancel: CancellationToken(), matches: (_) => false),
        throwsA(isA<TimeoutException>()));
  });
}
