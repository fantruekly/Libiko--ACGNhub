import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/work.dart';
import 'anime_providers.dart';

class AnimeDetailPage extends ConsumerStatefulWidget {
  final Work work;
  const AnimeDetailPage({super.key, required this.work});

  @override
  ConsumerState<AnimeDetailPage> createState() => _AnimeDetailPageState();
}

class _AnimeDetailPageState extends ConsumerState<AnimeDetailPage> {
  late Work _work;
  bool _loading = true;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _work = widget.work;
    _load();
  }

  Future<void> _load() async {
    try {
      final enriched = await ref.read(metadataServiceProvider).detail(widget.work);
      if (mounted) setState(() { _work = enriched; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final w = _work;
    final score = w.extra['score'] as num?;
    final episodes = w.extra['episodes'] as int?;
    final seasonYear = w.extra['seasonYear'] as int?;
    final format = w.extra['format'] as String?;
    final status = w.extra['status'] as String?;
    final banner = w.bannerUrl;
    final heroImage = (banner != null && banner.isNotEmpty) ? banner : w.coverUrl;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Column(
        children: [
          _header(w, cs),
          Expanded(
            child: CustomScrollView(
              slivers: [
                _heroImage(heroImage, cs),
                _infoSection(w, cs, score, episodes, seasonYear),
                if (w.tags.isNotEmpty) _tagsRow(w.tags),
                _summarySection(w.summary, cs),
                _metaSection(cs, format, status, seasonYear),
              ],
            ),
          ),
          _bottomBar(w),
        ],
      ),
    );
  }

  Widget _header(Work w, ColorScheme cs) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
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
              w.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroImage(String? cover, ColorScheme cs) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 220,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (cover != null && cover.isNotEmpty)
              CachedNetworkImage(
                imageUrl: cover,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(color: cs.primary.withValues(alpha: 0.1)),
              )
            else
              Container(color: cs.primary.withValues(alpha: 0.1)),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, const Color(0xFFF2F2F7)],
                    stops: const [0.6, 1],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoSection(Work w, ColorScheme cs, num? score, int? episodes, int? seasonYear) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 110,
                height: 154,
                child: w.coverUrl != null && w.coverUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: w.coverUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _coverPlaceholder(cs),
                      )
                    : _coverPlaceholder(cs),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    w.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.35),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (_loading)
                    SizedBox(
                      width: 100,
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                      ),
                    )
                  else ...[
                    if (score != null) _metaChip(Icons.star_rounded, score.toStringAsFixed(1), Colors.amber),
                    if (episodes != null) ...[
                      const SizedBox(height: 6),
                      _metaChip(Icons.live_tv_rounded, '$episodes 话', const Color(0xFF007AFF)),
                    ],
                    if (seasonYear != null) ...[
                      const SizedBox(height: 6),
                      _metaChip(Icons.calendar_today_rounded, '$seasonYear', const Color(0xFF5856D6)),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
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

  Widget _coverPlaceholder(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary.withValues(alpha: 0.1), cs.tertiary.withValues(alpha: 0.05)],
        ),
      ),
      child: Center(child: Icon(Icons.image_outlined, size: 24, color: cs.primary.withValues(alpha: 0.2))),
    );
  }

  Widget _tagsRow(List<String> tags) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: tags
              .map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFE8F0FE), borderRadius: BorderRadius.circular(20)),
                    child: Text(t, style: const TextStyle(fontSize: 11, color: Color(0xFF007AFF), fontWeight: FontWeight.w500)),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _summarySection(String? summary, ColorScheme cs) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('简介', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface)),
            const SizedBox(height: 8),
            if (_loading)
              SizedBox(
                width: 100,
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                ),
              )
            else if (summary == null || summary.isEmpty)
              Text('暂无简介数据', style: TextStyle(fontSize: 13.5, color: cs.onSurface.withValues(alpha: 0.35)))
            else
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Text(
                  summary,
                  maxLines: _expanded ? null : 4,
                  overflow: _expanded ? null : TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, height: 1.65, color: cs.onSurface.withValues(alpha: 0.7)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _metaSection(ColorScheme cs, String? format, String? status, int? seasonYear) {
    final rows = <MapEntry<String, String>>[
      if (format != null) MapEntry('类型', format),
      if (status != null) MapEntry('状态', _statusLabel(status)),
      if (seasonYear != null) MapEntry('年份', '$seasonYear'),
    ];
    if (rows.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('详细信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface)),
                const SizedBox(height: 12),
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 64,
                          child: Text(row.key, style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.45))),
                        ),
                        Expanded(child: Text(row.value, style: TextStyle(fontSize: 13, color: cs.onSurface))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
        'RELEASING' => '连载中',
        'FINISHED' => '已完结',
        'NOT_YET_RELEASED' => '未播出',
        'CANCELLED' => '已取消',
        'HIATUS' => '停更',
        _ => status,
      };

  Widget _bottomBar(Work w) {
    final anilistId = w.anilistId;
    final malId = w.malId;
    final hasLink = anilistId != null || malId != null;
    final label = anilistId != null ? '在 AniList 查看' : '在 MyAnimeList 查看';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        border: Border(top: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton.icon(
          onPressed: hasLink
              ? () async {
                  final uri = anilistId != null
                      ? Uri.parse('https://anilist.co/anime/$anilistId')
                      : Uri.parse('https://myanimelist.net/anime/$malId');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              : null,
          icon: const Icon(Icons.open_in_new_rounded, size: 20),
          label: Text(label),
        ),
      ),
    );
  }
}
