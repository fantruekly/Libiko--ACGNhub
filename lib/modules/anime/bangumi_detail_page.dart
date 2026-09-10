import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/work.dart';
import 'anime_providers.dart';
import 'anime_search.dart';

class BangumiDetailPage extends ConsumerStatefulWidget {
  final Work work;

  const BangumiDetailPage({super.key, required this.work});

  @override
  ConsumerState<BangumiDetailPage> createState() => _BangumiDetailPageState();
}

class _BangumiDetailPageState extends ConsumerState<BangumiDetailPage> {
  Map<String, dynamic>? _detail;
  bool _loadingDetail = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final bangumiId = widget.work.extra['bangumiId'] as int?;
    if (bangumiId == null) {
      setState(() => _loadingDetail = false);
      return;
    }
    final service = ref.read(bangumiServiceProvider);
    final detail = await service.getSubjectDetail(bangumiId);
    if (mounted) {
      setState(() {
        _detail = detail;
        _loadingDetail = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final work = widget.work;
    final colorScheme = Theme.of(context).colorScheme;
    final bangumiId = work.extra['bangumiId'] as int?;

    final summary = _detail?['summary'] as String?;
    final rating = _detail?['rating'] as num?;
    final eps = _detail?['eps'] as int?;
    final airDate = _detail?['airDate'] as String?;
    final tags = (_detail?['tags'] as List<dynamic>?)?.map((t) => t.toString()).toList() ?? [];
    final coverUrl = (_detail?['cover'] as String?) ?? work.coverUrl;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero image background
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              work.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            centerTitle: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverUrl != null && coverUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: coverUrl,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 300),
                      errorWidget: (_, __, ___) => _gradientBg(colorScheme),
                    )
                  else
                    _gradientBg(colorScheme),
                  // Gradient fade
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.1),
                            colorScheme.surface.withValues(alpha: 0.85),
                            colorScheme.surface,
                          ],
                          stops: const [0, 0.7, 1],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Info card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 120, height: 168,
                      child: coverUrl != null && coverUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: coverUrl,
                              fit: BoxFit.cover,
                              fadeInDuration: const Duration(milliseconds: 150),
                              errorWidget: (_, __, ___) => _coverPlaceholder(colorScheme),
                            )
                          : _coverPlaceholder(colorScheme),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          work.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.3),
                        ),
                        const SizedBox(height: 10),
                        if (_loadingDetail)
                          SizedBox(
                            width: 100,
                            child: LinearProgressIndicator(minHeight: 2, color: colorScheme.primary.withValues(alpha: 0.3)),
                          ),
                        if (!_loadingDetail) ...[
                          _MetaChip(icon: Icons.star_rounded, label: rating != null ? rating.toStringAsFixed(1) : 'N/A', color: Colors.amber),
                          const SizedBox(height: 6),
                          _MetaChip(icon: Icons.live_tv_rounded, label: eps != null ? '$eps 话' : '? 话', color: colorScheme.primary),
                          if (airDate != null) ...[
                            const SizedBox(height: 6),
                            _MetaChip(icon: Icons.calendar_today_rounded, label: airDate, color: colorScheme.tertiary),
                          ],
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tags
          if (tags.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tags.map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(t, style: TextStyle(fontSize: 11, color: colorScheme.primary, fontWeight: FontWeight.w500)),
                  )).toList(),
                ),
              ),
            ),

          // Action buttons
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                children: [
                  if (bangumiId != null)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _openBgm(bangumiId),
                        icon: const Icon(Icons.play_circle_rounded, size: 20),
                        label: const Text('在Bangumi查看'),
                      ),
                    ),
                  if (bangumiId != null) const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final keyword = work.extra['keyword'] as String? ?? work.title;
                        Navigator.push(context, MaterialPageRoute(builder: (_) => AnimeSearchPage(initialKeyword: keyword)));
                      },
                      icon: const Icon(Icons.search, size: 20),
                      label: const Text('搜索播放资源'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Summary
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 2),
              child: Text('简介', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Text(
                summary?.isNotEmpty == true ? summary! : (_loadingDetail ? '正在加载…' : '暂无简介数据'),
                style: TextStyle(fontSize: 13.5, height: 1.65, color: colorScheme.onSurface.withValues(alpha: 0.7)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openBgm(int bangumiId) async {
    final uri = Uri.parse('https://bgm.tv/subject/$bangumiId');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _gradientBg(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primary.withValues(alpha: 0.3), colorScheme.tertiary.withValues(alpha: 0.2)],
        ),
      ),
    );
  }

  Widget _coverPlaceholder(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primary.withValues(alpha: 0.15), colorScheme.tertiary.withValues(alpha: 0.08)],
        ),
      ),
      child: Center(
        child: Icon(Icons.image_outlined, color: colorScheme.primary.withValues(alpha: 0.25), size: 32),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MetaChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}