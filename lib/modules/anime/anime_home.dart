import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'anime_providers.dart';
import 'anime_search.dart';
import 'anime_detail.dart';
import '../../core/widgets/work_card.dart';
import '../../core/models/work.dart';

class AnimeHomePage extends ConsumerWidget {
  const AnimeHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worksAsync = ref.watch(animeHomeWorksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('动漫'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AnimeSearchPage()),
              );
            },
          ),
        ],
      ),
      body: worksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text('加载失败', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(animeHomeWorksProvider),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (works) {
          final grouped = <String, List<Work>>{};
          for (final w in works) {
            grouped.putIfAbsent(w.sourceName, () => []).add(w);
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(animeHomeWorksProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final entry in grouped.entries) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.7,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: entry.value.length,
                    itemBuilder: (context, index) {
                      final work = entry.value[index];
                      return WorkCard(
                        work: work,
                        onTap: () => _onWorkTap(context, work),
                      );
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _onWorkTap(BuildContext context, Work work) {
    if (work.sourceId == 'popular') {
      final keyword = work.extra['keyword'] as String? ?? work.title;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AnimeSearchPage(initialKeyword: keyword),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AnimeDetailPage(work: work),
        ),
      );
    }
  }
}