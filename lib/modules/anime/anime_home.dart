import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'anime_providers.dart';
import 'anime_search.dart';
import 'bangumi_detail_page.dart';
import '../../core/widgets/work_card.dart';
import '../../core/models/work.dart';

class AnimeHomePage extends ConsumerWidget {
  const AnimeHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendingAsync = ref.watch(trendingAnimeProvider);
    final popular = ref.watch(popularAnimeProvider);

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
      body: trendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _buildContent(context, popular, ref),
        data: (works) => _buildContent(context, works.isEmpty ? popular : works, ref),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<Work> works, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.refresh(trendingAnimeProvider.future),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Text('新番放送', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.7,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: works.length,
              itemBuilder: (context, index) {
                final work = works[index];
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
          ),
        ],
      ),
    );
  }
}