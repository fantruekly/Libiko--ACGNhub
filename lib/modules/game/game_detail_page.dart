import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/game/galgamezywz_source.dart';
import '../../core/game/models.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../core/widgets/smooth_route.dart';
import '../../core/widgets/window_controls.dart';
import 'game_providers.dart';

const _accent = Color(0xFF007AFF);
const _muted = Color(0xFF5A5A5F);
const _fg = Color(0xFF1C1C1E);

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
    final key = (sourceKey, gameId);
    final async = ref.watch(gameDetailProvider(key));
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Column(
        children: [
          _header(context, async.valueOrNull),
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
                onAction: () => ref.invalidate(gameDetailProvider(key)),
              ),
              data: (detail) => _content(context, detail),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, GameDetail? detail) {
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
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: _fg),
              ),
            ),
            IconButton(
              tooltip: '在原站打开',
              icon: const Icon(Icons.open_in_new_rounded, size: 20),
              color: _muted,
              onPressed: detail == null
                  ? null
                  : () => _openSource(detail.sourceUrl),
            ),
            const WindowControls(),
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
    final game = detail.game;
    final coverUrl = (game.coverUrl?.isNotEmpty ?? false)
        ? game.coverUrl
        : ((cover?.isNotEmpty ?? false) ? cover : null);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _infoCard(game, coverUrl, detail),
        if (detail.paragraphs.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionTitle('简介'),
          const SizedBox(height: 8),
          for (final p in detail.paragraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(p,
                  style: const TextStyle(fontSize: 13, height: 1.6, color: _fg)),
            ),
        ],
        if (detail.screenshots.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionTitle('截图'),
          const SizedBox(height: 8),
          _gallery(context, detail.screenshots),
        ],
        const SizedBox(height: 20),
        const Text('数据来源 game.galgamezywz.org',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: _muted)),
      ],
    );
  }

  Widget _infoCard(Game game, String? coverUrl, GameDetail detail) {
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
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(width: 100, height: 132, child: _cover(coverUrl)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(game.title,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: _fg)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (game.category != null && game.category!.isNotEmpty)
                          _tag(game.category!),
                        for (final t in game.tags) _tag(t),
                      ],
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
                            style: const TextStyle(fontSize: 12, color: _muted))),
                    Expanded(
                        child: Text(value,
                            style: const TextStyle(fontSize: 12, color: _fg))),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _gallery(BuildContext context, List<String> urls) {
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
                httpHeaders: gameImageHeaders,
                placeholder: (_, __) => Container(color: const Color(0xFFE5E5EA)),
                errorWidget: (_, __, ___) =>
                    Container(color: const Color(0xFFE5E5EA)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(text,
      style: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600, color: _fg));

  Widget _tag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: const Color(0xFFE8F0FE),
            borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11, color: _accent, fontWeight: FontWeight.w500)),
      );

  Widget _cover(String? url) {
    if (url == null || url.isEmpty) {
      return Container(color: const Color(0xFFE8EAF6));
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: 300,
      httpHeaders: gameImageHeaders,
      placeholder: (_, __) => Container(color: const Color(0xFFE8EAF6)),
      errorWidget: (_, __, ___) => Container(color: const Color(0xFFE8EAF6)),
    );
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
                  httpHeaders: gameImageHeaders,
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
            child: DragToMoveArea(
              child: Container(
                height: 48,
                padding: const EdgeInsets.only(left: 4),
                child: Row(
                  children: [
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const WindowControls(),
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
