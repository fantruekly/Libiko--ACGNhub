import 'resolve_result.dart';

/// In-memory LRU cache of resolved streams, keyed by the play-page URL.
/// Successes live longer than failures (negative cache) so a dead source is
/// not hammered.
class ResolvedStreamCache {
  ResolvedStreamCache({
    this.capacity = 64,
    this.ttlSuccess = const Duration(minutes: 15),
    this.ttlFailure = const Duration(seconds: 30),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final int capacity;
  final Duration ttlSuccess;
  final Duration ttlFailure;
  final DateTime Function() _now;
  final _entries = <String, _CacheEntry>{};

  ResolveResult? get(String playUrl) {
    final key = _key(playUrl);
    final entry = _entries.remove(key);
    if (entry == null) return null;
    final ttl = entry.result.ok ? ttlSuccess : ttlFailure;
    if (_now().difference(entry.at) >= ttl) return null;
    _entries[key] = entry; // refresh LRU position
    return entry.result;
  }

  void put(String playUrl, ResolveResult result) {
    final key = _key(playUrl);
    _entries.remove(key);
    _entries[key] = _CacheEntry(result, _now());
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
  }

  void invalidate(String playUrl) => _entries.remove(_key(playUrl));

  void clear() => _entries.clear();

  static String _key(String url) =>
      Uri.tryParse(url)?.replace(fragment: '').toString() ?? url.trim();
}

class _CacheEntry {
  _CacheEntry(this.result, this.at);
  final ResolveResult result;
  final DateTime at;
}

/// The app-wide cache shared by every [StreamResolver] instance.
final ResolvedStreamCache sharedStreamCache = ResolvedStreamCache();
