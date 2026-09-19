import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/novel/linovelib_source.dart';
import '../../core/novel/models.dart';
import '../../core/novel/novel_favorite.dart';
import '../../core/novel/novel_history.dart';
import '../../core/platform.dart';
import '../../core/services/cache_manager.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/button_grid.dart';
import '../../core/widgets/desktop_drag_area.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/pill_button.dart';
import '../../core/widgets/smooth_route.dart';
import '../../core/widgets/window_controls.dart';
import 'novel_providers.dart';
import 'novel_reader_page.dart';

class NovelDetailPage extends ConsumerStatefulWidget {
  final String sourceKey;
  final String novelId;
  final String title;
  final String? cover;
  const NovelDetailPage({
    super.key,
    required this.sourceKey,
    required this.novelId,
    required this.title,
    this.cover,
  });

  @override
  ConsumerState<NovelDetailPage> createState() => _NovelDetailPageState();
}

class _NovelDetailPageState extends ConsumerState<NovelDetailPage> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final key = (widget.sourceKey, widget.novelId);
    final async = ref.watch(novelDetailProvider(key));
    return Scaffold(
      backgroundColor: kAppBackground,
      body: Column(
        children: [
          _header(),
          Expanded(
            child: async.when(
              loading: () => _loading(),
              error: (_, __) => EmptyState(
                icon: Icons.cloud_off_rounded,
                message: '加载失败',
                actionLabel: '重试',
                onAction: () => ref.invalidate(novelDetailProvider(key)),
              ),
              data: (detail) => _content(detail),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loading() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _infoCard(
          Novel(
              id: widget.novelId, title: widget.title, coverUrl: widget.cover),
          widget.cover,
        ),
        const SizedBox(height: 24),
        const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _header() {
    final cs = Theme.of(context).colorScheme;
    final topInset = isDesktop ? 0.0 : MediaQuery.of(context).padding.top;
    return DesktopDragArea(
      child: Container(
        height: 48 + topInset,
        padding: EdgeInsets.only(left: 4, top: topInset),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          border:
              Border(bottom: BorderSide(color: cs.outlineVariant, width: 0.5)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              color: cs.onSurface,
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurface),
              ),
            ),
            if (isDesktop) const WindowControls(),
          ],
        ),
      ),
    );
  }

  Widget _content(NovelDetail detail) {
    final cs = Theme.of(context).colorScheme;
    final novel = detail.novel;
    final cover = (novel.coverUrl?.isNotEmpty ?? false)
        ? novel.coverUrl
        : ((widget.cover?.isNotEmpty ?? false) ? widget.cover : null);
    final history = _historyEntry();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _infoCard(novel, cover),
        if (history != null) ...[
          const SizedBox(height: 12),
          _continueReading(history, cover),
        ],
        const SizedBox(height: 16),
        if (detail.volumes.isEmpty)
          const SizedBox(
            height: 200,
            child: EmptyState(
                icon: Icons.menu_book_rounded, message: '暂无章节'),
          )
        else
          for (final vol in detail.volumes) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Text(vol.title,
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface)),
            ),
            TwoColumnButtonGrid(
              children: [
                for (final ch in vol.chapters)
                  PillButton(label: ch.title, onTap: () => _openChapter(ch, cover)),
              ],
            ),
          ],
      ],
    );
  }

  Widget _infoCard(Novel novel, String? cover) {
    final cs = Theme.of(context).colorScheme;
    final summary = novel.summary ?? '';
    final status = novel.extra['status']?.toString();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'novel_${widget.sourceKey}_${widget.novelId}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 100,
                    height: 132,
                    child: cover != null
                        ? CachedNetworkImage(
                            imageUrl: cover,
                            fit: BoxFit.cover,
                            httpHeaders: novelImageHeaders,
                            cacheManager: AppCacheManager(),
                            placeholder: (_, __) => _coverPlaceholder(),
                            errorWidget: (_, __, ___) => _coverPlaceholder(),
                          )
                        : _coverPlaceholder(),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(novel.title,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface)),
                    const SizedBox(height: 6),
                    if (novel.author != null && novel.author!.isNotEmpty)
                      Text(novel.author!,
                          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (status != null && status.isNotEmpty) _tag(status),
                        for (final t in novel.tags) _tag(t),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 14),
            LayoutBuilder(builder: (context, constraints) {
              final style = TextStyle(fontSize: 13, height: 1.5, color: cs.onSurface);
              final overflows = _summaryOverflows(
                  summary, style, constraints.maxWidth,
                  MediaQuery.textScalerOf(context));
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(summary,
                      maxLines: _expanded ? null : 3,
                      overflow: _expanded ? null : TextOverflow.ellipsis,
                      style: style),
                  if (overflows)
                    GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(_expanded ? '收起' : '展开',
                            style: TextStyle(fontSize: 13, color: cs.primary)),
                      ),
                    ),
                ],
              );
            }),
          ],
          const SizedBox(height: 14),
          _favoriteButton(novel, cover),
        ],
      ),
    );
  }

  Widget _favoriteButton(Novel novel, String? cover) {
    final favorites = ref.watch(novelFavoritesProvider);
    final isFavorite = favorites.any((f) =>
        f.sourceKey == widget.sourceKey && f.novelId == widget.novelId);
    final cs = Theme.of(context).colorScheme;
    return FilledButton.icon(
      style: isFavorite
          ? FilledButton.styleFrom(
              backgroundColor: cs.surfaceContainerHighest,
              foregroundColor: cs.onSurfaceVariant,
            )
          : null,
      onPressed: () {
        ref.read(novelFavoritesProvider.notifier).toggle(NovelFavorite(
              sourceKey: widget.sourceKey,
              novelId: widget.novelId,
              title: novel.title,
              cover: cover,
              addedAt: DateTime.now(),
            ));
      },
      icon: Icon(
          isFavorite
              ? Icons.bookmark_added_rounded
              : Icons.bookmark_add_outlined,
          size: 16),
      label: Text(isFavorite ? '已收藏' : '收藏',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }

  Widget _continueReading(NovelHistoryEntry entry, String? cover) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => Navigator.push(
          context,
          smoothRoute(NovelReaderPage(
            sourceKey: widget.sourceKey,
            novelId: widget.novelId,
            chapterId: entry.chapterId,
            title: widget.title,
            cover: cover,
          )),
        ),
        icon: const Icon(Icons.menu_book_rounded, size: 18),
        label: const Text('继续阅读',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }

  NovelHistoryEntry? _historyEntry() {
    final entries = ref.watch(novelHistoryProvider);
    for (final entry in entries) {
      if (entry.sourceKey == widget.sourceKey &&
          entry.novelId == widget.novelId) {
        return entry;
      }
    }
    return null;
  }

  Widget _coverPlaceholder() => Container(color: const Color(0xFFE8EAF6));

  bool _summaryOverflows(
      String text, TextStyle style, double maxWidth, TextScaler textScaler) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 3,
      textScaler: textScaler,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    final overflows = tp.didExceedMaxLines;
    tp.dispose();
    return overflows;
  }

  Widget _tag(String text) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: cs.secondaryContainer,
          borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              color: cs.onSecondaryContainer,
              fontWeight: FontWeight.w500)),
    );
  }

  void _openChapter(NovelChapterRef chapter, String? cover) {
    Navigator.push(
      context,
      smoothRoute(NovelReaderPage(
        sourceKey: widget.sourceKey,
        novelId: widget.novelId,
        chapterId: chapter.id,
        title: widget.title,
        cover: cover,
      )),
    );
  }
}
