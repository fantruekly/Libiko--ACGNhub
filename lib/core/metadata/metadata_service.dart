import '../models/work.dart';
import 'anilist_provider.dart';
import 'jikan_provider.dart';
import 'metadata_provider.dart';

class MetadataService {
  final MetadataProvider anilist;
  final MetadataProvider jikan;
  final DateTime Function() _now;

  static const _disableDuration = Duration(minutes: 10);
  static const _cacheTtl = Duration(minutes: 5);

  DateTime? _anilistDisabledUntil;
  final Map<String, _CacheEntry> _cache = {};

  MetadataService({
    MetadataProvider? anilist,
    MetadataProvider? jikan,
    DateTime Function()? now,
  })  : anilist = anilist ?? AniListProvider(),
        jikan = jikan ?? JikanProvider(),
        _now = now ?? DateTime.now;

  Future<List<Work>> feed(AnimeFeed feed, {int page = 1}) =>
      _run('feed:${feed.name}:$page', (p) => p.feed(feed, page: page));

  Future<List<Work>> search(String keyword, {int page = 1}) =>
      _run('search:$keyword:$page', (p) => p.search(keyword, page: page));

  Future<Work> detail(Work work) =>
      _run('detail:${work.anilistId ?? work.malId ?? work.id}', (p) => p.detail(work));

  Future<T> _run<T>(String key, Future<T> Function(MetadataProvider) op) async {
    final cached = _cache[key];
    if (cached != null && _now().difference(cached.at) < _cacheTtl) {
      return cached.value as T;
    }

    final skipAniList =
        _anilistDisabledUntil != null && _now().isBefore(_anilistDisabledUntil!);
    final order = skipAniList ? [jikan, anilist] : [anilist, jikan];

    Object? lastError;
    for (final provider in order) {
      try {
        final result = await op(provider);
        if (provider == anilist) _anilistDisabledUntil = null;
        _cache[key] = _CacheEntry(_now(), result);
        return result;
      } catch (e) {
        lastError = e;
        if (provider == anilist) {
          _anilistDisabledUntil = _now().add(_disableDuration);
        }
      }
    }
    throw Exception('All metadata providers failed: $lastError');
  }
}

class _CacheEntry {
  final DateTime at;
  final Object? value;
  _CacheEntry(this.at, this.value);
}
