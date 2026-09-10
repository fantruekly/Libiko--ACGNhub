import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'anime_providers.dart';
import 'anime_search.dart';
import 'bangumi_detail_page.dart';
import '../../core/widgets/work_card.dart';
import '../../core/models/work.dart';

class AnimeHomePage extends ConsumerStatefulWidget {
  const AnimeHomePage({super.key});

  @override
  ConsumerState<AnimeHomePage> createState() => _AnimeHomePageState();
}

class _AnimeHomePageState extends ConsumerState<AnimeHomePage> {
  static const _pageSize = 15;
  final _scrollController = ScrollController();
  List<Work> _allWorks = [];
  List<Work> _displayed = [];
  bool _hasMore = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final start = _displayed.length;
    final end = (start + _pageSize).clamp(0, _allWorks.length);
    if (start < _allWorks.length) {
      _displayed.addAll(_allWorks.sublist(start, end));
      _hasMore = end < _allWorks.length;
    } else {
      _hasMore = false;
    }
    setState(() => _loadingMore = false);
  }

  void _setAllWorks(List<Work> works) {
    _allWorks = works;
    _displayed = works.take(_pageSize).toList();
    _hasMore = works.length > _pageSize;
  }

  @override
  Widget build(BuildContext context) {
    final trendingAsync = ref.watch(trendingAnimeProvider);
    final popular = ref.watch(popularAnimeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('动漫'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnimeSearchPage())),
          ),
        ],
      ),
      body: trendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _buildGrid(context, popular, ref),
        data: (works) => _buildGrid(context, works.isEmpty ? popular : works, ref),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<Work> works, WidgetRef ref) {
    if (_allWorks.isEmpty && works.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setAllWorks(works);
      });
    }

    return RefreshIndicator(
      onRefresh: () {
        _allWorks = [];
        _displayed = [];
        _hasMore = true;
        return ref.refresh(trendingAnimeProvider.future);
      },
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Text('新番放送', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.7,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index >= _displayed.length) return null;
                  final work = _displayed[index];
                  return WorkCard(
                    work: work,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => BangumiDetailPage(work: work)),
                    ),
                  );
                },
                childCount: _displayed.length,
              ),
            ),
          ),
          if (_loadingMore || _hasMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}