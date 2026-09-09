import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'anime_providers.dart';
import 'anime_search.dart';

class AnimeHomePage extends ConsumerWidget {
  const AnimeHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourcesAsync = ref.watch(animeSourceListProvider);

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
      body: sourcesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('加载失败: $err')),
        data: (sources) {
          if (sources.isEmpty) {
            return const Center(child: Text('没有可用的动漫源'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(animeSourceListProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  '已加载的动漫源',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...sources.map((s) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.tv),
                        title: Text(s.name),
                        subtitle: Text(s.baseUrl),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    )),
                const SizedBox(height: 24),
                const Text(
                  '使用搜索查找你想看的动漫',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}