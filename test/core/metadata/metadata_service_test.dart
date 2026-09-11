import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/metadata/metadata_cache.dart';
import 'package:acgnhub/core/metadata/metadata_provider.dart';
import 'package:acgnhub/core/metadata/metadata_service.dart';
import 'package:acgnhub/core/models/work.dart';

class _FakeCache implements MetadataCache {
  final Map<String, String> store = {};

  @override
  Future<String?> read(String key) async => store[key];

  @override
  Future<void> write(String key, String value) async {
    store[key] = value;
  }
}

class _FakeProvider implements MetadataProvider {
  @override
  final String id;
  bool fail;
  bool transient;
  int calls = 0;
  _FakeProvider(this.id, {this.fail = false, this.transient = false});

  DioException _error() => DioException(
        requestOptions: RequestOptions(path: '/$id'),
        response: transient
            ? Response(requestOptions: RequestOptions(path: '/$id'), statusCode: 503)
            : null,
      );

  List<Work> _items() => [
        Work(id: '${id}_1', sourceId: id, sourceName: id, type: WorkType.anime, title: id),
      ];

  @override
  Future<List<Work>> feed(AnimeFeed feed, {int page = 1}) async {
    calls++;
    if (fail) throw _error();
    return _items();
  }

  @override
  Future<List<Work>> search(String keyword, {int page = 1}) async {
    calls++;
    if (fail) throw _error();
    return _items();
  }

  @override
  Future<Work> detail(Work work) async {
    calls++;
    if (fail) throw _error();
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

class _FlakyProvider extends _FakeProvider {
  int remainingFailures;
  _FlakyProvider(super.id, {required this.remainingFailures});

  @override
  Future<List<Work>> feed(AnimeFeed feed, {int page = 1}) async {
    calls++;
    if (remainingFailures > 0) {
      remainingFailures--;
      throw DioException(
        requestOptions: RequestOptions(path: '/$id'),
        response: Response(requestOptions: RequestOptions(path: '/$id'), statusCode: 504),
      );
    }
    return _items();
  }
}

MetadataService _service({
  MetadataProvider? bangumi,
  MetadataProvider? anilist,
  MetadataProvider? jikan,
  MetadataCache? cache,
  MetadataSeedLoader? seedLoader,
  DateTime Function()? now,
}) {
  return MetadataService(
    bangumi: bangumi ?? _FakeProvider('bangumi', fail: true),
    anilist: anilist ?? _FakeProvider('anilist'),
    jikan: jikan ?? _FakeProvider('jikan'),
    cache: cache ?? _FakeCache(),
    seedLoader: seedLoader ?? () async => const [],
    now: now,
    intervals: const {},
  );
}

void main() {
  test('tries Bangumi first, then falls back', () async {
    final bangumi = _FakeProvider('bangumi', fail: true);
    final anilist = _FakeProvider('anilist');
    final service = _service(bangumi: bangumi, anilist: anilist);

    final works = await service.feed(AnimeFeed.trending);
    expect(works.single.sourceId, 'anilist');
    expect(bangumi.calls, 1);
    expect(anilist.calls, 1);
  });

  test('falls back to Jikan when AniList fails, then skips AniList for 10 min', () async {
    var now = DateTime(2026, 9, 10, 12);
    final anilist = _FakeProvider('anilist', fail: true, transient: true);
    final jikan = _FakeProvider('jikan');
    final service = _service(anilist: anilist, jikan: jikan, now: () => now);

    final first = await service.feed(AnimeFeed.trending);
    expect(first.single.sourceId, 'jikan');
    expect(anilist.calls, 4); // retried up to _maxAttempts before being disabled
    expect(jikan.calls, 1);

    // Within 10 min: different key, AniList is skipped entirely.
    await service.feed(AnimeFeed.trending, page: 2);
    expect(anilist.calls, 4);
    expect(jikan.calls, 2);

    // After 10 min: AniList is retried (now healthy).
    anilist.fail = false;
    now = now.add(const Duration(minutes: 11));
    final third = await service.feed(AnimeFeed.trending, page: 3);
    expect(third.single.sourceId, 'anilist');
    expect(anilist.calls, 5);
  });

  test('caches identical calls for 5 minutes', () async {
    final anilist = _FakeProvider('anilist');
    final service = _service(anilist: anilist);

    await service.feed(AnimeFeed.trending);
    await service.feed(AnimeFeed.trending);
    expect(anilist.calls, 1);
  });

  test('invalidate forces a refetch', () async {
    final anilist = _FakeProvider('anilist');
    final service = _service(anilist: anilist);

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
    final service = _service(anilist: anilist, jikan: jikan);

    await Future.wait([
      service.feed(AnimeFeed.trending),
      service.search('a'),
    ]);
    expect(jikan.maxConcurrent, 1);
  });

  test('retries transient provider failures', () async {
    final anilist = _FakeProvider('anilist', fail: true);
    final jikan = _FlakyProvider('jikan', remainingFailures: 2);
    final service = _service(anilist: anilist, jikan: jikan);

    final works = await service.feed(AnimeFeed.trending);
    expect(works, isNotEmpty);
    expect(jikan.calls, 3);
  });

  test('returns disk-cached feed when all providers fail', () async {
    final cache = _FakeCache();
    cache.store['feed:trending:1'] = jsonEncode([
      Work(
        id: 'cached_1',
        sourceId: 'cached',
        sourceName: 'Cached',
        type: WorkType.anime,
        title: 'Cached Anime',
      ).toJson(),
    ]);
    final service = _service(
      anilist: _FakeProvider('anilist', fail: true),
      jikan: _FakeProvider('jikan', fail: true),
      cache: cache,
    );

    final works = await service.feed(AnimeFeed.trending);
    expect(works.single.id, 'cached_1');
  });

  test('returns seed when all providers fail and no cache', () async {
    final service = _service(
      anilist: _FakeProvider('anilist', fail: true),
      jikan: _FakeProvider('jikan', fail: true),
      seedLoader: () async => [
        Work(id: 'seed_1', sourceId: 'seed', sourceName: 'Seed', type: WorkType.anime, title: 'Seed Anime'),
      ],
    );

    final works = await service.feed(AnimeFeed.trending);
    expect(works.single.id, 'seed_1');
  });
}
