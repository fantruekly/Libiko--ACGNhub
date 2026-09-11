import 'package:shared_preferences/shared_preferences.dart';

/// Persists metadata responses so the app can show the last successful
/// result while the upstream APIs are unavailable.
abstract class MetadataCache {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class PrefsMetadataCache implements MetadataCache {
  static const _prefix = 'meta_cache:';

  Future<SharedPreferences>? _prefs;
  Future<SharedPreferences> get _instance => _prefs ??= SharedPreferences.getInstance();

  @override
  Future<String?> read(String key) async {
    final prefs = await _instance;
    return prefs.getString('$_prefix$key');
  }

  @override
  Future<void> write(String key, String value) async {
    final prefs = await _instance;
    await prefs.setString('$_prefix$key', value);
  }
}
