import 'dart:convert';

import '../sources/source_preferences.dart';
import 'collection_store.dart';

class PersonalBackupPreview {
  const PersonalBackupPreview(
      {required this.collections,
      required this.createdAt,
      required this.records,
      this.sources});
  final Map<String, dynamic> collections;
  final DateTime createdAt;
  final int records;
  final SourcePreferences? sources;
}

/// Only an explicit allowlist of personal collections and source preferences is
/// exported. Account tokens, source login data and executable scripts stay out.
class PersonalBackupService {
  PersonalBackupService(
      {required this.store,
      required this.readSources,
      required this.writeSources,
      DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;
  final CollectionStore store;
  final SourcePreferences Function() readSources;
  final Future<void> Function(SourcePreferences) writeSources;
  final DateTime Function() _clock;
  static const maxBytes = 20 * 1024 * 1024;

  String exportText() => const JsonEncoder.withIndent('  ').convert({
        'application': 'libiko',
        'version': 1,
        'createdAt': _clock().toUtc().toIso8601String(),
        'personal': store.exportSnapshot(),
        'sources': readSources().toJson(),
      });

  PersonalBackupPreview preview(String text) {
    if (utf8.encode(text).length > maxBytes) {
      throw const FormatException('备份文件超过 20 MB');
    }
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic> ||
        decoded['application'] != 'libiko' ||
        decoded['version'] != 1 ||
        decoded['personal'] is! Map<String, dynamic>) {
      throw const FormatException('不是受支持的 Libiko 备份');
    }
    final createdAt = DateTime.tryParse(decoded['createdAt']?.toString() ?? '');
    if (createdAt == null) throw const FormatException('备份时间格式无效');
    final personal = decoded['personal'] as Map<String, dynamic>;
    final validator = CollectionStore.memory();
    try {
      validator.restoreSnapshot(personal);
    } finally {
      validator.dispose();
    }
    final rawSources = decoded['sources'];
    if (rawSources != null && rawSources is! Map<String, dynamic>) {
      throw const FormatException('源设置格式无效');
    }
    final sources = rawSources == null
        ? null
        : SourcePreferences.fromJson(rawSources as Map<String, dynamic>);
    final records = (personal['collections'] as Map<String, dynamic>)
        .values
        .fold<int>(0, (count, value) => count + (value as List).length);
    return PersonalBackupPreview(
        collections: personal,
        createdAt: createdAt,
        records: records,
        sources: sources);
  }

  Future<RestoreReport> restore(PersonalBackupPreview backup,
      {bool restoreSources = true}) async {
    // Validate again: callers may hold a preview while the application changes.
    final validator = CollectionStore.memory();
    try {
      validator.restoreSnapshot(backup.collections);
    } finally {
      validator.dispose();
    }
    final previous = readSources();
    final updateSources = restoreSources && backup.sources != null;
    try {
      if (updateSources) await writeSources(backup.sources!);
      // Synchronous transaction comes last, so no in-flight async preference
      // write can require overwriting concurrently changed personal records.
      return store.restoreSnapshot(backup.collections);
    } catch (_) {
      if (updateSources) await writeSources(previous);
      rethrow;
    }
  }
}
