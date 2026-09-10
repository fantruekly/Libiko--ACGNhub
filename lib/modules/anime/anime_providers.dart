import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../core/metadata/metadata_provider.dart';
import '../../core/metadata/metadata_service.dart';
import '../../core/source/source_manager.dart';
import '../../core/models/work.dart';
import 'anime_source.dart';
import 'anime_rule.dart';

final sourceManagerProvider = Provider<SourceManager>((ref) {
  return SourceManager();
});

final animeSourceListProvider = FutureProvider<List<AnimeSource>>((ref) async {
  final manager = ref.read(sourceManagerProvider);
  final manifestJson = await rootBundle.loadString('AssetManifest.json');
  final manifest = json.decode(manifestJson) as Map<String, dynamic>;
  final ruleFiles = manifest.keys.where((k) => k.startsWith('assets/rules/') && k.endsWith('.json')).toList();
  for (final file in ruleFiles) {
    final jsonString = await rootBundle.loadString(file);
    final rule = AnimeRule.fromJsonString(jsonString);
    manager.register(AnimeSource(rule));
  }
  return manager.getByType(WorkType.anime).cast<AnimeSource>();
});

final metadataServiceProvider = Provider<MetadataService>((ref) => MetadataService());

final animeFeedProvider = FutureProvider.family<List<Work>, AnimeFeed>((ref, feed) {
  return ref.watch(metadataServiceProvider).feed(feed);
});
