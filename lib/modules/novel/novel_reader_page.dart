import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/novel/linovelib_source.dart';
import '../../core/novel/models.dart';
import '../../core/novel/novel_history.dart';
import '../../core/novel/reading_position.dart';
import '../../core/novel/novel_reader_settings.dart';
import '../../core/platform.dart';
import '../../core/services/cache_manager.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/widgets/reader_progress_bar.dart';
import '../../core/widgets/window_controls.dart';
import 'novel_providers.dart';

class _Palette {
  final Color bg;
  final Color fg;
  final Color bar;
  final Color border;
  const _Palette(this.bg, this.fg, this.bar, this.border);

  static _Palette of(NovelReaderTheme theme, Brightness brightness) {
    return switch (resolveTheme(theme, brightness)) {
      NovelReaderTheme.light => const _Palette(Color(0xFFFFFFFF),
          Color(0xFF1C1C1E), Color(0xFFFFFFFF), Color(0xFFE5E5EA)),
      NovelReaderTheme.sepia => const _Palette(Color(0xFFF5EFE0),
          Color(0xFF3B3226), Color(0xFFEFE6D2), Color(0xFFE0D5BC)),
      NovelReaderTheme.dark => const _Palette(Color(0xFF1C1C1E),
          Color(0xFFD8D8DC), Color(0xFF2C2C2E), Color(0xFF3A3A3C)),
      NovelReaderTheme.auto => const _Palette(Color(0xFFFFFFFF),
          Color(0xFF1C1C1E), Color(0xFFFFFFFF), Color(0xFFE5E5EA)),
    };
  }
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

class _NovelReaderPageState extends ConsumerState<NovelReaderPage>
    with WidgetsBindingObserver {
  late String _chapterId = widget.chapterId;
  String? _lastRecordedChapterId;
  late final NovelHistoryNotifier _history;
  NovelChapter? _activeChapter;
  NovelHistoryEntry? _lastCaptured;
  final _blockKeys = <int, GlobalKey>{};
  final _viewportKey = GlobalKey();
  Timer? _historyTimer;
  bool _restoring = false;
  double? _layoutWidth;
  bool _chromeVisible = true;
  final _scroll = ScrollController();
  final _progress = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _history = ref.read(novelHistoryProvider.notifier);
    _scroll.addListener(_updateProgress);
  }

  @override
  void dispose() {
    _flushHistory();
    _historyTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _scroll.removeListener(_updateProgress);
    _progress.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _updateProgress() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final max = position.maxScrollExtent;
    _progress.value = max <= 0 ? 0 : (position.pixels / max).clamp(0.0, 1.0);
    if (!_restoring) _capturePosition();
    if (!_restoring && _activeChapter != null && _historyTimer == null) {
      _historyTimer = Timer(const Duration(seconds: 1), _flushHistory);
    }
  }

  void _seekToFraction(double fraction) {
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(_scroll.position.maxScrollExtent * fraction.clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(novelReaderSettingsProvider);
    ref.listen(
        novelReaderSettingsProvider, (_, __) => _preserveLayoutPosition());
    final width = MediaQuery.sizeOf(context).width;
    if (_layoutWidth != null && width != _layoutWidth) {
      _preserveLayoutPosition();
    }
    _layoutWidth = width;
    final palette = _Palette.of(settings.theme, Theme.of(context).brightness);
    final chapters = _chapters();
    final async = ref.watch(
        novelChapterProvider((widget.sourceKey, widget.novelId, _chapterId)));
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
          _progressBar(),
        ],
      ),
    );
  }

  void _recordHistory(NovelChapter chapter) {
    if (_lastRecordedChapterId == _chapterId) return;
    _lastRecordedChapterId = _chapterId;
    _activeChapter = chapter;
    final saved =
        NovelHistoryManager().forNovel(widget.sourceKey, widget.novelId);
    final sameChapter = saved?.chapterId == _chapterId;
    _lastCaptured = NovelHistoryEntry(
      sourceKey: widget.sourceKey,
      novelId: widget.novelId,
      title: widget.title,
      cover: widget.cover,
      chapterId: _chapterId,
      chapterTitle: chapter.title.isEmpty ? '第 $_chapterId 章' : chapter.title,
      updatedAt: DateTime.now(),
      blockIndex: sameChapter ? saved!.blockIndex : 0,
      characterOffset: sameChapter ? saved!.characterOffset : 0,
      scrollFraction: sameChapter ? saved!.scrollFraction : 0,
      anchorText: sameChapter ? saved!.anchorText : null,
    );
    _restoring = true;
    final chapterId = _chapterId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || chapterId != _chapterId) return;
      if (saved != null && saved.chapterId == chapterId) {
        _restorePosition(saved);
      }
      _restoring = false;
      _flushHistory();
    });
  }

  NovelHistoryEntry? _capturePosition() {
    final chapter = _activeChapter;
    if (chapter == null || _lastRecordedChapterId != _chapterId) return null;
    var blockIndex = 0;
    var characterOffset = 0;
    final viewport = _viewportKey.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize || !viewport.attached) {
      return _lastCaptured;
    }
    var foundBlock = false;
    {
      final visibleTop = viewport.localToGlobal(const Offset(0, 72)).dy;
      for (var i = 0; i < chapter.blocks.length; i++) {
        final render = _blockKeys[i]?.currentContext?.findRenderObject();
        if (render is! RenderBox || !render.hasSize || !render.attached) {
          continue;
        }
        final top = render.localToGlobal(Offset.zero).dy;
        if (top + render.size.height <= visibleTop) continue;
        blockIndex = i;
        foundBlock = true;
        if (render is RenderParagraph) {
          characterOffset = render
              .getPositionForOffset(
                  Offset(0, (visibleTop - top).clamp(0, render.size.height)))
              .offset;
        }
        break;
      }
    }
    if (!foundBlock) return _lastCaptured;
    final captured = NovelHistoryEntry(
      sourceKey: widget.sourceKey,
      novelId: widget.novelId,
      title: widget.title,
      cover: widget.cover,
      chapterId: _chapterId,
      chapterTitle: chapter.title.isEmpty ? '第 $_chapterId 章' : chapter.title,
      updatedAt: DateTime.now(),
      blockIndex: blockIndex,
      characterOffset: characterOffset,
      scrollFraction: _progress.value,
      anchorText: chapter.blocks.isEmpty
          ? null
          : novelAnchorText(chapter.blocks[blockIndex], characterOffset),
    );
    _lastCaptured = captured;
    return captured;
  }

  void _flushHistory() {
    _historyTimer?.cancel();
    _historyTimer = null;
    final entry = _restoring ? _lastCaptured : _capturePosition();
    if (entry != null) {
      unawaited(_history.record(entry).catchError((Object error) {
        debugPrint('[NovelReader] progress save failed: $error');
      }));
    }
  }

  void _restorePosition(NovelHistoryEntry saved) {
    if (!_scroll.hasClients || _activeChapter == null) return;
    if (saved.scrollFraction == 0 &&
        saved.characterOffset == 0 &&
        saved.blockIndex == 0) {
      return;
    }
    final anchor = resolveNovelAnchor(_activeChapter!, saved);
    var target = _scroll.position.maxScrollExtent * saved.scrollFraction;
    final viewport = _viewportKey.currentContext?.findRenderObject();
    final block = anchor == null
        ? null
        : _blockKeys[anchor.blockIndex]?.currentContext?.findRenderObject();
    if (viewport is RenderBox && block is RenderBox && block.hasSize) {
      final caret = block is RenderParagraph
          ? block
              .getOffsetForCaret(
                  TextPosition(offset: anchor!.characterOffset), Rect.zero)
              .dy
          : 0.0;
      target = _scroll.offset +
          block.localToGlobal(Offset.zero).dy -
          viewport.localToGlobal(const Offset(0, 72)).dy +
          caret;
    }
    _scroll.jumpTo(target.clamp(0, _scroll.position.maxScrollExtent));
  }

  void _preserveLayoutPosition() {
    if (_restoring) return;
    final saved = _capturePosition();
    if (saved == null) return;
    _restoring = true;
    final chapterId = _chapterId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || chapterId != _chapterId) return;
      _restorePosition(saved);
      _restoring = false;
      _flushHistory();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _flushHistory();
    }
  }

  List<NovelChapterRef> _chapters() {
    final detail = ref
        .watch(novelDetailProvider((widget.sourceKey, widget.novelId)))
        .valueOrNull;
    return detail == null ? const [] : flattenChapters(detail);
  }

  Widget _content(
      NovelChapter chapter, NovelReaderSettings settings, _Palette palette) {
    final imageWidth = (((MediaQuery.sizeOf(context).width - 40) *
                MediaQuery.devicePixelRatioOf(context))
            .round())
        .clamp(1, 1 << 20);
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        scrollbars: false,
        dragDevices: const {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
          PointerDeviceKind.unknown,
        },
      ),
      child: SingleChildScrollView(
        key: _viewportKey,
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
              for (var blockIndex = 0;
                  blockIndex < chapter.blocks.length;
                  blockIndex++)
                switch (chapter.blocks[blockIndex]) {
                  NovelText(:final text) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(text,
                          key:
                              _blockKeys.putIfAbsent(blockIndex, GlobalKey.new),
                          style: TextStyle(
                              fontSize: settings.fontSize,
                              height: settings.lineHeight,
                              color: palette.fg)),
                    ),
                  NovelImage(:final url) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: SizedBox(
                        key: _blockKeys.putIfAbsent(blockIndex, GlobalKey.new),
                        height: _illustrationHeight(context),
                        width: double.infinity,
                        child: CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.contain,
                          httpHeaders: novelImageHeaders,
                          cacheManager: AppCacheManager(),
                          memCacheWidth: imageWidth,
                          placeholder: (_, __) =>
                              const Center(child: CircularProgressIndicator()),
                          errorWidget: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image_outlined)),
                        ),
                      ),
                    ),
                },
          ],
        ),
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
      child: GlassSurface(
        borderRadius: BorderRadius.zero,
        blur: 12,
        color: palette.bar.withValues(alpha: 0.94),
        border: Border(bottom: BorderSide(color: palette.border, width: 0.7)),
        child: SizedBox(
          height: 56 + (isDesktop ? 0.0 : MediaQuery.of(context).padding.top),
          child: Padding(
            padding: EdgeInsets.only(
                left: 8,
                right: 8,
                top: isDesktop ? 0.0 : MediaQuery.of(context).padding.top),
            child: Row(
              children: [
                IconButton(
                  tooltip: '返回',
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: palette.fg,
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: palette.fg),
                  ),
                ),
                if (isDesktop)
                  Theme(
                      data: Theme.of(context).copyWith(
                          colorScheme: Theme.of(context)
                              .colorScheme
                              .copyWith(onSurface: palette.fg)),
                      child: const WindowControls()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(
      _Palette palette, List<NovelChapterRef> chapters, int index) {
    final hasPrev = index > 0;
    final hasNext = index >= 0 && index < chapters.length - 1;
    final detail = ref
        .watch(novelDetailProvider((widget.sourceKey, widget.novelId)))
        .valueOrNull;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: GlassSurface(
        borderRadius: BorderRadius.zero,
        blur: 12,
        color: palette.bar.withValues(alpha: 0.94),
        border: Border(top: BorderSide(color: palette.border, width: 0.7)),
        child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                      child: _barButton(
                          palette,
                          Icons.chevron_left_rounded,
                          '上一章',
                          hasPrev
                              ? () => _goChapter(chapters[index - 1].id)
                              : null)),
                  Expanded(
                      child: _barButton(palette, Icons.list_rounded, '目录',
                          () => _openCatalog(detail))),
                  Expanded(
                      child: _barButton(palette, Icons.text_fields_rounded,
                          '设置', _openSettings)),
                  Expanded(
                      child: _barButton(
                          palette,
                          Icons.chevron_right_rounded,
                          '下一章',
                          hasNext
                              ? () => _goChapter(chapters[index + 1].id)
                              : null)),
                ],
              ),
            )),
      ),
    );
  }

  Widget _progressBar() {
    final insets = MediaQuery.paddingOf(context);
    final topBar = 56 + (isDesktop ? 0.0 : insets.top);
    final bottomBar = 64 + (isDesktop ? 0.0 : insets.bottom);
    return Positioned(
      top: topBar + 8,
      bottom: bottomBar + 8,
      right: 2,
      child: IgnorePointer(
        ignoring: !_chromeVisible,
        child: AnimatedOpacity(
          opacity: _chromeVisible ? 1 : 0,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          child: ValueListenableBuilder<double>(
            valueListenable: _progress,
            builder: (context, progress, _) => ReaderProgressBar(
              progress: progress,
              thumbColor: Theme.of(context).colorScheme.primary,
              onSeek: _seekToFraction,
            ),
          ),
        ),
      ),
    );
  }

  Widget _barButton(
      _Palette palette, IconData icon, String label, VoidCallback? onTap) {
    final color =
        onTap == null ? palette.fg.withValues(alpha: 0.3) : palette.fg;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          minimumSize: const Size(0, 48),
          foregroundColor: color),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 20,
              color: onTap == null
                  ? color
                  : (palette.bg.computeLuminance() < 0.3
                      ? const Color(0xFFA0CFFF)
                      : const Color(0xFF2477CE))),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, height: 1.2, color: color)),
        ],
      ),
    );
  }

  void _goChapter(String chapterId) {
    _flushHistory();
    _restoring = true;
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _blockKeys.clear();
    _lastCaptured = null;
    _activeChapter = null;
    _lastRecordedChapterId = null;
    _progress.value = 0;
    setState(() => _chapterId = chapterId);
  }

  void _openCatalog(NovelDetail? detail) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 640),
      backgroundColor: Colors.transparent,
      builder: (_) => _ReaderSheetFrame(
        title: '章节目录',
        expand: true,
        child: Builder(builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            children: [
              if (detail == null || detail.volumes.isEmpty)
                const ListTile(title: Text('暂无目录'))
              else
                for (final v in detail.volumes) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                    child: Text(v.title,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurfaceVariant)),
                  ),
                  for (final c in v.chapters)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          selected: c.id == _chapterId,
                          selectedTileColor:
                              cs.primaryContainer.withValues(alpha: 0.55),
                          selectedColor: cs.onPrimaryContainer,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 3),
                          title: Text(c.title,
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: c.id == _chapterId
                              ? Icon(Icons.check_rounded,
                                  size: 18, color: cs.primary)
                              : null,
                          onTap: () {
                            Navigator.pop(context);
                            if (c.id != _chapterId) _goChapter(c.id);
                          },
                        )),
                ],
            ],
          );
        }),
      ),
    );
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 640),
      backgroundColor: Colors.transparent,
      builder: (_) => const _ReaderSheetFrame(
        title: '阅读设置',
        child: _ReaderSettingsSheet(),
      ),
    );
  }
}

class _ReaderSheetFrame extends ConsumerWidget {
  const _ReaderSheetFrame(
      {required this.title, required this.child, this.expand = false});
  final String title;
  final Widget child;
  final bool expand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = Theme.of(context);
    final settings = ref.watch(novelReaderSettingsProvider);
    final palette = _Palette.of(settings.theme, base.brightness);
    final dark = palette.bg.computeLuminance() < 0.3;
    final cs = base.colorScheme.copyWith(
      brightness: dark ? Brightness.dark : Brightness.light,
      surface: palette.bar,
      onSurface: palette.fg,
      onSurfaceVariant: palette.fg.withValues(alpha: 0.72),
      primary: dark ? const Color(0xFFA0CFFF) : const Color(0xFF2477CE),
      onPrimary: dark ? const Color(0xFF173755) : Colors.white,
      primaryContainer:
          dark ? const Color(0xFF284D76) : const Color(0xFFDDEEFF),
      onPrimaryContainer:
          dark ? const Color(0xFFE0F0FF) : const Color(0xFF185289),
      secondaryContainer:
          dark ? const Color(0xFF284D76) : const Color(0xFFDDEEFF),
      onSecondaryContainer:
          dark ? const Color(0xFFE0F0FF) : const Color(0xFF185289),
      outlineVariant: palette.border,
    );
    final height = MediaQuery.sizeOf(context).height * 0.82;
    return Theme(
      data: base.copyWith(
          colorScheme: cs,
          textTheme: base.textTheme
              .apply(bodyColor: palette.fg, displayColor: palette.fg),
          iconTheme: IconThemeData(color: palette.fg)),
      child: Container(
        constraints: BoxConstraints(maxHeight: height),
        height: expand ? height : null,
        decoration: BoxDecoration(
            color: palette.bar,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: palette.border.withValues(alpha: 0.7))),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                    child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(top: 12),
                        decoration: BoxDecoration(
                            color: palette.fg.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4)))),
                Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Text(title,
                        style: TextStyle(
                            fontSize: 18,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: palette.fg))),
                Flexible(
                    fit: expand ? FlexFit.tight : FlexFit.loose, child: child),
              ],
            )),
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
    return SingleChildScrollView(
      child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _numberSetting(context,
                  title: '字号',
                  value: '${settings.fontSize.round()}',
                  onDecrease: settings.fontSize > 12
                      ? () => notifier.setFontSize(settings.fontSize - 1)
                      : null,
                  onIncrease: settings.fontSize < 28
                      ? () => notifier.setFontSize(settings.fontSize + 1)
                      : null),
              _numberSetting(context,
                  title: '行距',
                  value: settings.lineHeight.toStringAsFixed(1),
                  onDecrease: settings.lineHeight > 1.2
                      ? () => notifier.setLineHeight(settings.lineHeight - 0.1)
                      : null,
                  onIncrease: settings.lineHeight < 2.6
                      ? () => notifier.setLineHeight(settings.lineHeight + 0.1)
                      : null),
              _group(context,
                  title: '主题',
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      for (final t in NovelReaderTheme.values)
                        ChoiceChip(
                          label: Text(switch (t) {
                            NovelReaderTheme.auto => '跟随App',
                            NovelReaderTheme.light => '浅色',
                            NovelReaderTheme.sepia => '米色',
                            NovelReaderTheme.dark => '深色',
                          }),
                          selected: settings.theme == t,
                          selectedColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          labelStyle: TextStyle(
                              fontFamily: 'NotoSansSC',
                              fontWeight: FontWeight.w400,
                              color: settings.theme == t
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer
                                  : Theme.of(context).colorScheme.onSurface),
                          showCheckmark: false,
                          onSelected: (_) => notifier.setTheme(t),
                        ),
                    ],
                  )),
            ],
          )),
    );
  }

  Widget _group(BuildContext context,
      {required String title, required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.65))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }

  Widget _numberSetting(BuildContext context,
          {required String title,
          required String value,
          VoidCallback? onDecrease,
          VoidCallback? onIncrease}) =>
      _group(context,
          title: title,
          child: Row(children: [
            IconButton(
                tooltip: '减小$title',
                onPressed: onDecrease,
                icon: const Icon(Icons.remove_rounded)),
            Expanded(
                child: Text(value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary))),
            IconButton(
                tooltip: '增大$title',
                onPressed: onIncrease,
                icon: const Icon(Icons.add_rounded)),
          ]));
}
