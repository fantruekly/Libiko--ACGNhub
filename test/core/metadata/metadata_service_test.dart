import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/metadata/metadata_provider.dart';
import 'package:acgnhub/core/metadata/metadata_service.dart';
import 'package:acgnhub/core/models/work.dart';

class _FakeProvider implements MetadataProvider {
  @override
  final String id;
  bool fail;
  int calls = 0;
  _FakeProvider(this.id, {this.fail = false});

  List<Work> _items() => [
        Work(id: '${id}_1', sourceId: id, sourceName: id, type: WorkType.anime, title: id),
      ];

  @override
  Future<List<Work>> feed(AnimeFeed feed, {int page = 1}) async {
    calls++;
    if (fail) throw DioException(requestOptions: RequestOptions(path: '/$id'));
    return _items();
  }

  @override
  Future<List<Work>> search(String keyword, {int page = 1}) async {
    calls++;
    if (fail) throw DioException(requestOptions: RequestOptions(path: '/$id'));
    return _items();
  }

  @override
  Future<Work> detail(Work work) async {
    calls++;
    if (fail) throw DioException(requestOptions: RequestOptions(path: '/$id'));
    return work;
  }
}

class _SlowFakeProvider extends _FakeProvider {
  int _concurrent = 0;
  int maxConcurrent = 0;
  _SlowFakeProvider(super.id);

  Future<void> _track() async {
    _concurrent++;
    if (_concurrent > maxConcurrent) maxConcurrent = _concurrent;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    _concurrent--;
  }

  @override
  Future<List<Work>> feed(AnimeFeed feed, {int page = 1}) async {
    await _track();
    return super.feed(feed, page: page);
  }

  @override
  Future<List<Work>> search(String keyword, {int page = 1}) async {
    await _track();
    return super.search(keyword, page: page);
  }
}

void main() {
  test('falls back to Jikan when AniList fails, then skips AniList for 10 min', () async {
    var now = DateTime(2026, 9, 10, 12);
    final anilist = _FakeProvider('anilist', fail: true);
    final jikan = _FakeProvider('jikan');
    final service = MetadataService(anilist: anilist, jikan: jikan, now: () => now);

    final first = await service.feed(AnimeFeed.trending);
    expect(first.single.sourceId, 'jikan');
    expect(anilist.calls, 1);
    expect(jikan.calls, 1);

    // Within 10 min: different key, AniList is skipped entirely.
    await service.feed(AnimeFeed.trending, page: 2);
    expect(anilist.calls, 1);
    expect(jikan.calls, 2);

    // After 10 min: AniList is retried (now healthy).
    anilist.fail = false;
    now = now.add(const Duration(minutes: 11));
    final third = await service.feed(AnimeFeed.trending, page: 3);
    expect(third.single.sourceId, 'anilist');
    expect(anilist.calls, 2);
  });

  test('caches identical calls for 5 minutes', () async {
    final anilist = _FakeProvider('anilist');
    final jikan = _FakeProvider('jikan');
    final service = MetadataService(anilist: anilist, jikan: jikan);

    await service.feed(AnimeFeed.trending);
    await service.feed(AnimeFeed.trending);
    expect(anilist.calls, 1);
  });

  test('invalidate forces a refetch', () async {
    final anilist = _FakeProvider('anilist');
    final jikan = _FakeProvider('jikan');
    final service = MetadataService(anilist: anilist, jikan: jikan);

    await service.feed(AnimeFeed.trending);
    await service.feed(AnimeFeed.trending);
    expect(anilist.calls, 1);

    service.invalidate('feed:trending:');
    await service.feed(AnimeFeed.trending);
    expect(anilist.calls, 2);
  });

  test('serializes Jikan calls (no overlap)', () async {
    final anilist = _FakeProvider('anilist', fail: true);
    final jikan = _SlowFakeProvider('jikan');
    final service = MetadataService(anilist: anilist, jikan: jikan);

    await Future.wait([
      service.feed(AnimeFeed.trending),
      service.search('a'),
    ]);
    expect(jikan.maxConcurrent, 1);
  });
}
