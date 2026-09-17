import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'anime_providers.dart';
import 'anime_detail_page.dart';
import 'anime_follow.dart';
import 'anime_history.dart';
import '../../core/metadata/metadata_provider.dart';
import '../../core/widgets/adaptive_grid.dart';
import '../../core/widgets/work_card.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/tab_strip.dart';
import '../../core/widgets/smooth_route.dart';
import '../../core/models/work.dart';

class AnimeHomePage extends ConsumerWidget {
  const AnimeHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Builder(
        builder: (context) {
          final controller = DefaultTabController.of(context);
          return Column(
            children: [
              const TabStrip(labels: ['本季新番', '热门推荐', '追番', '历史记录']),
              Expanded(
                child: TabBarView(
                  children: [
                    _heroTab(controller, 0, const _FeedView(feed: AnimeFeed.season)),
                    _heroTab(controller, 1, const _FeedView(feed: AnimeFeed.trending)),
                    _heroTab(controller, 2, const AnimeFollowView()),
                    _heroTab(controller, 3, const AnimeHistoryView()),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Heroes are only registered for the visible tab, so the same work mounted
  /// in two kept-alive tabs cannot collide on its `Hero` tag.
  static Widget _heroTab(TabController controller, int index, Widget child) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) =>
          HeroMode(enabled: controller.index == index, child: child),
    );
  }
}

class _FeedView extends ConsumerStatefulWidget {
  const _FeedView({required this.feed});

  final AnimeFeed feed;

  @override
  ConsumerState<_FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends ConsumerState<_FeedView>
    with AutomaticKeepAliveClientMixin {
  static const _perPage = 20;

  final List<Work> _extra = [];
  int _page = 1;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _generation = 0;

  @override
  bool get wantKeepAlive => true;

  bool _onScrollNotification(ScrollNotification n) {
    if (n.metrics.pixels >= n.metrics.maxScrollExtent - 400 &&
        _hasMore &&
        !_loadingMore) {
      _loadMore();
    }
    return false;
  }

  Future<void> _loadMore() async {
    final gen = _generation;
    final nextPage = _page + 1;
    setState(() => _loadingMore = true);
    try {
      final next = await ref
          .read(metadataServiceProvider)
          .feed(widget.feed, page: nextPage);
      if (!mounted || gen != _generation) return;
      setState(() {
        _page = nextPage;
        _extra.addAll(next);
        _hasMore = next.length >= _perPage;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted && gen == _generation) {
        setState(() {
          _loadingMore = false;
          _hasMore = false;
        });
      }
    }
  }

  void _refresh() {
    ref.read(metadataServiceProvider).invalidate('feed:${widget.feed.name}:');
    setState(() {
      _extra.clear();
      _page = 1;
      _hasMore = true;
      _loadingMore = false;
      _generation++;
    });
    ref.invalidate(animeFeedProvider(widget.feed));
  }

  String get _label => switch (widget.feed) {
        AnimeFeed.trending => '热门推荐',
        AnimeFeed.season => '本季新番',
        AnimeFeed.today => '今日放送',
      };

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async = ref.watch(animeFeedProvider(widget.feed));
    final cs = Theme.of(context).colorScheme;

    return async.when(
      loading: () => const ShimmerLoader(),
      error: (_, __) => EmptyState(
        icon: Icons.cloud_off_rounded,
        message: '加载失败',
        actionLabel: '重试',
        onAction: () => ref.invalidate(animeFeedProvider(widget.feed)),
      ),
      data: (works) {
        final items = [...works, ..._extra];
        return NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: CustomScrollView(
              primary: false,
              slivers: [
                _sectionTitle(_label, cs),
                items.isEmpty
                    ? SliverToBoxAdapter(
                        child: SizedBox(
                          height: 300,
                          child: EmptyState(
                              icon: Icons.live_tv_rounded, message: '暂无内容'),
                        ),
                      )
                    : SliverAdaptiveGrid(
                        itemCount: items.length,
                        mobileColumns: 3,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemBuilder: (_, i) => WorkCard(
                          work: items[i],
                          onTap: () => Navigator.push(context,
                              smoothRoute(AnimeDetailPage(work: items[i]))),
                        ),
                      ),
                if (_hasMore)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.primary.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title, ColorScheme cs) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Text(
          title,
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
              height: 1.4),
        ),
      ),
    );
  }
}
