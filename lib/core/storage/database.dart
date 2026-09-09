import 'package:shared_preferences/shared_preferences.dart';

class AppDatabase {
  static AppDatabase? _instance;
  late final SharedPreferences _prefs;

  AppDatabase._();

  static Future<AppDatabase> init() async {
    if (_instance != null) return _instance!;
    _instance = AppDatabase._();
    _instance!._prefs = await SharedPreferences.getInstance();
    return _instance!;
  }

  factory AppDatabase() {
    if (_instance == null) {
      throw StateError('AppDatabase not initialized. Call AppDatabase.init() first.');
    }
    return _instance!;
  }

  String? getString(String key) => _prefs.getString(key);
  Future<bool> setString(String key, String value) => _prefs.setString(key, value);

  bool? getBool(String key) => _prefs.getBool(key);
  Future<bool> setBool(String key, bool value) => _prefs.setBool(key, value);

  int? getInt(String key) => _prefs.getInt(key);
  Future<bool> setInt(String key, int value) => _prefs.setInt(key, value);

  List<String> getStringList(String key) => _prefs.getStringList(key) ?? [];
  Future<bool> setStringList(String key, List<String> value) => _prefs.setStringList(key, value);

  Future<bool> remove(String key) => _prefs.remove(key);
}