import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/watch_record.dart';
import '../models/work.dart';
import '../storage/database.dart';
import '../video/video_source.dart';

class WatchHistoryManager {
  static const _key = 'watch_history';
  static const _kPendingClear = 'watch_history_pending_clear';
  static const _kClearAt = 'watch_history_clear_at';

  List<WatchRecord> _readAll() {
    final jsonList = AppDatabase().getStringList(_key);
    final records = <WatchRecord>[];
    for (final raw in jsonList) {
      try {
        records.add(
            WatchRecord.fromJson(json.decode(raw) as Map<String, dynamic>));
      } catch (_) {
        // Skip a malformed entry rather than failing the whole list.
      }
    }
    return records;
  }

  List<WatchRecord> all() =>
      sortDescending(_readAll().where((r) => !r.deleted).toList());

  List<WatchRecord> dirty() => _readAll().where((r) => r.dirty).toList();

  bool get pendingClear => AppDatabase().getBool(_kPendingClear) ?? false;

  int? get clearAt => AppDatabase().getInt(_kClearAt);

  Future<void> clearPendingClear() async {
    await AppDatabase().remove(_kPendingClear);
    await AppDatabase().remove(_kClearAt);
  }

  Future<void> _pending = Future.value();

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _pending.then((_) => action());
    _pending = next.catchError((_) {});
    return next;
  }

  Future<void> record(Work work, VideoEpisode episode) => _enqueue(() async {
        final now = DateTime.now();
        final record = WatchRecord(
          work: work,
          episodeTitle: episode.title,
          episodeIndex: episode.index,
          watchedAt: now,
          updatedAt: now,
          dirty: true,
        );
        await _save(upsert(_readAll(), record));
      });

  Future<void> clear() => _enqueue(() async {
        final now = DateTime.now();
        final tombstones = _readAll()
            .where((r) => !r.deleted)
            .map((r) => r.copyWith(
                deleted: true, dirty: true, updatedAt: now))
            .toList();
        for (final tombstone in tombstones) {
          await _save(upsert(_readAll(), tombstone));
        }
        await AppDatabase().setBool(_kPendingClear, true);
        await AppDatabase().setInt(_kClearAt, now.millisecondsSinceEpoch);
      });

  Future<void> markSynced(Map<String, DateTime> pushedUpdatedAt) =>
      _enqueue(() async {
        final records = _readAll().map((r) {
          final pushed = pushedUpdatedAt[r.work.id];
          return pushed != null && r.updatedAt == pushed
              ? r.copyWith(dirty: false)
              : r;
        }).toList();
        await _save(records);
      });

  Future<void> mergeFromServer(List<WatchRecord> server) =>
      _enqueue(() => _save(merge(_readAll(), server)));

  @visibleForTesting
  static List<WatchRecord> merge(
      List<WatchRecord> local, List<WatchRecord> server) {
    final byId = {for (final r in local) r.work.id: r};
    for (final item in server) {
      final existing = byId[item.work.id];
      if (existing != null && existing.updatedAt.isAfter(item.updatedAt)) {
        byId[item.work.id] = existing.copyWith();
      } else {
        byId[item.work.id] = item.copyWith(dirty: false);
      }
    }
    return byId.values.toList();
  }

  Future<void> _save(List<WatchRecord> records) async {
    final jsonList = records.map((r) => json.encode(r.toJson())).toList();
    await AppDatabase().setStringList(_key, jsonList);
  }

  @visibleForTesting
  static List<WatchRecord> upsert(
      List<WatchRecord> current, WatchRecord record) {
    final out = current.where((r) => r.work.id != record.work.id).toList();
    out.insert(0, record);
    return out;
  }

  @visibleForTesting
  static List<WatchRecord> sortDescending(List<WatchRecord> records) {
    final out = [...records];
    out.sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
    return out;
  }
}

class WatchHistoryNotifier extends Notifier<List<WatchRecord>> {
  final _manager = WatchHistoryManager();

  @override
  List<WatchRecord> build() => _manager.all();

  Future<void> record(Work work, VideoEpisode episode) async {
    await _manager.record(work, episode);
    state = _manager.all();
  }

  Future<void> clear() async {
    await _manager.clear();
    state = const [];
  }
}

final watchHistoryProvider =
    NotifierProvider<WatchHistoryNotifier, List<WatchRecord>>(
        WatchHistoryNotifier.new);
