import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/watch_record.dart';
import '../models/work.dart';
import '../storage/database.dart';
import '../video/video_source.dart';

class WatchHistoryManager {
  static const _key = 'watch_history';

  List<WatchRecord> all() {
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
    return sortDescending(records);
  }

  Future<void> record(Work work, VideoEpisode episode) async {
    final record = WatchRecord(
      work: work,
      episodeTitle: episode.title,
      episodeIndex: episode.index,
      watchedAt: DateTime.now(),
    );
    await _save(upsert(all(), record));
  }

  Future<void> clear() => AppDatabase().remove(_key);

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
