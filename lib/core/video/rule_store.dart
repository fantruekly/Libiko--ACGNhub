import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'source_rule.dart';

/// Loads built-in rules from `assets/source_rules/` and user-imported rules
/// from `<app support dir>/rules/`. Imported rules win on a name collision.
class RuleStore {
  static const _assetDir = 'assets/source_rules/';
  static const _manifest = 'AssetManifest.json';

  Future<List<SourceRule>> loadAll() async {
    final builtIn = await loadBuiltIn();
    final imported = await loadImported();
    return mergeRules(builtIn, imported);
  }

  Future<List<SourceRule>> loadBuiltIn() async {
    final rules = <SourceRule>[];
    final manifestJson = await rootBundle.loadString(_manifest);
    final manifest = json.decode(manifestJson) as Map<String, dynamic>;
    final files = manifest.keys
        .where((k) => k.startsWith(_assetDir) && k.endsWith('.json'))
        .toList()
      ..sort();
    for (final file in files) {
      try {
        rules.add(SourceRule.fromJsonString(await rootBundle.loadString(file)));
      } catch (e) {
        debugPrint('[RuleStore] bad built-in rule $file: $e');
      }
    }
    return rules;
  }

  Future<Directory> _importDir() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'rules'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<List<SourceRule>> loadImported() async {
    final dir = await _importDir();
    final rules = <SourceRule>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        rules.add(SourceRule.fromJsonString(await entity.readAsString()));
      } catch (e) {
        debugPrint('[RuleStore] bad imported rule ${entity.path}: $e');
      }
    }
    return rules;
  }

  /// Parses [rawJson] (throws [FormatException] if invalid) and persists it.
  Future<SourceRule> importJson(String rawJson) async {
    final rule = SourceRule.fromJsonString(rawJson);
    final dir = await _importDir();
    final file = File(p.join(dir.path, '${_safeName(rule.name)}.json'));
    await file.writeAsString(rawJson);
    return rule;
  }

  /// Deletes the imported rule named [name], if present.
  Future<void> remove(String name) async {
    final dir = await _importDir();
    final file = File(p.join(dir.path, '${_safeName(name)}.json'));
    if (await file.exists()) await file.delete();
  }

  static String _safeName(String name) =>
      name.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');

  @visibleForTesting
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
