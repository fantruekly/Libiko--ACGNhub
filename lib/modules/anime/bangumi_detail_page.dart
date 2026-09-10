import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/work.dart';
import '../../core/widgets/dio_image.dart';
import 'bangumi_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final bangumiId = widget.work.extra['bangumiId'] as int?;
    if (bangumiId == null) return;
    final service = ref.read(bangumiServiceProvider);
    final detail = await service.getSubjectDetail(bangumiId);
    if (mounted) setState(() => _detail = detail);
  }

  @override
  Widget build(BuildContext context) {
    final work = widget.work;
    final bangumiId = work.extra['bangumiId'] as int?;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: work.coverUrl != null && work.coverUrl!.isNotEmpty
                  ? DioImage(
                      url: work.coverUrl!,
                      fit: BoxFit.cover,
                      placeholder: () => _buildGradientCover(work),
                      errorWidget: () => _buildGradientCover(work),
                    )
                  : _buildGradientCover(work),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(work.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_detail != null) _buildMetaRow(),
                  if (_detail?['tags'] is List && (_detail!['tags'] as List).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Wrap(
                        spacing: 8, runSpacing: 4,
                        children: (_detail!['tags'] as List)
                            .map((t) => Chip(
                                  label: Text(t.toString(), style: const TextStyle(fontSize: 11)),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ))
                            .toList(),
                      ),
                    ),
                  if (work.summary != null && work.summary!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('简介', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(work.summary!, style: const TextStyle(fontSize: 14, height: 1.5)),
                  ],
                  const SizedBox(height: 28),
                  if (bangumiId != null)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.play_circle),
                        label: const Text('在网页中观看', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _openWebView(context, bangumiId),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.search),
                      label: const Text('搜索播放资源'),
                      onPressed: () {
                        final keyword = work.extra['keyword'] as String? ?? work.title;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AnimeSearchPage(initialKeyword: keyword),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow() {
    return Row(
      children: [
        if (_detail!['rating'] != null) ...[
          const Icon(Icons.star, color: Colors.amber, size: 18),
          const SizedBox(width: 4),
          Text('${(_detail!['rating'] as num).toStringAsFixed(1)}',
              style: const TextStyle(fontSize: 16, color: Colors.amber)),
          const SizedBox(width: 16),
        ],
        Icon(Icons.tv, size: 16, color: Colors.grey[400]),
        const SizedBox(width: 4),
        Text('${_detail!['eps'] ?? '?'} 话', style: TextStyle(color: Colors.grey[400])),
        if (_detail!['airDate'] != null) ...[
          const SizedBox(width: 16),
          Text(_detail!['airDate']!.toString(), style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        ],
      ],
    );
  }

  void _openWebView(BuildContext context, int bangumiId) async {
    final uri = Uri.parse('https://bgm.tv/subject/$bangumiId');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildGradientCover(Work work) {
    final hash = work.title.hashCode.abs();
    final colors = [Colors.blueGrey, Colors.teal, Colors.indigo, Colors.deepPurple];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors[hash % colors.length].withValues(alpha: 0.8),
            colors[(hash + 1) % colors.length].withValues(alpha: 0.4),
          ],
        ),
      ),
      child: Center(
        child: Text(
          work.title.isNotEmpty ? work.title.characters.first : '?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 72, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}