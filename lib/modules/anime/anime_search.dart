import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/work.dart';
import '../../core/services/search_engine.dart';
import '../../core/widgets/work_card.dart';
import 'anime_providers.dart';
import 'anime_detail.dart';

class AnimeSearchPage extends ConsumerStatefulWidget {
  const AnimeSearchPage({super.key});

  @override
  ConsumerState<AnimeSearchPage> createState() => _AnimeSearchPageState();
}

class _AnimeSearchPageState extends ConsumerState<AnimeSearchPage> {
  final _controller = TextEditingController();
  List<Work> _results = [];
  bool _loading = false;
  String? _error;

  Future<void> _search() async {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final manager = ref.read(sourceManagerProvider);
      final engine = SearchEngine(manager);
      final results = await engine.getAggregatedResults(WorkType.anime, keyword);
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
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
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '搜索动漫...',
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
                  ? const Center(child: Text('输入关键词搜索动漫'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.65,
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
                                builder: (_) => AnimeDetailPage(work: work),
                              ),
                            );
                          },
                        );
                      },
                    ),
    );
  }
}