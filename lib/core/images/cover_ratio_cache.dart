import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the aspect ratio (`width / height`) of cover images so a card can
/// size itself before its image has loaded again. Persisted, so the masonry
/// layout does not jump on every rebuild or relaunch.
class CoverRatioCache {
  CoverRatioCache();

  static const _prefix = 'cover_ratio.';
  final Map<String, double> _memory = {};

  Future<double?> ratioOf(String url) async {
    if (url.isEmpty) return null;
    final cached = _memory[url];
    if (cached != null) return cached;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getDouble('$_prefix$url');
      if (stored != null && _isUsable(stored)) {
        _memory[url] = stored;
        return stored;
      }
    } catch (_) {}
    return null;
  }

  Future<void> remember(String url, double ratio) async {
    if (url.isEmpty || !_isUsable(ratio)) return;
    _memory[url] = ratio;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('$_prefix$url', ratio);
    } catch (_) {}
  }

  static bool _isUsable(double ratio) =>
      ratio.isFinite && ratio > 0;
}

/// Shared instance used by the card widgets.
final CoverRatioCache defaultCoverRatioCache = CoverRatioCache();
