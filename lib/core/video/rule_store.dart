import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../storage/database.dart';
import 'source_rule.dart';

/// Loads built-in rules from `assets/source_rules/` and user-imported rules
/// from `<app support dir>/rules/`. Imported rules win on a name collision.
class RuleMetadata {
  const RuleMetadata({this.version, this.updatedAt, this.hasPrevious = false});
  final String? version;
  final DateTime? updatedAt;
  final bool hasPrevious;
}

class RuleStore {
  RuleStore(
      {Directory? directory, AssetBundle? bundle, DateTime Function()? clock})
      : _directory = directory,
        _bundle = bundle ?? rootBundle,
        _clock = clock ?? DateTime.now;
  static const _assetDir = 'assets/source_rules/';
  final Directory? _directory;
  final AssetBundle _bundle;
  final DateTime Function() _clock;
  Future<void> _pending = Future.value();
  int _serial = 0;
  final Map<String, RuleMetadata> _bundledMetadata = {};
  final Map<String, String> _bundledRaw = {};

  Future<T> _exclusive<T>(Future<T> Function() action) {
    final next = _pending.then((_) => action());
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  Future<List<SourceRule>> loadAll() async =>
      mergeRules(await loadBuiltIn(), await loadImported());

  Future<List<SourceRule>> loadBuiltIn() async {
    final rules = <SourceRule>[];
    final manifest = await AssetManifest.loadFromAssetBundle(_bundle);
    final files = manifest
        .listAssets()
        .where((k) => k.startsWith(_assetDir) && k.endsWith('.json'))
        .toList()
      ..sort();
    for (final file in files) {
      try {
        final raw = await _bundle.loadString(file);
        final rule = SourceRule.fromJsonString(raw);
        rules.add(rule);
        _bundledRaw[rule.name] = raw;
        _bundledMetadata[rule.name] = await _assetMetadata(rule.name, raw);
      } catch (e) {
        debugPrint('[RuleStore] bad built-in rule $file: $e');
      }
    }
    return rules;
  }

  Future<RuleMetadata> _assetMetadata(String name, String raw) async {
    final value = jsonDecode(raw) as Map;
    final rawVersion = value['version'];
    DateTime? updated;
    try {
      final db = AppDatabase();
      final key = 'source_rule_stamp.$name';
      final digest = sha256.convert(utf8.encode(raw)).toString();
      final stamp = db.getString(key)?.split('|');
      updated = stamp?.length == 2 && stamp![0] == digest
          ? DateTime.tryParse(stamp[1])
          : null;
      if (updated == null) {
        updated = _clock();
        await db.setString(key, '$digest|${updated.toIso8601String()}');
      }
    } on StateError {/* Asset-only tests need no application database. */}
    return RuleMetadata(
        version: rawVersion is String || rawVersion is num
            ? rawVersion.toString()
            : null,
        updatedAt: updated);
  }

  Future<Directory> _importDir() async {
    final dir = _directory ??
        Directory(
            p.join((await getApplicationSupportDirectory()).path, 'rules'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<List<File>> _files() async {
    final dir = await _importDir();
    return (await dir.list().toList())
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
  }

  Future<List<SourceRule>> loadImported() async {
    final rules = <SourceRule>[];
    for (final file in await _files()) {
      try {
        rules.add(SourceRule.fromJsonString(await file.readAsString()));
      } catch (e) {
        debugPrint('[RuleStore] bad imported rule ${file.path}: $e');
      }
    }
    return rules;
  }

  Future<File> _fileForName(String name) async {
    // Find legacy file names as well, and avoid overwriting another rule whose
    // sanitized name happens to collide with this one.
    for (final file in await _files()) {
      try {
        if (SourceRule.fromJsonString(await file.readAsString()).name == name) {
          return file;
        }
      } catch (_) {}
    }
    final dir = await _importDir();
    final encoded = sha256.convert(utf8.encode(name)).toString();
    return File(p.join(dir.path, '$encoded.json'));
  }

  Future<void> _atomicWrite(File target, String content) async {
    final temporary = File(
        '${target.path}.tmp.${_clock().microsecondsSinceEpoch}.${_serial++}');
    try {
      await temporary.writeAsString(content, flush: true);
      // Rename within the same directory, so readers see a complete file.
      await temporary.rename(target.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<SourceRule> _import(String rawJson) async {
    final rule = SourceRule.fromJsonString(rawJson);
    final file = await _fileForName(rule.name);
    if (await file.exists()) {
      final previous = await file.readAsString();
      // Validate before replacing a known-good rollback version.
      SourceRule.fromJsonString(previous);
      if (previous != rawJson) {
        await _atomicWrite(File('${file.path}.previous'), previous);
      }
    } else {
      // An imported override may replace a built-in rule on its very first
      // import. Preserve that effective version too, not just disk imports.
      if (!_bundledRaw.containsKey(rule.name)) {
        try {
          await loadBuiltIn();
        } catch (_) {}
      }
      final builtIn = _bundledRaw[rule.name];
      if (builtIn != null && builtIn != rawJson) {
        await _atomicWrite(File('${file.path}.previous'), builtIn);
      }
    }
    await _atomicWrite(file, rawJson);
    return rule;
  }

  /// Parses before touching disk and keeps the previous imported version.
  Future<SourceRule> importJson(String rawJson) {
    SourceRule.fromJsonString(rawJson);
    return _exclusive(() => _import(rawJson));
  }

  Future<RuleMetadata> metadata(String name) async {
    final file = await _fileForName(name);
    if (!await file.exists()) {
      return _bundledMetadata[name] ?? const RuleMetadata();
    }
    final json = jsonDecode(await file.readAsString()) as Map;
    final rawVersion = json['version'];
    return RuleMetadata(
        version: rawVersion is String || rawVersion is num
            ? rawVersion.toString()
            : null,
        updatedAt: (await file.stat()).modified,
        hasPrevious: await File('${file.path}.previous').exists());
  }

  Future<SourceRule> rollback(String name) => _exclusive(() async {
        final file = await _fileForName(name);
        final previous = File('${file.path}.previous');
        if (!await previous.exists()) throw StateError('没有可回退的上一版本');
        final raw = await previous.readAsString();
        final rule = SourceRule.fromJsonString(raw);
        if (rule.name != name) throw const FormatException('备份规则名称不匹配');
        return _import(raw);
      });

  Future<void> remove(String name) => _exclusive(() async {
        final file = await _fileForName(name);
        if (await file.exists()) await file.delete();
        final previous = File('${file.path}.previous');
        if (await previous.exists()) await previous.delete();
      });

  Future<List<Map<String, dynamic>>> exportImportedRules() async => [
        for (final file in await _files())
          Map<String, dynamic>.from(
              jsonDecode(await file.readAsString()) as Map),
      ];

  /// Merge an already reviewed backup; validate the whole payload first.
  Future<void> restoreImports(List<Map<String, dynamic>> rules) {
    final validated = [for (final rule in rules) jsonEncode(rule)];
    for (final raw in validated) {
      SourceRule.fromJsonString(raw);
    }
    return _exclusive(() async {
      for (final raw in validated) {
        await _import(raw);
      }
    });
  }

  static List<SourceRule> mergeRules(
      List<SourceRule> builtIn, List<SourceRule> imported) {
    final byName = <String, SourceRule>{};
    for (final r in builtIn) {
      byName[r.name] = r;
    }
    for (final r in imported) {
      byName[r.name] = r;
    }
    return byName.values.toList();
  }
}

final ruleStoreProvider = Provider<RuleStore>((ref) => RuleStore());
