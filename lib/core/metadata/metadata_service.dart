import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import '../models/anime_extra.dart';
import '../models/work.dart';
import 'anilist_provider.dart';
import 'bangumi_provider.dart';
import 'jikan_provider.dart';
import 'metadata_cache.dart';
import 'metadata_provider.dart';

typedef MetadataSeedLoader = Future<List<Work>> Function();

class MetadataService {
  final MetadataProvider bangumi;
  final MetadataProvider anilist;
  final MetadataProvider jikan;
  final DateTime Function() _now;
  final MetadataCache? cache;
  final MetadataSeedLoader? seedLoader;

  static const _disableDuration = Duration(minutes: 1);
  static const _cacheTtl = Duration(minutes: 5);
  static const _maxAttempts = 4;

  final Map<String, DateTime> _disabledUntil = {};

  List<MetadataProvider> get _providers => [bangumi, anilist, jikan];
  final Map<String, _CacheEntry> _cache = {};
  List<Work>? _seed;

  Future<void> _jikanChain = Future<void>.value();
  final Map<String, Duration> _intervals;
  final Map<String, DateTime> _lastRequest = {};

  MetadataService({
    MetadataProvider? bangumi,
    MetadataProvider? anilist,
    MetadataProvider? jikan,
    DateTime Function()? now,
    MetadataCache? cache,
    MetadataSeedLoader? seedLoader,
    Map<String, Duration>? intervals,
  })  : bangumi = bangumi ?? BangumiProvider(),
        anilist = anilist ?? AniListProvider(),
        jikan = jikan ?? JikanProvider(),
        _now = now ?? DateTime.now,
        cache = cache ?? PrefsMetadataCache(),
        seedLoader = seedLoader ?? _defaultSeedLoader,
        _intervals = intervals ??
            const {
              'bangumi': Duration(milliseconds: 300),
              'anilist': Duration(milliseconds: 1000),
              'jikan': Duration(milliseconds: 350),
            };

  Future<T> _serializeJikan<T>(Future<T> Function() task) {
    final result = _jikanChain.then((_) => task());
    _jikanChain = result.then((_) {}, onError: (_) {});
    return result;
  }

  void invalidate(String prefix) {
    _cache.removeWhere((key, _) => key.startsWith(prefix));
  }

  Future<List<Work>> feed(AnimeFeed feed, {int page = 1}) async {
    final key = 'feed:${feed.name}:$page';
    try {
      final works = await _run(key, (p) => p.feed(feed, page: page));
      _persistList(key, works);
      return works;
    } catch (_) {
      final cached = await _readList(key);
      if (cached != null && cached.isNotEmpty) return cached;
      if (page == 1) {
        final seed = await _loadSeed();
        if (seed.isNotEmpty) return seed;
      }
      rethrow;
    }
  }

  Future<List<Work>> search(String keyword, {int page = 1}) async {
    final key = 'search:$keyword:$page';
    try {
      final works = await _run(key, (p) => p.search(keyword, page: page));
      _persistList(key, works);
      return works;
    } catch (_) {
      final cached = await _readList(key);
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<Work> detail(Work work) async {
    final key = 'detail:${work.anilistId ?? work.malId ?? work.id}';
    try {
      final enriched = await _run(key, (p) => p.detail(work));
      _persistWork(key, enriched);
      return enriched;
    } catch (_) {
      final cached = await _readWork(key);
      return cached ?? work;
    }
  }

  Future<List<AnimeCharacter>> characters(Work work) async {
    final id = work.bangumiId;
    final provider = bangumi;
    if (id == null || provider is! BangumiProvider) return const [];
    try {
      return await _withRetry(() => provider.characters(id));
    } catch (_) {
      return const [];
    }
  }

  Future<List<RelatedWork>> related(Work work) async {
    final id = work.bangumiId;
    final provider = bangumi;
    if (id == null || provider is! BangumiProvider) return const [];
    try {
      return await _withRetry(() => provider.related(id));
    } catch (_) {
      return const [];
    }
  }

  Future<T> _run<T>(String key, Future<T> Function(MetadataProvider) op) async {
    final cached = _cache[key];
    if (cached != null && _now().difference(cached.at) < _cacheTtl) {
      return cached.value as T;
    }

    var order = _providers.where((p) {
      final until = _disabledUntil[p.id];
      return until == null || !_now().isBefore(until);
    }).toList();
    if (order.isEmpty) order = List.of(_providers);

    Object? lastError;
    for (final provider in order) {
      try {
        final result = provider == jikan
            ? await _serializeJikan(
                () => _withRetry(() => _call(provider, () => op(provider))))
            : await _withRetry(() => _call(provider, () => op(provider)));
        _disabledUntil.remove(provider.id);
        _cache[key] = _CacheEntry(_now(), result);
        return result;
      } catch (e) {
        lastError = e;
        if (_isTransient(e)) {
          _disabledUntil[provider.id] = _now().add(_disableDuration);
        }
      }
    }
    throw Exception('All metadata providers failed: $lastError');
  }

  Future<T> _withRetry<T>(Future<T> Function() op) async {
    for (var attempt = 1;; attempt++) {
      try {
        return await op();
      } catch (e) {
        if (attempt >= _maxAttempts || !_isTransient(e)) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
  }

  Future<T> _call<T>(MetadataProvider provider, Future<T> Function() op) async {
    final interval = _intervals[provider.id];
    if (interval != null && interval > Duration.zero) {
      final last = _lastRequest[provider.id];
      if (last != null) {
        final elapsed = DateTime.now().difference(last);
        if (elapsed < interval) {
          await Future<void>.delayed(interval - elapsed);
        }
      }
      _lastRequest[provider.id] = DateTime.now();
    }
    return op();
  }

  bool _isTransient(Object e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      if (status != null) return status >= 500 || status == 429;
      return e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError;
    }
    return false;
  }

  void _persistList(String key, List<Work> works) {
    _persist(key, jsonEncode(works.map((w) => w.toJson()).toList()));
  }

  void _persistWork(String key, Work work) {
    _persist(key, jsonEncode(work.toJson()));
  }

  void _persist(String key, String json) {
    final store = cache;
    if (store == null) return;
    unawaited(() async {
      try {
        await store.write(key, json);
      } catch (_) {}
    }());
  }

  Future<List<Work>?> _readList(String key) async {
    final raw = await _readRaw(key);
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Work.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<Work?> _readWork(String key) async {
    final raw = await _readRaw(key);
    if (raw == null) return null;
    try {
      return Work.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _readRaw(String key) async {
    final store = cache;
    if (store == null) return null;
    try {
      return await store.read(key);
    } catch (_) {
      return null;
    }
  }

  Future<List<Work>> _loadSeed() async {
    if (_seed != null) return _seed!;
    final loader = seedLoader;
    if (loader == null) return const [];
    try {
      _seed = await loader();
    } catch (_) {
      _seed = const [];
    }
    return _seed!;
  }

  static Future<List<Work>> _defaultSeedLoader() async {
    final raw = await rootBundle.loadString('assets/anime_seed.json');
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Work.fromJson(e as Map<String, dynamic>)).toList();
  }
}

class _CacheEntry {
  final DateTime at;
  final Object? value;
  _CacheEntry(this.at, this.value);
}
