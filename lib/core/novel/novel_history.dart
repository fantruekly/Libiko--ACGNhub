import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/database.dart';

class NovelHistoryEntry {
  final String sourceKey;
  final String novelId;
  final String title;
  final String? cover;
  final String chapterId;
  final String chapterTitle;
  final DateTime updatedAt;

  const NovelHistoryEntry({
    required this.sourceKey,
    required this.novelId,
    required this.title,
    this.cover,
    required this.chapterId,
    required this.chapterTitle,
    required this.updatedAt,
  });

  factory NovelHistoryEntry.fromJson(Map<String, dynamic> json) =>
      NovelHistoryEntry(
        sourceKey: json['sourceKey'] as String? ?? '',
        novelId: json['novelId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        cover: json['cover'] as String?,
        chapterId: json['chapterId'] as String? ?? '',
        chapterTitle: json['chapterTitle'] as String? ?? '',
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int? ?? 0),
      );

  Map<String, dynamic> toJson() => {
        'sourceKey': sourceKey,
        'novelId': novelId,
        'title': title,
        'cover': cover,
        'chapterId': chapterId,
        'chapterTitle': chapterTitle,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };
}

class NovelHistoryManager {
  static const _key = 'novel_history';

  List<NovelHistoryEntry> all() {
    final entries = <NovelHistoryEntry>[];
    for (final raw in AppDatabase().getStringList(_key)) {
      try {
        entries.add(NovelHistoryEntry.fromJson(
            json.decode(raw) as Map<String, dynamic>));
      } catch (_) {
        // Skip a malformed entry.
      }
    }
    entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return entries;
  }

  NovelHistoryEntry? forNovel(String sourceKey, String novelId) {
    for (final entry in all()) {
      if (entry.sourceKey == sourceKey && entry.novelId == novelId) {
        return entry;
      }
    }
    return null;
  }

  Future<void> _pending = Future.value();

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _pending.then((_) => action());
    _pending = next.catchError((_) {});
    return next;
  }

  Future<void> record(NovelHistoryEntry entry) => _enqueue(() async {
        await _save(upsert(all(), entry));
      });

  Future<void> clear() => _enqueue(() => AppDatabase().remove(_key));

  Future<void> _save(List<NovelHistoryEntry> entries) async {
    await AppDatabase().setStringList(
        _key, entries.map((e) => json.encode(e.toJson())).toList());
  }

  @visibleForTesting
  static List<NovelHistoryEntry> upsert(
      List<NovelHistoryEntry> current, NovelHistoryEntry entry) {
    final out = current
        .where((e) =>
            !(e.sourceKey == entry.sourceKey && e.novelId == entry.novelId))
        .toList();
    out.insert(0, entry);
    return out;
  }
}

class NovelHistoryNotifier extends Notifier<List<NovelHistoryEntry>> {
  final _manager = NovelHistoryManager();

  @override
  List<NovelHistoryEntry> build() => _manager.all();

  Future<void> record(NovelHistoryEntry entry) async {
    await _manager.record(entry);
    state = _manager.all();
  }

  Future<void> clear() async {
    await _manager.clear();
    state = const [];
  }
}

final novelHistoryProvider =
    NotifierProvider<NovelHistoryNotifier, List<NovelHistoryEntry>>(
        NovelHistoryNotifier.new);
