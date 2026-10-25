import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../comic/comic_history.dart';
import '../models/watch_record.dart';
import '../models/work.dart';
import '../novel/novel_history.dart';
import 'watch_history.dart';

class RecentActivity {
  const RecentActivity(
      {required this.type,
      required this.id,
      required this.title,
      required this.subtitle,
      required this.updatedAt,
      this.cover,
      this.watch,
      this.comic,
      this.novel});
  final WorkType type;
  final String id;
  final String title, subtitle;
  final String? cover;
  final DateTime updatedAt;
  final WatchRecord? watch;
  final ComicHistoryEntry? comic;
  final NovelHistoryEntry? novel;
}

List<RecentActivity> buildRecentActivity(List<WatchRecord> anime,
    List<ComicHistoryEntry> comics, List<NovelHistoryEntry> novels) {
  final entries = <RecentActivity>[
    for (final record in anime.where((r) => !r.deleted))
      RecentActivity(
          type: WorkType.anime,
          id: 'anime:${record.work.id}',
          title: record.work.title,
          cover: record.work.coverUrl,
          subtitle:
              '${record.episodeTitle} · ${record.completed ? "已看完" : "${record.positionMs ~/ 60000} 分钟"}',
          updatedAt: record.watchedAt,
          watch: record),
    for (final record in comics)
      RecentActivity(
          type: WorkType.comic,
          id: 'comic:${record.sourceKey}:${record.comicId}',
          title: record.title,
          cover: record.cover,
          subtitle: '${record.chapterTitle} · 第 ${record.page + 1} 页',
          updatedAt: record.readAt,
          comic: record),
    for (final record in novels)
      RecentActivity(
          type: WorkType.novel,
          id: 'novel:${record.sourceKey}:${record.novelId}',
          title: record.title,
          cover: record.cover,
          subtitle:
              '${record.chapterTitle} · ${(record.scrollFraction * 100).round()}%',
          updatedAt: record.updatedAt,
          novel: record),
  ];
  entries.sort((a, b) {
    final recent = b.updatedAt.compareTo(a.updatedAt);
    return recent != 0 ? recent : a.id.compareTo(b.id);
  });
  return entries;
}

final recentActivityProvider =
    Provider<List<RecentActivity>>((ref) => buildRecentActivity(
          ref.watch(watchHistoryProvider),
          ref.watch(comicHistoryProvider),
          ref.watch(novelHistoryProvider),
        ));
