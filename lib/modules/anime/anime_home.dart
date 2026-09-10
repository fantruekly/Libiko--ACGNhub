import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'anime_providers.dart';
import 'anime_search.dart';
import 'anime_detail.dart';
import '../../core/widgets/work_card.dart';
import '../../core/models/work.dart';
import '../../core/source/source_manager.dart';
import 'anime_source.dart';

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
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(trendingAnimeProvider.future),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _SectionHeader(title: trendingAsync.when(
              loading: () => '正在加载番剧...',
              error: (_, __) => '热门推荐',
              data: (d) => '新番放送',
            )),
            trendingAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => _AnimeGrid(
                works: popular,
                onTap: (work) => _searchAndNavigate(context, ref, work),
              ),
              data: (works) => works.isEmpty
                  ? _AnimeGrid(
                      works: popular,
                      onTap: (work) => _searchAndNavigate(context, ref, work),
                    )
                  : _AnimeGrid(
                      works: works,
                      onTap: (work) => _searchAndNavigate(context, ref, work),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _searchAndNavigate(BuildContext context, WidgetRef ref, Work work) async {
    final keyword = work.extra['keyword'] as String? ?? work.title;
    final manager = ref.read(sourceManagerProvider);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final sources = manager.getByType(WorkType.anime);
      Work? bestResult;

      for (final source in sources) {
        if (source is AnimeSource) {
          try {
            final result = await source.search(keyword, page: 1).timeout(const Duration(seconds: 8));
            if (result.works.isNotEmpty) {
              bestResult = result.works.first;
              break;
            }
          } catch (_) {}
        }
      }

      if (context.mounted) Navigator.of(context).pop();

      if (bestResult != null && context.mounted) {
        final result = bestResult;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AnimeDetailPage(work: result)),
        );
      } else if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AnimeSearchPage(initialKeyword: keyword),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
}

class _AnimeGrid extends StatelessWidget {
  final List<Work> works;
  final void Function(Work) onTap;

  const _AnimeGrid({required this.works, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: works.length,
      itemBuilder: (context, index) {
        final work = works[index];
        return WorkCard(work: work, onTap: () => onTap(work));
      },
    );
  }
}