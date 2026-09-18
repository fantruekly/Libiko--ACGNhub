import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/comic/comic_favorite.dart';
import '../../core/comic/comic_history.dart';
import '../../core/comic/comic_source.dart';
import '../../core/comic/models.dart';
import '../../core/platform.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/button_grid.dart';
import '../../core/widgets/desktop_drag_area.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/widgets/pill_button.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../core/widgets/smooth_route.dart';
import '../../core/widgets/window_controls.dart';
import 'comic_account_dialog.dart';
import 'comic_providers.dart';
import 'comic_reader_page.dart';

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
      backgroundColor: kAppBackground,
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
            if (isDesktop) const WindowControls(),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final async =
        ref.watch(comicDetailProvider((widget.sourceKey, widget.comicId)));
    final source = ref
        .watch(comicSourcesProvider)
        .valueOrNull
        ?.where((s) => s.key == widget.sourceKey)
        .firstOrNull;
    final needsLogin =
        source != null && (source.hasLogin || source.hasCookieLogin);
    final logged = !needsLogin ||
        (ref.watch(comicLoginProvider(widget.sourceKey)).valueOrNull ?? false);
    return async.when(
      loading: () => const ShimmerLoader(
        crossAxisCount: 6,
        itemCount: 12,
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
      ),
      error: (_, __) => (needsLogin && !logged)
          ? _loginRequired(source)
          : EmptyState(
              icon: Icons.error_outline_rounded,
              message: '加载失败',
              actionLabel: '重试',
              onAction: () => ref.invalidate(
                  comicDetailProvider((widget.sourceKey, widget.comicId))),
            ),
      data: (details) => (needsLogin && !logged && _looksEmpty(details))
          ? _loginRequired(source)
          : _content(details),
    );
  }

  /// True when a detail load produced no usable content (the other way a
  /// login-required source can "fail" without throwing).
  bool _looksEmpty(ComicDetails details) =>
      details.title.trim().isEmpty && details.chapters.isEmpty;

  Widget _loginRequired(ComicSource source) {
    return EmptyState(
      icon: Icons.lock_outline_rounded,
      message: '该源需要登录',
      actionLabel: '去登录',
      onAction: () async {
        await showDialog<void>(
          context: context,
          builder: (_) => ComicAccountDialog(source: source),
        );
        ref.invalidate(comicLoginProvider(widget.sourceKey));
        ref.invalidate(
            comicDetailProvider((widget.sourceKey, widget.comicId)));
      },
    );
  }

  Widget _content(ComicDetails details) {
    final history = _historyEntry();
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _infoCard(details)),
        SliverToBoxAdapter(child: _chapterSection(details)),
        if (history != null)
          SliverToBoxAdapter(child: _continueReading(history)),
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
        border: Border.all(color: cs.outlineVariant),
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
                        for (final tag in details.tags) _tagChip(tag, cs),
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
    final cs = Theme.of(context).colorScheme;
    return FilledButton.icon(
      style: isFavorite
          ? FilledButton.styleFrom(
              backgroundColor: cs.surfaceContainerHighest,
              foregroundColor: cs.onSurfaceVariant,
            )
          : null,
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

  Widget _tagChip(String label, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: cs.primary)),
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
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: cs.primary),
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
        border: Border.all(color: cs.outlineVariant),
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
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 12),
            if (chapters.isEmpty)
              _canLoadEp()
                  ? TwoColumnButtonGrid(
                      children: [_chapterButton('', '开始阅读')],
                    )
                  : Text('暂无章节',
                      style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withValues(alpha: 0.4)))
            else
              TwoColumnButtonGrid(
                children: [
                  for (final chapter in chapters)
                    _chapterButton(chapter.key, chapter.value),
                ],
              ),
          ],
        ),
      ),
    );
  }

  bool _canLoadEp() {
    return ref
            .watch(comicSourcesProvider)
            .valueOrNull
            ?.where((s) => s.key == widget.sourceKey)
            .firstOrNull
            ?.canLoadEp ??
        false;
  }

  Widget _chapterButton(String id, String title) {
    return PillButton(label: title, onTap: () => _openReader(id));
  }

  Widget _continueReading(ComicHistoryEntry entry) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => _openReader(entry.chapterId, entry.page),
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

  void _openReader(String chapterId, [int page = 0]) {
    Navigator.push(
      context,
      smoothRoute(ComicReaderPage(
        sourceKey: widget.sourceKey,
        comicId: widget.comicId,
        chapterId: chapterId,
        initialPage: page,
      )),
    );
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
