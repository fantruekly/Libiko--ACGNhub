import 'video_source.dart';

/// Caches a source's search and episode lists by (source id, query) so
/// re-opening a work or re-expanding a source is instant. Entries expire after
/// [ttl] and the cache is LRU-bounded by [capacity].
class SourceCache {
  SourceCache({
    this.capacity = 256,
    this.ttl = const Duration(minutes: 10),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final int capacity;
  final Duration ttl;
  final DateTime Function() _now;
  final _entries = <String, _Entry>{};

  List<VideoItem>? search(String sourceId, String keyword) {
    final value = _get('s|$sourceId|$keyword');
    return value is List<VideoItem> ? value : null;
  }

  void putSearch(String sourceId, String keyword, List<VideoItem> items) =>
      _put('s|$sourceId|$keyword', items);

  List<VideoEpisode>? episodes(String sourceId, String detailUrl) {
    final value = _get('e|$sourceId|$detailUrl');
    return value is List<VideoEpisode> ? value : null;
  }

  void putEpisodes(
          String sourceId, String detailUrl, List<VideoEpisode> episodes) =>
      _put('e|$sourceId|$detailUrl', episodes);

  void clear() => _entries.clear();

  Object? _get(String key) {
    final entry = _entries.remove(key);
    if (entry == null) return null;
    if (_now().difference(entry.at) >= ttl) return null;
    _entries[key] = entry; // refresh LRU position
    return entry.value;
  }

  void _put(String key, Object value) {
    _entries.remove(key);
    _entries[key] = _Entry(value, _now());
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
  }
}

class _Entry {
  _Entry(this.value, this.at);
  final Object value;
  final DateTime at;
}

/// The app-wide source cache shared by every rule source.
final SourceCache sharedSourceCache = SourceCache();
