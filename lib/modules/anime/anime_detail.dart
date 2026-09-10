import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/models/work.dart';
import '../../core/models/chapter.dart';
import '../../core/source/source_manager.dart';
import 'anime_player.dart';
import 'anime_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AnimeDetailPage extends ConsumerStatefulWidget {
  final Work work;

  const AnimeDetailPage({super.key, required this.work});

  @override
  ConsumerState<AnimeDetailPage> createState() => _AnimeDetailPageState();
}

class _AnimeDetailPageState extends ConsumerState<AnimeDetailPage> {
  List<Chapter> _chapters = [];
  bool _loadingChapters = false;

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    setState(() => _loadingChapters = true);
    try {
      final manager = ref.read(sourceManagerProvider);
      final adapter = manager.getById(widget.work.sourceId);
      if (adapter != null) {
        final link = widget.work.extra['link'] as String? ?? '';
        final workIdWithLink = '${widget.work.id}|$link';
        final chapters = await adapter.fetchChapters(workIdWithLink);
        setState(() {
          _chapters = chapters;
          _loadingChapters = false;
        });
      } else {
        setState(() => _loadingChapters = false);
      }
    } catch (e) {
      setState(() => _loadingChapters = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final work = widget.work;
    return Scaffold(
      appBar: AppBar(title: Text(work.title)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (work.coverUrl != null)
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
                  Text(work.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (work.author != null)
                    Text('作者: ${work.author}', style: TextStyle(color: Colors.grey[400])),
                  const SizedBox(height: 4),
                  Text('来源: ${work.sourceName}', style: TextStyle(color: Colors.grey[500])),
                  if (work.tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: work.tags.map((tag) => Chip(
                            label: Text(tag, style: const TextStyle(fontSize: 12)),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          )).toList(),
                    ),
                  ],
                  if (work.summary != null && work.summary!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('简介', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(work.summary!, style: const TextStyle(fontSize: 14, height: 1.5)),
                  ],
                  const SizedBox(height: 24),
                  const Text('剧集列表', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_loadingChapters)
                    const Center(child: CircularProgressIndicator())
                  else if (_chapters.isEmpty)
                    const Text('暂无剧集信息', style: TextStyle(color: Colors.grey))
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _chapters.length,
                      itemBuilder: (context, index) {
                        final ch = _chapters[index];
                        return ListTile(
                          leading: CircleAvatar(child: Text('${index + 1}')),
                          title: Text(ch.title),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AnimePlayerPage(
                                  chapterTitle: ch.title,
                                  videoUrl: ch.url ?? '',
                                ),
                              ),
                            );
                          },
                        );
                      },
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