import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../storage/database.dart';

/// Installs the bundled comic sources into the writable source directory.
///
/// Files whose name appears in the bundled manifest are (re)written when the
/// manifest version changes; any other file in the directory is left untouched.
class BuiltinSourceInstaller {
  BuiltinSourceInstaller({
    Future<String> Function(String assetPath)? loadAsset,
    Future<Directory> Function()? directory,
    String? Function(String key)? readMarker,
    Future<void> Function(String key, String value)? writeMarker,
  })  : _loadAsset = loadAsset ?? rootBundle.loadString,
        _directory = directory ?? _defaultDirectory,
        _readMarker = readMarker ?? ((key) => AppDatabase().getString(key)),
        _writeMarker = writeMarker ??
            ((key, value) => AppDatabase().setString(key, value));

  static const markerKey = 'comic_source_builtin_version';
  static const _manifestPath = 'assets/comic_source/builtin/index.json';
  static const _assetPrefix = 'assets/comic_source/builtin/';

  final Future<String> Function(String assetPath) _loadAsset;
  final Future<Directory> Function() _directory;
  final String? Function(String key) _readMarker;
  final Future<void> Function(String key, String value) _writeMarker;

  static Future<Directory> _defaultDirectory() async {
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, 'comic_source'));
  }

  Future<void> install() async {
    final raw = await _loadAsset(_manifestPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('invalid builtin comic source manifest');
    }
    final version = decoded['version']?.toString() ?? '';
    final sources = decoded['sources'];
    if (version.isEmpty || sources is! List) {
      throw const FormatException('invalid builtin comic source manifest');
    }
    if (_readMarker(markerKey) == version) return;
    final dir = await _directory();
    if (!await dir.exists()) await dir.create(recursive: true);
    for (final entry in sources) {
      if (entry is! Map) continue;
      final fileName = entry['fileName']?.toString() ?? '';
      // Only a plain file name is accepted: no directories, no traversal.
      if (fileName.isEmpty || p.basename(fileName) != fileName) continue;
      final script = await _loadAsset('$_assetPrefix$fileName');
      await File(p.join(dir.path, fileName)).writeAsString(script);
    }
    await _writeMarker(markerKey, version);
  }
}
