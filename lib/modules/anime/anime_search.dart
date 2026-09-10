import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/work.dart';
import '../../core/widgets/work_card.dart';
import 'anime_providers.dart';
import 'bangumi_detail_page.dart';

class AnimeSearchPage extends ConsumerStatefulWidget {
  final String? initialKeyword;

  const AnimeSearchPage({super.key, this.initialKeyword});

  @override
  ConsumerState<AnimeSearchPage> createState() => _AnimeSearchPageState();
}

class _AnimeSearchPageState extends ConsumerState<AnimeSearchPage> {
  final _controller = TextEditingController();
  List<Work> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialKeyword != null) {
      _controller.text = widget.initialKeyword!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  Future<void> _search() async {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) return;

    setState(() { _loading = true; _error = null; });

    try {
      final service = ref.read(bangumiServiceProvider);
      final results = await service.searchSubject(keyword);
      setState(() {
        _results = results.map((item) => Work(
          id: 'bangumi_${item['id']}',
          sourceId: 'bangumi',
          sourceName: 'Bangumi',
          type: WorkType.anime,
          title: item['title'] as String? ?? '',
          coverUrl: item['cover'] as String?,
          summary: item['summary'] as String?,
          extra: {'bangumiId': item['id'], 'keyword': item['title']},
        )).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); _loading = false; });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: widget.initialKeyword == null,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: '搜索动漫...',
            hintStyle: TextStyle(color: Colors.white54),
            border: InputBorder.none,
          ),
          onSubmitted: (_) => _search(),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: _search),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _search, child: const Text('重试')),
                    ],
                  ),
                )
              : _results.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('输入关键词搜索动漫', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.7,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final work = _results[index];
                        return WorkCard(
                          work: work,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BangumiDetailPage(work: work),
                              ),
                            );
                          },
                        );
                      },
                    ),
    );
  }
}