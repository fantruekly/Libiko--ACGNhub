import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/work.dart';
import '../core/services/recent_activity.dart';
import '../core/widgets/content_panel.dart';
import '../core/widgets/empty_state.dart';
import '../modules/anime/anime_detail_page.dart';
import '../modules/comic/comic_providers.dart';
import '../modules/comic/comic_reader_page.dart';
import '../modules/novel/novel_providers.dart';
import '../modules/novel/novel_reader_page.dart';

class RecentActivityPage extends ConsumerStatefulWidget {
  const RecentActivityPage({super.key});
  @override
  ConsumerState<RecentActivityPage> createState() => _RecentActivityPageState();
}

class _RecentActivityPageState extends ConsumerState<RecentActivityPage> {
  WorkType? _filter;
  String? _opening;

  Future<void> _continue(RecentActivity item) async {
    if (_opening != null) return;
    setState(() => _opening = item.id);
    try {
      final Widget target;
      if (item.watch case final record?) {
        target = AnimeDetailPage(
            work: record.work, resumeRecord: record, autoResume: true);
      } else if (item.comic case final record?) {
        final manager = ref.read(comicSourceManagerProvider);
        await ref.read(comicSourcesProvider.future);
        if (!manager.sources.any((source) => source.key == record.sourceKey)) {
          throw StateError('comic source unavailable');
        }
        target = ComicReaderPage(
            sourceKey: record.sourceKey,
            comicId: record.comicId,
            chapterId: record.chapterId,
            initialPage: record.page);
      } else if (item.novel case final record?) {
        if (ref.read(novelSourceManagerProvider).byId(record.sourceKey) ==
            null) {
          throw StateError('novel source unavailable');
        }
        target = NovelReaderPage(
            sourceKey: record.sourceKey,
            novelId: record.novelId,
            chapterId: record.chapterId,
            title: record.title,
            cover: record.cover);
      } else {
        return;
      }
      if (!mounted) return;
      await Navigator.push(
          context, MaterialPageRoute<void>(builder: (_) => target));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('暂时无法继续，请在源管理中检查原来源是否仍可用'),
        ));
      }
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final all = ref.watch(recentActivityProvider);
    final items =
        all.where((item) => _filter == null || item.type == _filter).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('最近观看与阅读')),
      body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
              width: 1040,
              child: Column(children: [
                SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    child: Row(children: [
                      for (final (type, label) in <(WorkType?, String)>[
                        (null, '全部'),
                        (WorkType.anime, '动漫'),
                        (WorkType.comic, '漫画'),
                        (WorkType.novel, '轻小说'),
                      ])
                        Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                                label: Text(label),
                                labelStyle: const TextStyle(
                                    fontFamily: 'NotoSansSC',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400),
                                selected: _filter == type,
                                onSelected: (_) =>
                                    setState(() => _filter = type))),
                    ])),
                Expanded(
                    child: items.isEmpty
                        ? const EmptyState(
                            icon: Icons.history_rounded,
                            message: '还没有记录，开始观看或阅读后会显示在这里')
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final icon = item.type == WorkType.anime
                                  ? Icons.live_tv_rounded
                                  : item.type == WorkType.comic
                                      ? Icons.menu_book_rounded
                                      : Icons.auto_stories_rounded;
                              return ContentPanel(
                                  child: ListTile(
                                key: ValueKey(item.id),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(9),
                                    child: SizedBox(
                                        width: 50,
                                        height: 72,
                                        child: item.cover == null ||
                                                item.cover!.isEmpty
                                            ? ColoredBox(
                                                color: cs.primaryContainer
                                                    .withValues(alpha: 0.5),
                                                child: Icon(icon,
                                                    color: cs.primary))
                                            : CachedNetworkImage(
                                                imageUrl: item.cover!,
                                                fit: BoxFit.cover,
                                                errorWidget: (_, __, ___) =>
                                                    ColoredBox(
                                                        color: cs
                                                            .surfaceContainerLow,
                                                        child: Icon(icon,
                                                            color:
                                                                cs.primary))))),
                                title: Text(
                                    item.title.isEmpty ? '未命名作品' : item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall),
                                subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(item.subtitle,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 4),
                                          Text(_dateLabel(item.updatedAt),
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                      color:
                                                          cs.onSurfaceVariant)),
                                        ])),
                                trailing: _opening == item.id
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : Icon(Icons.play_circle_outline_rounded,
                                        color: cs.primary),
                                onTap: _opening == null
                                    ? () => _continue(item)
                                    : null,
                              ));
                            })),
              ]))),
    );
  }

  String _dateLabel(DateTime date) {
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }
}
