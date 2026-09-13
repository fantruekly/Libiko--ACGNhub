import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/comic/comic_favorite.dart';
import '../../core/comic/comic_history.dart';
import '../../core/comic/models.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../core/widgets/window_controls.dart';
import 'comic_providers.dart';

const _accent = Color(0xFF007AFF);
const _muted = Color(0xFF8E8E93);

class ComicDetailPage extends ConsumerStatefulWidget {
  final String sourceKey;
  final String comicId;
  final String title;
  final String? cover;

  const ComicDetailPage({
    super.key,
    required this.sourceKey,
    required this.comicId,
    required this.title,
    this.cover,
  });

  @override
  ConsumerState<ComicDetailPage> createState() => _ComicDetailPageState();
}

class _ComicDetailPageState extends ConsumerState<ComicDetailPage> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Column(
        children: [
          _header(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _header() {
    final cs = Theme.of(context).colorScheme;
    return DragToMoveArea(
      child: Container(
        height: 48,
        padding: const EdgeInsets.only(left: 4),
        decoration: const BoxDecoration(
          color: Color(0xFFFFFFFF),
          border:
              Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
              splashRadius: 20,
            ),
            Expanded(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface),
              ),
            ),
            const WindowControls(),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final async =
        ref.watch(comicDetailProvider((widget.sourceKey, widget.comicId)));
    return async.when(
      loading: () => const ShimmerLoader(
        crossAxisCount: 6,
        itemCount: 12,
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
      ),
      error: (_, __) => EmptyState(
        icon: Icons.error_outline_rounded,
        message: '加载失败',
        actionLabel: '重试',
        onAction: () => ref
            .invalidate(comicDetailProvider((widget.sourceKey, widget.comicId))),
      ),
      data: (details) => _content(details),
    );
  }

  Widget _content(ComicDetails details) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _infoCard(details)),
        SliverToBoxAdapter(child: _chapterSection(details)),
        if (_historyEntry() != null)
          SliverToBoxAdapter(child: _continueReading()),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _infoCard(ComicDetails details) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: GlassSurface(
        blur: 0,
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(16),
        border: Border.all(color: const Color(0xFFE5E5EA)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, 6)),
        ],
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'comic_${widget.sourceKey}_${widget.comicId}',
              child: RepaintBoundary(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 110,
                    height: 154,
                    child:
                        details.cover != null && details.cover!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: details.cover!,
                                fit: BoxFit.cover,
                                memCacheWidth: 300,
                                errorWidget: (_, __, ___) =>
                                    _coverPlaceholder(cs),
                              )
                            : _coverPlaceholder(cs),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    details.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        height: 1.35),
                  ),
                  const SizedBox(height: 14),
                  _favoriteButton(details),
                  const SizedBox(height: 14),
                  if (details.tags.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final tag in details.tags) _tagChip(tag),
                      ],
                    ),
                  const SizedBox(height: 10),
                  _description(details.description, cs),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _favoriteButton(ComicDetails details) {
    final favorites = ref.watch(comicFavoritesProvider);
    final isFavorite = favorites.any((f) =>
        f.sourceKey == widget.sourceKey && f.comicId == widget.comicId);
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        backgroundColor:
            isFavorite ? const Color(0xFFE5E5EA) : const Color(0xFF007AFF),
        foregroundColor: isFavorite ? const Color(0xFF8E8E93) : Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () {
        ref.read(comicFavoritesProvider.notifier).toggle(ComicFavorite(
              sourceKey: widget.sourceKey,
              comicId: widget.comicId,
              title: details.title,
              cover: details.cover,
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

  Widget _tagChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: _accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: _accent)),
    );
  }

  Widget _description(String? description, ColorScheme cs) {
    if (description == null || description.isEmpty) {
      return Text('暂无简介',
          style: TextStyle(
              fontSize: 13, color: cs.onSurface.withValues(alpha: 0.35)));
    }
    final needsToggle = description.length > 60;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: needsToggle
              ? () => setState(() => _expanded = !_expanded)
              : null,
          child: Text(
            description,
            maxLines: _expanded ? null : 3,
            overflow: _expanded ? null : TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: cs.onSurface.withValues(alpha: 0.7)),
          ),
        ),
        if (needsToggle)
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _expanded ? '收起' : '展开',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _accent),
              ),
            ),
          ),
      ],
    );
  }

  Widget _chapterSection(ComicDetails details) {
    final cs = Theme.of(context).colorScheme;
    final chapters = details.chapters.entries.toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: GlassSurface(
        blur: 0,
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(16),
        border: Border.all(color: const Color(0xFFE5E5EA)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, 6)),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('章节',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface)),
                const SizedBox(width: 10),
                Text('共 ${chapters.length} 话',
                    style: const TextStyle(fontSize: 12, color: _muted)),
              ],
            ),
            const SizedBox(height: 12),
            if (chapters.isEmpty)
              Text('暂无章节',
                  style: TextStyle(
                      fontSize: 13, color: cs.onSurface.withValues(alpha: 0.4)))
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final chapter in chapters)
                    _chapterButton(chapter.value),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _chapterButton(String title) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showReaderPlaceholder(),
        borderRadius: BorderRadius.circular(10),
        hoverColor: const Color(0x1F007AFF),
        child: Container(
          width: 104,
          height: 44,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0x0F007AFF),
            border: Border.all(color: const Color(0x4D007AFF)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: _accent),
          ),
        ),
      ),
    );
  }

  Widget _continueReading() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            backgroundColor: _accent,
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => _showReaderPlaceholder(),
          icon: const Icon(Icons.menu_book_rounded, size: 18),
          label: const Text('继续阅读',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  ComicHistoryEntry? _historyEntry() {
    final entries = ref.watch(comicHistoryProvider);
    for (final entry in entries) {
      if (entry.sourceKey == widget.sourceKey &&
          entry.comicId == widget.comicId) {
        return entry;
      }
    }
    return null;
  }

  void _showReaderPlaceholder() {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('阅读器开发中')));
  }

  Widget _coverPlaceholder(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withValues(alpha: 0.1),
            cs.tertiary.withValues(alpha: 0.05)
          ],
        ),
      ),
      child: Center(
          child: Icon(Icons.image_outlined,
              size: 24, color: cs.primary.withValues(alpha: 0.2))),
    );
  }
}
