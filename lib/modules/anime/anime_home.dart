import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'anime_providers.dart';
import 'anime_search.dart';
import 'anime_detail.dart';
import '../../core/widgets/work_card.dart';

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
          if (works.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => ref.refresh(animeHomeWorksProvider.future),
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.live_tv, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('正在加载动漫列表...', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(animeHomeWorksProvider.future),
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
                        builder: (_) => AnimeDetailPage(work: work),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}