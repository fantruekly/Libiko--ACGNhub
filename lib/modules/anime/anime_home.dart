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
  static const _pageSize = 18;
  final _scrollController = ScrollController();
  List<Work> _allWorks = [];
  List<Work> _displayed = [];
  bool _hasMore = true;

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
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && _hasMore) {
      _loadMore();
    }
  }

  void _loadMore() {
    final start = _displayed.length;
    final end = (start + _pageSize).clamp(0, _allWorks.length);
    if (start < end) {
      setState(() {
        _displayed.addAll(_allWorks.sublist(start, end));
        _hasMore = end < _allWorks.length;
      });
    }
  }

  void _initWorks(List<Work> works) {
    if (_allWorks.isEmpty && works.isNotEmpty) {
      _allWorks = works;
      _displayed = works.take(_pageSize).toList();
      _hasMore = works.length > _pageSize;
    }
  }

  @override
  Widget build(BuildContext context) {
    final trendingAsync = ref.watch(trendingAnimeProvider);

    return Scaffold(
      body: trendingAsync.when(
        loading: () => const _LoadingView(),
        error: (_, __) => const _ErrorView(),
        data: (works) {
          if (works.isEmpty) return const _ErrorView();
          _initWorks(works);
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
                SliverAppBar(
                  floating: true,
                  title: const Text('番剧', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
                  centerTitle: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnimeSearchPage())),
                    ),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(8),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.62,
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
                if (_hasMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          title: const Text('番剧', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
          centerTitle: false,
          actions: [IconButton(icon: const Icon(Icons.search), onPressed: () {})],
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 4),
            child: LinearProgressIndicator(minHeight: 3),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          title: const Text('番剧', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
          centerTitle: false,
        ),
        const SliverToBoxAdapter(
          child: SizedBox(
            height: 400,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('暂无数据', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}