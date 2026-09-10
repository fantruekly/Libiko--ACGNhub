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
  static const _pageSize = 24;
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
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300 && _hasMore) {
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: trendingAsync.when(
        loading: () => _LoadingView(colorScheme: colorScheme),
        error: (_, __) => _ErrorView(colorScheme: colorScheme),
        data: (works) {
          if (works.isEmpty) return _ErrorView(colorScheme: colorScheme);
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
                _buildHeader(colorScheme),
                _buildIntro(works, colorScheme),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
                  sliver: _displayed.isEmpty
                      ? const SliverToBoxAdapter()
                      : SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 6,
                            childAspectRatio: 0.66,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              if (index >= _displayed.length) return null;
                              return WorkCard(
                                work: _displayed[index],
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => BangumiDetailPage(work: _displayed[index])),
                                ),
                              );
                            },
                            childCount: _displayed.length,
                          ),
                        ),
                ),
                if (_hasMore)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: Center(
                        child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary.withValues(alpha: 0.4)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return SliverAppBar(
      floating: true,
      title: Text(
        'ACGNhub',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22, color: colorScheme.primary, letterSpacing: -0.5),
      ),
      centerTitle: false,
      actions: [
        IconButton(
          icon: Icon(Icons.search_rounded, color: colorScheme.onSurface.withValues(alpha: 0.6)),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnimeSearchPage())),
        ),
      ],
    );
  }

  Widget _buildIntro(List<Work> works, ColorScheme colorScheme) {
    final featured = works.take(3).toList();

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Container(
                  width: 5, height: 20,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: LinearGradient(
                      colors: [colorScheme.primary, colorScheme.tertiary],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '今日放送',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: colorScheme.primary.withValues(alpha: 0.1),
                  ),
                  child: Text('${works.length}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colorScheme.primary)),
                ),
                const Spacer(),
                Text(
                  '下拉刷新',
                  style: TextStyle(fontSize: 10, color: colorScheme.onSurface.withValues(alpha: 0.25)),
                ),
              ],
            ),
            // Featured mini-cards
            const SizedBox(height: 8),
            SizedBox(
              height: 58,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: featured.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final w = featured[index];
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => BangumiDetailPage(work: w)),
                    ),
                    child: Container(
                      width: 220,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: colorScheme.surface,
                        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.06)),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              width: 34, height: 46,
                              child: w.coverUrl != null && w.coverUrl!.isNotEmpty
                                  ? Image.network(
                                      w.coverUrl!,
                                      fit: BoxFit.cover,
                                      headers: const {'User-Agent': 'Mozilla/5.0', 'Referer': 'https://bgm.tv/'},
                                      errorBuilder: (_, __, ___) => _miniPlaceholder(colorScheme),
                                    )
                                  : _miniPlaceholder(colorScheme),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  w.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: colorScheme.onSurface, height: 1.3),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '查看详情 >',
                                  style: TextStyle(fontSize: 9, color: colorScheme.primary.withValues(alpha: 0.6)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniPlaceholder(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.1),
      ),
      child: Icon(Icons.image_outlined, color: colorScheme.primary.withValues(alpha: 0.3), size: 16),
    );
  }

  Widget _buildStats(List<Work> works, ColorScheme colorScheme) {
    final todayNames = <String>['日', '一', '二', '三', '四', '五', '六'];
    final today = DateTime.now().weekday;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Text(
              '本周${todayNames[today % 7]}放送',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colorScheme.onSurface, letterSpacing: -0.3),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: colorScheme.primary.withValues(alpha: 0.1),
              ),
              child: Text(
                '${works.length}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.primary),
              ),
            ),
            const Spacer(),
            Text(
              '点击卡片查看详情',
              style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.3)),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  final ColorScheme colorScheme;
  const _LoadingView({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          title: Text('ACGNhub', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22, color: colorScheme.primary)),
          centerTitle: false,
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: LinearProgressIndicator(minHeight: 2, color: colorScheme.primary),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final ColorScheme colorScheme;
  const _ErrorView({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          title: Text('ACGNhub', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22, color: colorScheme.primary)),
          centerTitle: false,
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 400,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off_rounded, size: 40, color: colorScheme.onSurface.withValues(alpha: 0.15)),
                  const SizedBox(height: 12),
                  Text('暂无数据', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.3), fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}