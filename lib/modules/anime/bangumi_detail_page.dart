import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/models/work.dart';
import '../../core/models/chapter.dart';
import 'bangumi_service.dart';
import 'anime_providers.dart';
import 'anime_player.dart';
import 'anime_source.dart';

class BangumiDetailPage extends ConsumerStatefulWidget {
  final Work work;

  const BangumiDetailPage({super.key, required this.work});

  @override
  ConsumerState<BangumiDetailPage> createState() => _BangumiDetailPageState();
}

class _BangumiDetailPageState extends ConsumerState<BangumiDetailPage> {
  Map<String, dynamic>? _detail;
  List<Chapter> _episodes = [];
  String _episodeStatus = 'loading';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadDetail(), _loadEpisodes()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadDetail() async {
    final bangumiId = widget.work.extra['bangumiId'] as int?;
    if (bangumiId == null) return;
    final service = ref.read(bangumiServiceProvider);
    final detail = await service.getSubjectDetail(bangumiId);
    if (mounted) setState(() => _detail = detail);
  }

  Future<void> _loadEpisodes() async {
    final keyword = widget.work.extra['keyword'] as String? ?? widget.work.title;
    final manager = ref.read(sourceManagerProvider);
    final sources = manager.getByType(WorkType.anime);

    for (final source in sources) {
      if (source is AnimeSource) {
        try {
          final result = await source.search(keyword, page: 1).timeout(const Duration(seconds: 8));
          if (result.works.isNotEmpty) {
            final bestMatch = result.works.first;
            final link = bestMatch.extra['link'] as String? ?? '';
            if (link.isNotEmpty) {
              final chapters = await source.fetchChapters('${bestMatch.id}|$link').timeout(const Duration(seconds: 8));
              if (chapters.isNotEmpty && mounted) {
                setState(() {
                  _episodes = chapters;
                  _episodeStatus = 'loaded';
                });
                return;
              }
            }
          }
        } catch (_) {}
      }
    }
    if (mounted) setState(() => _episodeStatus = 'empty');
  }

  @override
  Widget build(BuildContext context) {
    final work = widget.work;
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 260,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    background: work.coverUrl != null && work.coverUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: work.coverUrl!,
                            fit: BoxFit.cover,
                            httpHeaders: const {
                              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                              'Referer': 'https://bgm.tv/',
                            },
                            errorWidget: (_, __, ___) => _buildGradientCover(work),
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
                        Text(work.title,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (_detail != null) ...[
                          _buildInfoRow(),
                          if (_detail!['tags'] is List && (_detail!['tags'] as List).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: (_detail!['tags'] as List)
                                    .map((t) => Chip(
                                          label: Text(t.toString(), style: const TextStyle(fontSize: 11)),
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: VisualDensity.compact,
                                        ))
                                    .toList(),
                              ),
                            ),
                        ],
                        if (work.summary != null && work.summary!.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const Text('简介', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(work.summary!, style: const TextStyle(fontSize: 14, height: 1.5)),
                        ],
                        const SizedBox(height: 24),
                        const Text('剧集', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _buildEpisodeSection(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoRow() {
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
          Text(_detail!['airDate'] as String, style: TextStyle(color: Colors.grey[500])),
        ],
      ],
    );
  }

  Widget _buildEpisodeSection() {
    if (_episodeStatus == 'loading') {
      return const Center(child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ));
    }
    if (_episodeStatus == 'empty') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.videocam_off, size: 48, color: Colors.grey[600]),
              const SizedBox(height: 12),
              Text('暂无剧集数据', style: TextStyle(color: Colors.grey[500])),
              const SizedBox(height: 8),
              Text('请尝试在搜索页面手动搜索', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _episodes.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final ep = _episodes[index];
        return ListTile(
          leading: CircleAvatar(
            radius: 18,
            child: Text('${index + 1}', style: const TextStyle(fontSize: 13)),
          ),
          title: Text(ep.title, style: const TextStyle(fontSize: 14)),
          trailing: IconButton(
            icon: const Icon(Icons.play_circle_outline, size: 32),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AnimePlayerPage(
                    chapterTitle: ep.title,
                    videoUrl: ep.url ?? '',
                  ),
                ),
              );
            },
          ),
        );
      },
    );
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
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 72,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}