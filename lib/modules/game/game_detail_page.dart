import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/game/game_image.dart';
import '../../core/game/models.dart';
import '../../core/platform.dart';
import '../../core/widgets/desktop_drag_area.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/smooth_route.dart';
import '../../core/widgets/window_controls.dart';
import 'game_providers.dart';

class GameDetailPage extends ConsumerWidget {
  final String sourceKey;
  final String gameId;
  final String title;
  final String? cover;

  const GameDetailPage({
    super.key,
    required this.sourceKey,
    required this.gameId,
    required this.title,
    this.cover,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final key = (sourceKey, gameId);
    final async = ref.watch(gameDetailProvider(key));
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Column(
        children: [
          _header(context),
          Expanded(
            child: async.when(
              loading: () => _loading(cs),
              error: (_, __) => EmptyState(
                icon: Icons.cloud_off_rounded,
                message: '加载失败',
                actionLabel: '重试',
                onAction: () => ref.invalidate(gameDetailProvider(key)),
              ),
              data: (detail) => _content(context, detail),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loading(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _infoCard(
          Game(id: gameId, title: title, coverUrl: cover),
          cover,
          GameDetail(game: Game(id: gameId, title: title), sourceUrl: ''),
          cs,
        ),
        const SizedBox(height: 24),
        const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _header(BuildContext context) {
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
                title,
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

  Future<void> _openSource(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _content(BuildContext context, GameDetail detail) {
    final cs = Theme.of(context).colorScheme;
    final game = detail.game;
    final coverUrl = (game.coverUrl?.isNotEmpty ?? false)
        ? game.coverUrl
        : ((cover?.isNotEmpty ?? false) ? cover : null);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _infoCard(game, coverUrl, detail, cs),
        if (detail.paragraphs.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionTitle('简介', cs),
          const SizedBox(height: 8),
          for (final p in detail.paragraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(p,
                  style: TextStyle(fontSize: 13, height: 1.6, color: cs.onSurface)),
            ),
        ],
        if (detail.screenshots.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionTitle('截图', cs),
          const SizedBox(height: 8),
          _gallery(context, detail.screenshots),
        ],
        const SizedBox(height: 20),
        Text('数据来源 ${_sourceHost(detail.sourceUrl)}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      ],
    );
  }

  Widget _infoCard(Game game, String? coverUrl, GameDetail detail, ColorScheme cs) {
    final meta = <(String, String)>[
      if (game.publishedAt != null) ('发布时间', _formatDate(game.publishedAt!)),
      if (detail.updatedAt != null) ('最近更新', _formatDate(detail.updatedAt!)),
      if (detail.size != null && detail.size!.isNotEmpty)
        ('游戏大小', detail.size!),
      if (detail.platform != null && detail.platform!.isNotEmpty)
        ('游戏平台', detail.platform!),
      if (game.views != null) ('浏览热度', _formatCount(game.views!)),
    ];
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
                tag: 'game_${sourceKey}_$gameId',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child:
                      SizedBox(width: 100, height: 132, child: _cover(coverUrl)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(game.title,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (game.category != null && game.category!.isNotEmpty)
                          _tag(game.category!, cs),
                        for (final t in game.tags) _tag(t, cs),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: detail.sourceUrl.isEmpty
                          ? null
                          : () => _openSource(detail.sourceUrl),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('在原站打开',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final (label, value) in meta)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                        width: 72,
                        child: Text(label,
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant))),
                    Expanded(
                        child: Text(value,
                            style: TextStyle(fontSize: 12, color: cs.onSurface))),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _gallery(BuildContext context, List<String> urls) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 112.5,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => Navigator.push(
            context,
            smoothRoute(_ImageViewerPage(urls: urls, initialIndex: i)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 200,
              height: 112.5,
              child: CachedNetworkImage(
                imageUrl: urls[i],
                fit: BoxFit.cover,
                memCacheWidth: 400,
                httpHeaders: gameImageHeadersFor(urls[i]),
                placeholder: (_, __) => Container(color: cs.outlineVariant),
                errorWidget: (_, __, ___) =>
                    Container(color: cs.outlineVariant),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, ColorScheme cs) => Text(text,
      style: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface));

  Widget _tag(String text, ColorScheme cs) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: const Color(0xFFE8F0FE),
            borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: TextStyle(
                fontSize: 11, color: cs.primary, fontWeight: FontWeight.w500)),
      );

  Widget _cover(String? url) {
    if (url == null || url.isEmpty) {
      return Container(color: const Color(0xFFE8EAF6));
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: 300,
      httpHeaders: gameImageHeadersFor(url),
      placeholder: (_, __) => Container(color: const Color(0xFFE8EAF6)),
      errorWidget: (_, __, ___) => Container(color: const Color(0xFFE8EAF6)),
    );
  }

  String _sourceHost(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    return host.isEmpty ? url : host;
  }

  String _formatDate(DateTime d) {
    final l = d.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-'
        '${l.day.toString().padLeft(2, '0')}';
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _ImageViewerPage extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  const _ImageViewerPage({required this.urls, required this.initialIndex});

  @override
  State<_ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<_ImageViewerPage> {
  late final PageController _ctrl;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _ctrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _ctrl,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: widget.urls[i],
                  fit: BoxFit.contain,
                  httpHeaders: gameImageHeadersFor(widget.urls[i]),
                  placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(color: Colors.white54)),
                  errorWidget: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: Colors.white38, size: 48)),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: DesktopDragArea(
              child: Container(
                height: 48 +
                    (isDesktop ? 0.0 : MediaQuery.of(context).padding.top),
                padding: EdgeInsets.only(
                    left: 4,
                    top: isDesktop ? 0.0 : MediaQuery.of(context).padding.top),
                child: Row(
                  children: [
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    if (isDesktop)
                      WindowControls(
                        foregroundColor: Colors.white.withValues(alpha: 0.85),
                        hoverColor: Colors.white.withValues(alpha: 0.12),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (widget.urls.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Text('${_index + 1} / ${widget.urls.length}',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            ),
        ],
      ),
    );
  }
}
