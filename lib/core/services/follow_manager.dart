import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/follow_record.dart';
import '../models/work.dart';
import '../storage/database.dart';

class FollowManager {
  static const _key = 'follows';

  List<FollowRecord> _readAll() {
    final records = <FollowRecord>[];
    for (final raw in AppDatabase().getStringList(_key)) {
      try {
        records.add(
            FollowRecord.fromJson(json.decode(raw) as Map<String, dynamic>));
      } catch (_) {
        // Skip a malformed entry.
      }
    }
    return records;
  }

  Future<void> _save(List<FollowRecord> records) async {
    await AppDatabase().setStringList(
        _key, records.map((r) => json.encode(r.toJson())).toList());
  }

  List<FollowRecord> all() =>
      sortDescending(_readAll().where((r) => !r.deleted).toList());

  bool isFollowing(String workId) =>
      all().any((r) => r.work.id == workId);

  List<FollowRecord> dirty() => _readAll().where((r) => r.dirty).toList();

  Future<void> follow(Work work) async {
    final record = FollowRecord(work: work, updatedAt: DateTime.now(), dirty: true);
    await _save(upsert(_readAll(), record));
  }

  Future<void> unfollow(String workId) async {
    final records = _readAll();
    final existing = records.where((r) => r.work.id == workId).toList();
    if (existing.isEmpty) return;
    final tombstone = existing.first.copyWith(
        updatedAt: DateTime.now(), deleted: true, dirty: true);
    await _save(upsert(records, tombstone));
  }

  Future<void> markSynced(Set<String> workIds) async {
    final records = _readAll()
        .map((r) => workIds.contains(r.work.id) ? r.copyWith(dirty: false) : r)
        .toList();
    await _save(records);
  }

  Future<void> mergeFromServer(List<FollowRecord> server) async {
    await _save(merge(_readAll(), server));
  }

  @visibleForTesting
  static List<FollowRecord> upsert(
      List<FollowRecord> current, FollowRecord record) {
    final out = current.where((r) => r.work.id != record.work.id).toList();
    out.insert(0, record);
    return out;
  }

  @visibleForTesting
  static List<FollowRecord> sortDescending(List<FollowRecord> records) {
    final out = [...records];
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  /// LWW: a local record strictly newer than the server's is kept (still
  /// dirty); otherwise the server record wins with `dirty = false`.
  @visibleForTesting
  static List<FollowRecord> merge(
      List<FollowRecord> local, List<FollowRecord> server) {
    final byId = {for (final r in local) r.work.id: r};
    for (final item in server) {
      final existing = byId[item.work.id];
      if (existing != null && existing.updatedAt.isAfter(item.updatedAt)) {
        byId[item.work.id] = existing.copyWith(dirty: false);
      } else {
        byId[item.work.id] = item.copyWith(dirty: false);
      }
    }
    return byId.values.toList();
  }
}

class FollowNotifier extends Notifier<List<FollowRecord>> {
  final _manager = FollowManager();

  @override
  List<FollowRecord> build() => _manager.all();

  bool isFollowing(String workId) =>
      state.any((r) => r.work.id == workId);

  Future<void> toggle(Work work) async {
    if (isFollowing(work.id)) {
      await _manager.unfollow(work.id);
    } else {
      await _manager.follow(work);
    }
    state = _manager.all();
  }
}

final followProvider =
    NotifierProvider<FollowNotifier, List<FollowRecord>>(FollowNotifier.new);
