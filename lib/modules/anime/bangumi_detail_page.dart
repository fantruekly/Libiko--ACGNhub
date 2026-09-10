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
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.work.extra['bangumiId'] as int?;
    if (id == null) {
      setState(() => _loadingDetail = false);
      return;
    }
    final d = await ref.read(bangumiServiceProvider).getSubjectDetail(id);
    if (mounted) {
      setState(() {
        _detail = d;
        _loadingDetail = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.work;
    final cs = Theme.of(context).colorScheme;
    final id = w.extra['bangumiId'] as int?;
    final rating = _detail?['rating'] as num?;
    final eps = _detail?['eps'] as int?;
    final air = _detail?['airDate'] as String?;
    final tags = (_detail?['tags'] as List<dynamic>?)?.map((t) => t.toString()).toList() ?? [];
    final cover = (_detail?['cover'] as String?) ?? w.coverUrl;
    final summary = _detail?['summary'] as String?;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Column(
        children: [
          _header(w, cs),
          Expanded(
            child: CustomScrollView(
              slivers: [
                _heroImage(cover, cs),
                _infoSection(w, cs, rating, eps, air),
                if (tags.isNotEmpty) _tagsRow(tags),
                _summarySection(summary, cs),
                _episodeSection(w, cs),
              ],
            ),
          ),
          _bottomBar(w, id),
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

  Widget _infoSection(Work w, ColorScheme cs, num? rating, int? eps, String? air) {
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
                  if (_loadingDetail)
                    SizedBox(
                      width: 100,
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                      ),
                    )
                  else ...[
                    if (rating != null) _metaChip(Icons.star_rounded, rating.toStringAsFixed(1), Colors.amber),
                    if (eps != null) ...[
                      const SizedBox(height: 6),
                      _metaChip(Icons.live_tv_rounded, '$eps 话', const Color(0xFF007AFF)),
                    ],
                    if (air != null) ...[
                      const SizedBox(height: 6),
                      _metaChip(Icons.calendar_today_rounded, air, const Color(0xFF5856D6)),
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
            if (_loadingDetail)
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

  Widget _episodeSection(Work w, ColorScheme cs) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('剧集列表', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface)),
                    const Spacer(),
                    Text('正序 ▼', style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.45))),
                  ],
                ),
                const SizedBox(height: 12),
                Text('搜索播放资源以查看剧集', style: TextStyle(fontSize: 14, color: cs.onSurface.withValues(alpha: 0.35))),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    final kw = w.extra['keyword'] as String? ?? w.title;
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AnimeSearchPage(initialKeyword: kw)),
                    );
                  },
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('搜索播放资源'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(Work w, int? id) {
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
          onPressed: id != null
              ? () async {
                  final uri = Uri.parse('https://bgm.tv/subject/$id');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              : null,
          icon: const Icon(Icons.play_circle_rounded, size: 20),
          label: const Text('在Bangumi查看'),
        ),
      ),
    );
  }
}