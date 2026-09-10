import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/models/work.dart';
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final bangumiId = widget.work.extra['bangumiId'] as int?;
    if (bangumiId == null) {
      setState(() => _loading = false);
      return;
    }
    final service = ref.read(bangumiServiceProvider);
    final detail = await service.getSubjectDetail(bangumiId);
    if (mounted) {
      setState(() {
        _detail = detail;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final work = widget.work;
    return Scaffold(
      appBar: AppBar(title: Text(work.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (work.coverUrl != null && work.coverUrl!.isNotEmpty)
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: CachedNetworkImage(
                        imageUrl: work.coverUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: Colors.grey[900]),
                        errorWidget: (_, __, ___) => Container(color: Colors.grey[900]),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(work.title,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (_detail != null) ...[
                          if (_detail!['rating'] != null)
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 20),
                                const SizedBox(width: 4),
                                Text('${(_detail!['rating'] as num).toStringAsFixed(1)}',
                                    style: const TextStyle(fontSize: 16, color: Colors.amber)),
                                const SizedBox(width: 8),
                                Text('共 ${_detail!['eps'] ?? '?'} 话',
                                    style: TextStyle(color: Colors.grey[400])),
                              ],
                            ),
                          if (_detail!['airDate'] != null) ...[
                            const SizedBox(height: 4),
                            Text('首播: ${_detail!['airDate']}',
                                style: TextStyle(color: Colors.grey[500])),
                          ],
                        ],
                        const SizedBox(height: 12),
                        if (_detail?['tags'] is List && (_detail!['tags'] as List).isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: (_detail!['tags'] as List)
                                .map((t) => Chip(
                                      label: Text(t.toString(), style: const TextStyle(fontSize: 12)),
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ))
                                .toList(),
                          ),
                        const SizedBox(height: 16),
                        if (work.summary != null && work.summary!.isNotEmpty) ...[
                          const Text('简介', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(work.summary!, style: const TextStyle(fontSize: 14, height: 1.5)),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}