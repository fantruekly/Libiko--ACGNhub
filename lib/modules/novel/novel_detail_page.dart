import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/novel/linovelib_source.dart';
import '../../core/novel/models.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/pill_button.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../core/widgets/smooth_route.dart';
import '../../core/widgets/window_controls.dart';
import 'novel_providers.dart';
import 'novel_reader_page.dart';

const _accent = Color(0xFF007AFF);
const _muted = Color(0xFF5A5A5F);
const _fg = Color(0xFF1C1C1E);

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
      backgroundColor: const Color(0xFFF2F2F7),
      body: Column(
        children: [
          _header(),
          Expanded(
            child: async.when(
              loading: () => const ShimmerLoader(
                  crossAxisCount: 6,
                  itemCount: 12,
                  aspectRatio: 0.58,
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 24)),
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

  Widget _header() {
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
              color: _fg,
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: _fg),
              ),
            ),
            const WindowControls(),
          ],
        ),
      ),
    );
  }

  Widget _content(NovelDetail detail) {
    final novel = detail.novel;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _infoCard(novel),
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
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600, color: _fg)),
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final ch in vol.chapters)
                  PillButton(label: ch.title, onTap: () => _openChapter(ch)),
              ],
            ),
          ],
      ],
    );
  }

  Widget _infoCard(Novel novel) {
    final summary = novel.summary ?? '';
    final cover = (novel.coverUrl?.isNotEmpty ?? false)
        ? novel.coverUrl
        : (widget.cover?.isNotEmpty ?? false ? widget.cover : null);
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
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 100,
                  height: 132,
                  child: cover != null
                      ? CachedNetworkImage(
                          imageUrl: cover,
                          fit: BoxFit.cover,
                          httpHeaders: novelImageHeaders,
                          placeholder: (_, __) => _coverPlaceholder(),
                          errorWidget: (_, __, ___) => _coverPlaceholder(),
                        )
                      : _coverPlaceholder(),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(novel.title,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: _fg)),
                    const SizedBox(height: 6),
                    if (novel.author != null && novel.author!.isNotEmpty)
                      Text(novel.author!,
                          style: const TextStyle(fontSize: 13, color: _muted)),
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
              const style = TextStyle(fontSize: 13, height: 1.5, color: _fg);
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
                            style: const TextStyle(fontSize: 13, color: _accent)),
                      ),
                    ),
                ],
              );
            }),
          ],
        ],
      ),
    );
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

  Widget _tag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: const Color(0xFFE8F0FE),
            borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11, color: _accent, fontWeight: FontWeight.w500)),
      );

  void _openChapter(NovelChapterRef chapter) {
    Navigator.push(
      context,
      smoothRoute(NovelReaderPage(
        sourceKey: widget.sourceKey,
        novelId: widget.novelId,
        chapterId: chapter.id,
        title: widget.title,
      )),
    );
  }
}
