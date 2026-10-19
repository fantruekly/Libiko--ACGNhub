import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'collection_store.dart';

export 'collection_store.dart';

class AppDatabase {
  static AppDatabase? _instance;
  final SharedPreferences _prefs;
  final CollectionStore collections;

  AppDatabase._(this._prefs, this.collections);

  static Future<AppDatabase> init(
      {CollectionStore? collections, String? databasePath}) async {
    final testing = Platform.environment['FLUTTER_TEST'] == 'true';
    if (_instance != null &&
        collections == null &&
        databasePath == null &&
        !testing) {
      return _instance!;
    }
    final prefs = await SharedPreferences.getInstance();
    if (!testing && Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }
    final CollectionStore store;
    if (collections != null) {
      store = collections;
    } else if (testing && databasePath == null) {
      // Widget/unit tests retain their existing SharedPreferences mock setup and
      // never invoke a path-provider platform channel or touch a user's DB.
      store = CollectionStore.memory();
    } else {
      final location = databasePath ??
          path.join(
              (await getApplicationSupportDirectory()).path, 'personal.sqlite');
      Directory(path.dirname(location)).createSync(recursive: true);
      store = CollectionStore.open(location);
    }
    try {
      final legacy = <String, List<String>>{};
      for (final key in personalCollections) {
        final value = prefs.get(key);
        if (value is List) legacy[key] = value.whereType<String>().toList();
      }
      store.migrateLegacy(legacy);
    } catch (_) {
      if (collections == null) store.dispose();
      rethrow;
    }
    final previous = _instance;
    _instance = AppDatabase._(prefs, store);
    if (previous != null && !identical(previous.collections, store)) {
      previous.collections.dispose();
    }
    return _instance!;
  }

  factory AppDatabase() {
    if (_instance == null) {
      throw StateError(
          'AppDatabase not initialized. Call AppDatabase.init() first.');
    }
    return _instance!;
  }

  String? getString(String key) => _prefs.getString(key);
  Future<bool> setString(String key, String value) =>
      _prefs.setString(key, value);

  bool? getBool(String key) => _prefs.getBool(key);
  Future<bool> setBool(String key, bool value) => _prefs.setBool(key, value);

  int? getInt(String key) => _prefs.getInt(key);
  Future<bool> setInt(String key, int value) => _prefs.setInt(key, value);

  List<String> getStringList(String key) => personalCollections.contains(key)
      ? collections.all(key).map(jsonEncode).toList()
      : _prefs.getStringList(key) ?? [];
  Future<bool> setStringList(String key, List<String> value) async {
    if (!personalCollections.contains(key)) {
      return _prefs.setStringList(key, value);
    }
    collections.replace(key,
        value.map((raw) => jsonDecode(raw) as Map<String, dynamic>).toList());
    return true;
  }

  Future<bool> remove(String key) async {
    if (!personalCollections.contains(key)) return _prefs.remove(key);
    collections.clear(key);
    return true;
  }
}
