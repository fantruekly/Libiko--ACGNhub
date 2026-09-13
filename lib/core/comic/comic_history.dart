import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/database.dart';

class ComicHistoryEntry {
  final String sourceKey;
  final String comicId;
  final String title;
  final String? cover;
  final String chapterId;
  final String chapterTitle;
  final int page;
  final DateTime readAt;

  const ComicHistoryEntry({
    required this.sourceKey,
    required this.comicId,
    required this.title,
    this.cover,
    required this.chapterId,
    required this.chapterTitle,
    required this.page,
    required this.readAt,
  });

  factory ComicHistoryEntry.fromJson(Map<String, dynamic> json) =>
      ComicHistoryEntry(
        sourceKey: json['sourceKey'] as String? ?? '',
        comicId: json['comicId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        cover: json['cover'] as String?,
        chapterId: json['chapterId'] as String? ?? '',
        chapterTitle: json['chapterTitle'] as String? ?? '',
        page: json['page'] as int? ?? 0,
        readAt: DateTime.fromMillisecondsSinceEpoch(json['readAt'] as int? ?? 0),
      );

  Map<String, dynamic> toJson() => {
        'sourceKey': sourceKey,
        'comicId': comicId,
        'title': title,
        'cover': cover,
        'chapterId': chapterId,
        'chapterTitle': chapterTitle,
        'page': page,
        'readAt': readAt.millisecondsSinceEpoch,
      };

  ComicHistoryEntry copyWith({
    String? chapterId,
    String? chapterTitle,
    int? page,
    DateTime? readAt,
  }) =>
      ComicHistoryEntry(
        sourceKey: sourceKey,
        comicId: comicId,
        title: title,
        cover: cover,
        chapterId: chapterId ?? this.chapterId,
        chapterTitle: chapterTitle ?? this.chapterTitle,
        page: page ?? this.page,
        readAt: readAt ?? this.readAt,
      );
}

class ComicHistoryManager {
  static const _key = 'comic_history';

  List<ComicHistoryEntry> all() {
    final entries = <ComicHistoryEntry>[];
    for (final raw in AppDatabase().getStringList(_key)) {
      try {
        entries.add(ComicHistoryEntry.fromJson(
            json.decode(raw) as Map<String, dynamic>));
      } catch (_) {
        // Skip a malformed entry.
      }
    }
    entries.sort((a, b) => b.readAt.compareTo(a.readAt));
    return entries;
  }

  ComicHistoryEntry? forComic(String sourceKey, String comicId) {
    for (final entry in all()) {
      if (entry.sourceKey == sourceKey && entry.comicId == comicId) {
        return entry;
      }
    }
    return null;
  }

  Future<void> record(ComicHistoryEntry entry) async {
    await _save(upsert(all(), entry));
  }

  Future<void> clear() => AppDatabase().remove(_key);

  Future<void> _save(List<ComicHistoryEntry> entries) async {
    await AppDatabase().setStringList(
        _key, entries.map((e) => json.encode(e.toJson())).toList());
  }

  @visibleForTesting
  static List<ComicHistoryEntry> upsert(
      List<ComicHistoryEntry> current, ComicHistoryEntry entry) {
    final out = current
        .where((e) =>
            !(e.sourceKey == entry.sourceKey && e.comicId == entry.comicId))
        .toList();
    out.insert(0, entry);
    return out;
  }
}

class ComicHistoryNotifier extends Notifier<List<ComicHistoryEntry>> {
  final _manager = ComicHistoryManager();

  @override
  List<ComicHistoryEntry> build() => _manager.all();

  Future<void> record(ComicHistoryEntry entry) async {
    await _manager.record(entry);
    state = _manager.all();
  }

  Future<void> clear() async {
    await _manager.clear();
    state = const [];
  }
}

final comicHistoryProvider =
    NotifierProvider<ComicHistoryNotifier, List<ComicHistoryEntry>>(
        ComicHistoryNotifier.new);
