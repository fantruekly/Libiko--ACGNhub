import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/novel/linovelib_source.dart';
import '../../core/novel/models.dart';
import '../../core/novel/novel_history.dart';
import '../../core/novel/novel_reader_settings.dart';
import '../../core/platform.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/marquee_text.dart';
import '../../core/widgets/window_controls.dart';
import 'novel_providers.dart';

class _Palette {
  final Color bg;
  final Color fg;
  final Color bar;
  final Color border;
  const _Palette(this.bg, this.fg, this.bar, this.border);

  static _Palette of(NovelReaderTheme theme) => switch (theme) {
        NovelReaderTheme.light => const _Palette(
            Color(0xFFFFFFFF), Color(0xFF1C1C1E), Color(0xFFFFFFFF), Color(0xFFE5E5EA)),
        NovelReaderTheme.sepia => const _Palette(
            Color(0xFFF5EFE0), Color(0xFF3B3226), Color(0xFFEFE6D2), Color(0xFFE0D5BC)),
        NovelReaderTheme.dark => const _Palette(
            Color(0xFF1C1C1E), Color(0xFFD8D8DC), Color(0xFF2C2C2E), Color(0xFF3A3A3C)),
      };
}

class NovelReaderPage extends ConsumerStatefulWidget {
  final String sourceKey;
  final String novelId;
  final String chapterId;
  final String title;
  final String? cover;
  const NovelReaderPage({
    super.key,
    required this.sourceKey,
    required this.novelId,
    required this.chapterId,
    required this.title,
    this.cover,
  });

  @override
  ConsumerState<NovelReaderPage> createState() => _NovelReaderPageState();
}

class _NovelReaderPageState extends ConsumerState<NovelReaderPage> {
  late String _chapterId = widget.chapterId;
  String? _lastRecordedChapterId;
  bool _chromeVisible = true;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(novelReaderSettingsProvider);
    final palette = _Palette.of(settings.theme);
    final chapters = _chapters();
    final async =
        ref.watch(novelChapterProvider((widget.sourceKey, widget.novelId, _chapterId)));
    final index = chapters.indexWhere((c) => c.id == _chapterId);

    ref.listen(
      novelChapterProvider((widget.sourceKey, widget.novelId, _chapterId)),
      (_, next) => next.whenData(_recordHistory),
    );
    async.whenData(_recordHistory);

    return Scaffold(
      backgroundColor: palette.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _chromeVisible = !_chromeVisible),
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => EmptyState(
                  icon: Icons.cloud_off_rounded,
                  message: '加载失败',
                  actionLabel: '重试',
                  onAction: () => ref.invalidate(novelChapterProvider(
                      (widget.sourceKey, widget.novelId, _chapterId))),
                ),
                data: (chapter) => _content(chapter, settings, palette),
              ),
            ),
          ),
          if (_chromeVisible) _topBar(palette),
          if (_chromeVisible) _bottomBar(palette, chapters, index),
        ],
      ),
    );
  }

  void _recordHistory(NovelChapter chapter) {
    if (_lastRecordedChapterId == _chapterId) return;
    _lastRecordedChapterId = _chapterId;
    ref.read(novelHistoryProvider.notifier).record(NovelHistoryEntry(
          sourceKey: widget.sourceKey,
          novelId: widget.novelId,
          title: widget.title,
          cover: widget.cover,
          chapterId: _chapterId,
          chapterTitle:
              chapter.title.isEmpty ? '第 $_chapterId 章' : chapter.title,
          updatedAt: DateTime.now(),
        ));
  }

  List<NovelChapterRef> _chapters() {
    final detail = ref
        .watch(novelDetailProvider((widget.sourceKey, widget.novelId)))
        .valueOrNull;
    return detail == null ? const [] : flattenChapters(detail);
  }

  Widget _content(
      NovelChapter chapter, NovelReaderSettings settings, _Palette palette) {
    return SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(20, 72, 20, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (chapter.title.isNotEmpty) ...[
            Text(chapter.title,
                style: TextStyle(
                    fontSize: settings.fontSize + 4,
                    fontWeight: FontWeight.w600,
                    color: palette.fg)),
            const SizedBox(height: 16),
          ],
          if (chapter.blocks.isEmpty)
            Text('本章暂无内容',
                style: TextStyle(
                    fontSize: settings.fontSize,
                    color: palette.fg.withValues(alpha: 0.5)))
          else
            for (final block in chapter.blocks)
              switch (block) {
                NovelText(:final text) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(text,
                        style: TextStyle(
                            fontSize: settings.fontSize,
                            height: settings.lineHeight,
                            color: palette.fg)),
                  ),
                NovelImage(:final url) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: SizedBox(
                      height: _illustrationHeight(context),
                      width: double.infinity,
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.contain,
                        httpHeaders: novelImageHeaders,
                        placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator()),
                        errorWidget: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_outlined)),
                      ),
                    ),
                  ),
              },
        ],
      ),
    );
  }

  /// The height of the content viewport (between the 56px top bar and the
  /// 64px bottom bar), so an illustration fills the page vertically with the
  /// sides left blank, like a comic page.
  double _illustrationHeight(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    final topBar = 56 + (isDesktop ? 0.0 : insets.top);
    final bottomBar = 64 + (isDesktop ? 0.0 : insets.bottom);
    final h = MediaQuery.sizeOf(context).height - topBar - bottomBar - 24;
    return h.clamp(200, 4000).toDouble();
  }

  Widget _topBar(_Palette palette) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 56 + (isDesktop ? 0.0 : MediaQuery.of(context).padding.top),
        padding: EdgeInsets.only(
            left: 8,
            right: 8,
            top: isDesktop ? 0.0 : MediaQuery.of(context).padding.top),
        decoration: BoxDecoration(
          color: palette.bar,
          border: Border(bottom: BorderSide(color: palette.border, width: 0.5)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              color: palette.fg,
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: palette.fg),
              ),
            ),
            if (isDesktop) const WindowControls(),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar(_Palette palette, List<NovelChapterRef> chapters, int index) {
    final hasPrev = index > 0;
    final hasNext = index >= 0 && index < chapters.length - 1;
    final detail = ref
        .watch(novelDetailProvider((widget.sourceKey, widget.novelId)))
        .valueOrNull;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: palette.bar,
          border: Border(top: BorderSide(color: palette.border, width: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _barButton(palette, Icons.chevron_left_rounded, '上一章',
                hasPrev ? () => _goChapter(chapters[index - 1].id) : null),
            _barButton(palette, Icons.list_rounded, '目录', () => _openCatalog(detail)),
            _barButton(palette, Icons.text_fields_rounded, '设置', _openSettings),
            _barButton(palette, Icons.chevron_right_rounded, '下一章',
                hasNext ? () => _goChapter(chapters[index + 1].id) : null),
          ],
        ),
      ),
    );
  }

  Widget _barButton(
      _Palette palette, IconData icon, String label, VoidCallback? onTap) {
    final color = onTap == null ? palette.fg.withValues(alpha: 0.3) : palette.fg;
    return TextButton(
      onPressed: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  void _goChapter(String chapterId) {
    setState(() => _chapterId = chapterId);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _openCatalog(NovelDetail? detail) {
    final cs = Theme.of(context).colorScheme;
    final palette = _Palette.of(ref.read(novelReaderSettingsProvider).theme);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: palette.bg,
      builder: (_) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                surface: palette.bg,
                onSurface: palette.fg,
              ),
        ),
        child: ListView(
          children: [
            if (detail == null || detail.volumes.isEmpty)
              const ListTile(title: Text('暂无目录'))
            else
              for (final v in detail.volumes) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(v.title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: palette.fg.withValues(alpha: 0.7))),
                ),
                for (final c in v.chapters)
                  ListTile(
                    dense: true,
                    title: MarqueeText(text: c.title),
                    trailing: c.id == _chapterId
                        ? Icon(Icons.check_rounded, size: 18, color: cs.primary)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      if (c.id != _chapterId) _goChapter(c.id);
                    },
                  ),
              ],
          ],
        ),
      ),
    );
  }

  void _openSettings() {
    final palette = _Palette.of(ref.read(novelReaderSettingsProvider).theme);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: palette.bg,
      builder: (_) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                surface: palette.bg,
                onSurface: palette.fg,
              ),
        ),
        child: const _ReaderSettingsSheet(),
      ),
    );
  }
}

class _ReaderSettingsSheet extends ConsumerWidget {
  const _ReaderSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(novelReaderSettingsProvider);
    final notifier = ref.read(novelReaderSettingsProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('字号', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Row(
            children: [
              IconButton(
                onPressed: settings.fontSize > 12
                    ? () => notifier.setFontSize(settings.fontSize - 1)
                    : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              Text('${settings.fontSize.round()}', style: const TextStyle(fontSize: 15)),
              IconButton(
                onPressed: settings.fontSize < 28
                    ? () => notifier.setFontSize(settings.fontSize + 1)
                    : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('行距', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Row(
            children: [
              IconButton(
                onPressed: settings.lineHeight > 1.2
                    ? () => notifier.setLineHeight(settings.lineHeight - 0.1)
                    : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              Text(settings.lineHeight.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 15)),
              IconButton(
                onPressed: settings.lineHeight < 2.6
                    ? () => notifier.setLineHeight(settings.lineHeight + 0.1)
                    : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('主题', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final t in NovelReaderTheme.values)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ChoiceChip(
                    label: Text(switch (t) {
                      NovelReaderTheme.light => '浅色',
                      NovelReaderTheme.sepia => '米色',
                      NovelReaderTheme.dark => '深色',
                    }),
                    selected: settings.theme == t,
                    showCheckmark: false,
                    onSelected: (_) => notifier.setTheme(t),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
