import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/comic/comic_history.dart';
import '../../core/comic/comic_reader_settings.dart';
import '../../core/comic/models.dart';
import '../../core/comic/reader_nav.dart';
import '../../core/platform.dart';
import '../../core/widgets/desktop_drag_area.dart';
import '../../core/widgets/window_controls.dart';
import 'comic_providers.dart';

class ComicReaderPage extends ConsumerStatefulWidget {
  final String sourceKey;
  final String comicId;
  final String chapterId;
  final int initialPage;

  const ComicReaderPage({
    super.key,
    required this.sourceKey,
    required this.comicId,
    required this.chapterId,
    this.initialPage = 0,
  });

  @override
  ConsumerState<ComicReaderPage> createState() => _ComicReaderPageState();
}

class _ComicReaderPageState extends ConsumerState<ComicReaderPage> {
  late String _chapterId;
  late int _page;
  bool _chromeVisible = true;
  bool _switchingChapter = false;
  bool _programmaticScroll = false;
  bool _initialJumpDone = false;
  bool _pendingLandAtEnd = false;
  bool _resuming = false;
  DateTime? _lastHistoryWrite;
  Timer? _chromeTimer;
  Timer? _historyTimer;
  final _scrollController = ScrollController();
  final _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _chapterId = widget.chapterId;
    _page = widget.initialPage;
    _showChrome();
  }

  @override
  void dispose() {
    _chromeTimer?.cancel();
    _historyTimer?.cancel();
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final epAsync = ref.watch(
        comicEpProvider((widget.sourceKey, widget.comicId, _chapterId)));
    final details =
        ref.watch(comicDetailProvider((widget.sourceKey, widget.comicId)))
            .valueOrNull;
    final settings = ref.watch(comicReaderSettingsProvider);
    final showChrome = _chromeVisible || !epAsync.hasValue;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: epAsync.when(
              loading: () => Center(
                  child: CircularProgressIndicator(color: cs.onSurfaceVariant)),
              error: (_, __) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleChrome,
                child: _chapterError(),
              ),
              data: (ep) => settings.mode == ComicReaderMode.pageHorizontal
                  ? _horizontal(ep, details)
                  : _continuous(ep, details),
            ),
          ),
          if (showChrome) _topBar(details),
          if (showChrome) _bottomBar(epAsync.valueOrNull, details, settings),
        ],
      ),
    );
  }

  Widget _continuous(ComicEp ep, ComicDetails? details) {
    final cs = Theme.of(context).colorScheme;
    final images = ep.images;
    if (images.isEmpty) {
      return Center(
          child: Text('本章暂无图片', style: TextStyle(color: cs.onSurfaceVariant)));
    }
    _scheduleInitialOrLanding(images.length);
    final nav = _nav(details);
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        if (_resuming) _applyResumeJump(images.length);
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (_programmaticScroll) return false;
          if (notification is ScrollStartNotification) {
            _resuming = false;
          }
          if (notification is! ScrollUpdateNotification &&
              notification is! ScrollEndNotification) {
            return false;
          }
          final metrics = notification.metrics;
          final page = currentPageFromScroll(
              metrics.pixels, metrics.maxScrollExtent, images.length);
          _onPageChanged(page, images.length);
          if (metrics.maxScrollExtent > 0 &&
              metrics.pixels >= metrics.maxScrollExtent - 8 &&
              nav.next != null) {
            _goToChapter(nav.next!);
          } else if (metrics.pixels <= 8 &&
              _page == 0 &&
              nav.previous != null) {
            _goToChapter(nav.previous!, atEnd: true);
          }
          return false;
        },
        child: ListView.builder(
          controller: _scrollController,
          itemCount: images.length + (nav.next != null ? 1 : 0),
          itemBuilder: (context, i) {
            if (i >= images.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _goToChapter(nav.next!),
                      child: const Text('下一章'),
                    ),
                  ),
                ),
              );
            }
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleChrome,
              child: _ReaderImage(
                key: ValueKey('$_chapterId-$i'),
                sourceKey: widget.sourceKey,
                comicId: widget.comicId,
                chapterId: _chapterId,
                url: images[i],
                fit: BoxFit.fitWidth,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _horizontal(ComicEp ep, ComicDetails? details) {
    final cs = Theme.of(context).colorScheme;
    final images = ep.images;
    if (images.isEmpty) {
      return Center(
          child: Text('本章暂无图片', style: TextStyle(color: cs.onSurfaceVariant)));
    }
    _scheduleInitialOrLanding(images.length);
    final nav = _nav(details);
    final hasNext = nav.next != null;
    return NotificationListener<OverscrollNotification>(
      onNotification: (notification) {
        if (notification.overscroll < 0 &&
            _page == 0 &&
            nav.previous != null) {
          _goToChapter(nav.previous!, atEnd: true);
        }
        return false;
      },
      child: PageView.builder(
        controller: _pageController,
        itemCount: images.length + (hasNext ? 1 : 0),
        onPageChanged: (index) {
          if (index >= images.length) {
            if (hasNext) _goToChapter(nav.next!);
            return;
          }
          _onPageChanged(index, images.length);
        },
        itemBuilder: (context, index) {
          if (index >= images.length) {
            return Center(
                child: CircularProgressIndicator(color: cs.onSurfaceVariant));
          }
          return _ZoomablePage(
            onPrev: () => _flipTo(-1),
            onNext: () => _flipTo(1),
            onToggleChrome: _toggleChrome,
            child: _ReaderImage(
              key: ValueKey('$_chapterId-$index'),
              sourceKey: widget.sourceKey,
              comicId: widget.comicId,
              chapterId: _chapterId,
              url: images[index],
            ),
          );
        },
      ),
    );
  }

  void _scheduleInitialOrLanding(int total) {
    if (_pendingLandAtEnd) {
      _pendingLandAtEnd = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _page = total - 1);
        _jumpToInitial(total);
        _preload(_page, total);
      });
      return;
    }
    if (_initialJumpDone) return;
    _initialJumpDone = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _jumpToInitial(total);
      _preload(_page, total);
    });
  }

  void _jumpToInitial(int total) {
    if (!mounted) return;
    if (ref.read(comicReaderSettingsProvider).mode ==
        ComicReaderMode.pageHorizontal) {
      if (_pageController.hasClients) _pageController.jumpToPage(_page);
      return;
    }
    if (_page <= 0 || total <= 1) return;
    _resuming = true;
    _applyResumeJump(total);
  }

  void _applyResumeJump(int total) {
    if (!_resuming || !_scrollController.hasClients || total <= 1) return;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) return;
    final target = (_page / (total - 1)) * max;
    final current = _scrollController.position.pixels;
    if ((current - target).abs() < 1) return;
    _programmaticScroll = true;
    _scrollController.jumpTo(target.clamp(0.0, max));
    _programmaticScroll = false;
  }

  Widget _topBar(ComicDetails? details) {
    final cs = Theme.of(context).colorScheme;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
            child: DesktopDragArea(
        child: Container(
          height: 48 + (isDesktop ? 0.0 : MediaQuery.of(context).padding.top),
          padding: EdgeInsets.only(
              left: 4,
              top: isDesktop ? 0.0 : MediaQuery.of(context).padding.top),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            border: Border(
                bottom: BorderSide(color: cs.outlineVariant, width: 0.5)),
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
                  details?.title ?? '',
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
      ),
    );
  }

  Widget _bottomBar(
      ComicEp? ep, ComicDetails? details, ComicReaderSettings settings) {
    final cs = Theme.of(context).colorScheme;
    final total = ep?.images.length ?? 0;
    final chapterTitle = details?.chapters[_chapterId] ?? '';
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          border:
              Border(top: BorderSide(color: cs.outlineVariant, width: 0.5)),
        ),
        child: Row(
          children: [
            TextButton.icon(
              onPressed: () => _openChapterList(details),
              icon: const Icon(Icons.list_rounded, size: 18),
              label: const Text('目录'),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                chapterTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ),
            const Spacer(),
            Text(
              '${total == 0 ? 0 : _page + 1} / $total',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: settings.mode == ComicReaderMode.continuousVertical
                  ? '翻页模式'
                  : '连续模式',
              onPressed: _toggleMode,
              icon: Icon(
                settings.mode == ComicReaderMode.continuousVertical
                    ? Icons.swap_horiz_rounded
                    : Icons.swap_vert_rounded,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openChapterList(ComicDetails? details) {
    final cs = Theme.of(context).colorScheme;
    final chapters = details?.chapters.entries.toList() ?? const [];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFFFFFFFF),
      builder: (ctx) => ListView.builder(
        itemCount: chapters.length,
        itemBuilder: (_, i) {
          final entry = chapters[i];
          return ListTile(
            title: Text(entry.value),
            selected: entry.key == _chapterId,
            selectedColor: cs.primary,
            onTap: () {
              Navigator.pop(ctx);
              _goToChapter(entry.key);
            },
          );
        },
      ),
    );
  }

  void _toggleChrome() {
    _chromeTimer?.cancel();
    setState(() => _chromeVisible = !_chromeVisible);
  }

  void _showChrome() {
    _chromeTimer?.cancel();
    if (!_chromeVisible) setState(() => _chromeVisible = true);
  }

  ChapterNav _nav(ComicDetails? details) {
    final ids = details?.chapters.keys.toList() ?? const <String>[];
    return chapterNav(ids, _chapterId);
  }

  void _flipTo(int delta) {
    final ep = ref
        .read(comicEpProvider((widget.sourceKey, widget.comicId, _chapterId)))
        .valueOrNull;
    final total = ep?.images.length ?? 0;
    final nav = _nav(ref
        .read(comicDetailProvider((widget.sourceKey, widget.comicId)))
        .valueOrNull);
    final target = _page + delta;
    if (target < 0) {
      if (nav.previous != null) _goToChapter(nav.previous!, atEnd: true);
      return;
    }
    if (target >= total) {
      if (nav.next != null) _goToChapter(nav.next!);
      return;
    }
    if (_pageController.hasClients) {
      _pageController.animateToPage(target,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  void _goToChapter(String chapterId, {bool atEnd = false}) {
    if (_switchingChapter || chapterId == _chapterId) return;
    _switchingChapter = true;
    _pendingLandAtEnd = atEnd;
    _resuming = false;
    setState(() {
      _chapterId = chapterId;
      _page = 0;
    });
    _recordHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _programmaticScroll = true;
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
      if (_pageController.hasClients) _pageController.jumpToPage(0);
      _programmaticScroll = false;
      _switchingChapter = false;
    });
  }

  Future<void> _toggleMode() async {
    final current = ref.read(comicReaderSettingsProvider).mode;
    final next = current == ComicReaderMode.continuousVertical
        ? ComicReaderMode.pageHorizontal
        : ComicReaderMode.continuousVertical;
    await ref.read(comicReaderSettingsProvider.notifier).setMode(next);
    if (!mounted) return;
    _initialJumpDone = true;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (next == ComicReaderMode.pageHorizontal) {
        if (_pageController.hasClients) _pageController.jumpToPage(_page);
        return;
      }
      final total = ref
              .read(comicEpProvider(
                  (widget.sourceKey, widget.comicId, _chapterId)))
              .valueOrNull
              ?.images
              .length ??
          0;
      if (total > 1) {
        _resuming = true;
        _applyResumeJump(total);
      }
    });
  }

  void _onPageChanged(int page, int total) {
    if (page == _page) return;
    setState(() => _page = page);
    _scheduleHistory();
    _preload(page, total);
  }

  void _scheduleHistory() {
    final now = DateTime.now();
    final last = _lastHistoryWrite;
    if (last == null || now.difference(last) >= const Duration(seconds: 1)) {
      _recordHistory();
    } else {
      _historyTimer?.cancel();
      _historyTimer = Timer(
          const Duration(seconds: 1) - now.difference(last), _recordHistory);
    }
  }

  void _recordHistory() {
    _historyTimer?.cancel();
    _lastHistoryWrite = DateTime.now();
    final details =
        ref.read(comicDetailProvider((widget.sourceKey, widget.comicId)))
            .valueOrNull;
    final chapterTitle = details?.chapters[_chapterId] ?? _chapterId;
    ref.read(comicHistoryProvider.notifier).record(ComicHistoryEntry(
          sourceKey: widget.sourceKey,
          comicId: widget.comicId,
          title: details?.title ?? '',
          cover: details?.cover,
          chapterId: _chapterId,
          chapterTitle: chapterTitle,
          page: _page,
          readAt: DateTime.now(),
        ));
  }

  Future<void> _preload(int page, int total) async {
    final images = ref
        .read(comicEpProvider(
            (widget.sourceKey, widget.comicId, _chapterId)))
        .valueOrNull
        ?.images;
    if (images == null) return;
    final imageProvider = ref.read(comicImageProvider);
    for (final index in preloadIndices(page, total)) {
      try {
        final provider = await imageProvider.resolve(
            widget.sourceKey, widget.comicId, _chapterId, images[index]);
        if (!mounted) return;
        await precacheImage(provider, context);
      } catch (_) {
        // A preload failure must not disturb reading.
      }
    }
    final details =
        ref.read(comicDetailProvider((widget.sourceKey, widget.comicId)))
            .valueOrNull;
    final nav = _nav(details);
    if (nav.next != null) {
      await _preloadChapterImage(nav.next!, last: false);
    }
    if (page <= 1 && nav.previous != null) {
      await _preloadChapterImage(nav.previous!, last: true);
    }
  }

  Future<void> _preloadChapterImage(String chapterId,
      {required bool last}) async {
    try {
      final ep = await ref
          .read(comicEpProvider(
              (widget.sourceKey, widget.comicId, chapterId))
              .future);
      if (ep.images.isEmpty || !mounted) return;
      final url = last ? ep.images.last : ep.images.first;
      final provider = await ref
          .read(comicImageProvider)
          .resolve(widget.sourceKey, widget.comicId, chapterId, url);
      if (mounted) await precacheImage(provider, context);
    } catch (_) {
      // A preload failure must not disturb reading.
    }
  }

  Widget _chapterError() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, color: cs.onSurfaceVariant, size: 40),
          const SizedBox(height: 12),
          Text('章节加载失败',
              style: TextStyle(color: cs.onSurface)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => ref.invalidate(comicEpProvider(
                  (widget.sourceKey, widget.comicId, _chapterId))),
              child: const Text('重试'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReaderImage extends ConsumerStatefulWidget {
  final String sourceKey;
  final String comicId;
  final String chapterId;
  final String url;
  final BoxFit fit;

  const _ReaderImage({
    super.key,
    required this.sourceKey,
    required this.comicId,
    required this.chapterId,
    required this.url,
    this.fit = BoxFit.contain,
  });

  @override
  ConsumerState<_ReaderImage> createState() => _ReaderImageState();
}

class _ReaderImageState extends ConsumerState<_ReaderImage> {
  late Future<ImageProvider> _future;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _ReaderImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.chapterId != widget.chapterId) {
      _resolve();
    }
  }

  void _resolve() {
    _future = ref.read(comicImageProvider).resolve(
        widget.sourceKey, widget.comicId, widget.chapterId, widget.url);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ImageProvider>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _retry();
        if (!snapshot.hasData) return _loading();
        return Image(
          image: snapshot.data!,
          fit: widget.fit,
          width: double.infinity,
          errorBuilder: (_, __, ___) => _retry(),
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : _loading(),
        );
      },
    );
  }

  Widget _loading() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
          child: CircularProgressIndicator(color: cs.onSurfaceVariant)),
    );
  }

  Widget _retry() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined,
                color: cs.onSurfaceVariant, size: 36),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(_resolve),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomablePage extends StatefulWidget {
  final Widget child;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToggleChrome;

  const _ZoomablePage({
    required this.child,
    required this.onPrev,
    required this.onNext,
    required this.onToggleChrome,
  });

  @override
  State<_ZoomablePage> createState() => _ZoomablePageState();
}

class _ZoomablePageState extends State<_ZoomablePage> {
  final _controller = TransformationController();
  bool _zoomed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    setState(() {
      _zoomed = !_zoomed;
      _controller.value = _zoomed
          ? (Matrix4.identity()..scaleByDouble(2.5, 2.5, 2.5, 1.0))
          : Matrix4.identity();
    });
  }

  void _handleTapUp(TapUpDetails details) {
    final width = context.size?.width ?? 0;
    final x = details.localPosition.dx;
    if (width > 0 && x < width / 3) {
      widget.onPrev();
    } else if (width > 0 && x > width * 2 / 3) {
      widget.onNext();
    } else {
      widget.onToggleChrome();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapUp: _handleTapUp,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _controller,
        minScale: 1,
        maxScale: 4,
        child: widget.child,
      ),
    );
  }
}
