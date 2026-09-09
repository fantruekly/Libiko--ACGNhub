import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/source/source_manager.dart';
import '../../core/models/work.dart';
import 'anime_source.dart';
import 'anime_rule.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

final sourceManagerProvider = Provider<SourceManager>((ref) {
  return SourceManager();
});

final animeSourceListProvider = FutureProvider<List<AnimeSource>>((ref) async {
  final manager = ref.read(sourceManagerProvider);

  // Load built-in rules
  final manifest = await rootBundle.loadString('AssetManifest.json');
  final ruleFiles = <String>[];
  if (manifest.contains('assets/rules/')) {
    final lines = manifest.split('\n');
    for (final line in lines) {
      if (line.contains('assets/rules/') && line.contains('.json')) {
        final key = line.split('"')[1];
        if (key != null) ruleFiles.add(key);
      }
    }
  }

  // Load default rule if no files found in manifest
  for (final file in ruleFiles) {
    final jsonString = await rootBundle.loadString(file);
    final rule = AnimeRule.fromJsonString(jsonString);
    final source = AnimeSource(rule);
    manager.register(source);
  }

  return manager.getByType(WorkType.anime).cast<AnimeSource>();
});