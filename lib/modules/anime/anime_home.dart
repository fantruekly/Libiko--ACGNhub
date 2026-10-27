import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'anime_providers.dart';
import 'anime_detail_page.dart';
import 'anime_follow.dart';
import 'anime_history.dart';
import 'anime_home_feature.dart';
import '../../core/metadata/metadata_provider.dart';
import '../../core/widgets/work_card.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/tab_strip.dart';
import '../../core/widgets/smooth_route.dart';
import '../../core/models/work.dart';
import '../../core/models/watch_record.dart';
import '../../core/services/watch_history.dart';

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
              const TabStrip(labels: ['本季新番', '热门推荐', '追番', '历史']),
              Expanded(
                child: TabBarView(
                  children: [
                    _heroTab(
                        controller, 0, const _FeedView(feed: AnimeFeed.season)),
                    _heroTab(controller, 1,
                        const _FeedView(feed: AnimeFeed.trending)),
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
  int _firstPageCount = 0;
  int _generation = 0;

  @override
  bool get wantKeepAlive => true;

  bool get _canLoadMore => _hasMore && _firstPageCount >= _perPage;

  bool _onScrollNotification(ScrollNotification n) {
    if (n.depth == 0 &&
        n.metrics.axis == Axis.vertical &&
        n is ScrollUpdateNotification &&
        n.metrics.pixels >= n.metrics.maxScrollExtent - 400 &&
        _canLoadMore &&
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
        final identities = {
          ...?ref
              .read(animeFeedProvider(widget.feed))
              .valueOrNull
              ?.map(_identity),
          ..._extra.map(_identity),
        };
        final unique =
            next.where((work) => identities.add(_identity(work))).toList();
        _extra.addAll(unique);
        _hasMore = next.length >= _perPage && unique.isNotEmpty;
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

  Future<void> _refresh() async {
    ref.read(metadataServiceProvider).invalidate('feed:${widget.feed.name}:');
    setState(() {
      _extra.clear();
      _page = 1;
      _hasMore = true;
      _loadingMore = false;
      _generation++;
    });
    ref.invalidate(animeFeedProvider(widget.feed));
    try {
      await ref.read(animeFeedProvider(widget.feed).future);
    } catch (_) {
      // The feed's error state owns the retry UI.
    }
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
    final history = ref.watch(watchHistoryProvider);

    return async.when(
      loading: () => const ShimmerLoader(),
      error: (_, __) => EmptyState(
        icon: Icons.cloud_off_rounded,
        message: '加载失败',
        actionLabel: '重试',
        onAction: () => ref.invalidate(animeFeedProvider(widget.feed)),
      ),
      data: (works) {
        _firstPageCount = works.length;
        final identities = <String>{};
        final items = [...works, ..._extra]
            .where((work) => identities.add(_identity(work)))
            .toList();
        final recent = history
            .where((record) =>
                !record.deleted &&
                !record.completed &&
                record.work.type == WorkType.anime)
            .toList()
          ..sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
        return LayoutBuilder(builder: (context, constraints) {
          final padding = constraints.maxWidth >= 900 ? 32.0 : 20.0;
          final available = constraints.maxWidth - padding * 2;
          final columns = (available / 176).floor().clamp(2, 8);
          final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
          final cardWidth = (available - (columns - 1) * 18) / columns;
          return NotificationListener<ScrollNotification>(
            onNotification: _onScrollNotification,
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                primary: false,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (items.isNotEmpty)
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(padding, 24, padding, 0),
                      sliver: SliverToBoxAdapter(
                        child: AnimeFeatureBanner(
                          work: items.first,
                          feedLabel: _label,
                          onOpen: () => _openWork(context, items.first),
                        ),
                      ),
                    ),
                  if (recent.isNotEmpty && widget.feed == AnimeFeed.season) ...[
                    _sectionTitle('继续观看', cs, padding),
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: padding),
                      sliver: SliverToBoxAdapter(
                        child: _resumeCards(
                            context, recent.take(2).toList(), available),
                      ),
                    ),
                  ],
                  _sectionTitle(_label, cs, padding),
                  items.isEmpty
                      ? SliverToBoxAdapter(
                          child: SizedBox(
                            height: 300,
                            child: EmptyState(
                                icon: Icons.live_tv_rounded, message: '暂无内容'),
                          ),
                        )
                      : SliverPadding(
                          padding: EdgeInsets.fromLTRB(padding, 0, padding, 24),
                          sliver: SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              crossAxisSpacing: 18,
                              mainAxisSpacing: 24,
                              mainAxisExtent: cardWidth * 1.5 + 48 * scale,
                            ),
                            delegate: SliverChildBuilderDelegate(
                                (_, i) => WorkCard(
                                      work: items[i],
                                      onTap: () => _openWork(context, items[i]),
                                    ),
                                childCount: items.length),
                          ),
                        ),
                  if (_canLoadMore)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Center(
                          child: _loadingMore
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: cs.primary.withValues(alpha: 0.4),
                                  ),
                                )
                              : TextButton.icon(
                                  onPressed: _loadMore,
                                  icon: const Icon(Icons.expand_more_rounded,
                                      size: 18),
                                  label: const Text('加载更多'),
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  static String _identity(Work work) => '${work.sourceId}\u0000${work.id}';

  void _openWork(BuildContext context, Work work) =>
      Navigator.push(context, smoothRoute(AnimeDetailPage(work: work)));

  Widget _resumeCards(
      BuildContext context, List<WatchRecord> records, double width) {
    Widget card(WatchRecord record) => AnimeResumeCard(
          key: ValueKey('resume-${_identity(record.work)}'),
          record: record,
          onResume: () => Navigator.push(
              context,
              smoothRoute(AnimeDetailPage(
                  work: record.work, resumeRecord: record, autoResume: true))),
        );
    if (width < 620) {
      return Column(children: [
        for (var i = 0; i < records.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          card(records[i]),
        ],
      ]);
    }
    return Row(children: [
      for (var i = 0; i < records.length; i++) ...[
        if (i > 0) const SizedBox(width: 16),
        Expanded(child: card(records[i])),
      ],
    ]);
  }

  Widget _sectionTitle(String title, ColorScheme cs, double horizontal) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(horizontal, 26, horizontal, 16),
        child: Text(
          title,
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
              height: 1.4),
        ),
      ),
    );
  }
}
