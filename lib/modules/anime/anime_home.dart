import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'anime_providers.dart';
import 'anime_detail_page.dart';
import '../../core/metadata/metadata_provider.dart';
import '../../core/widgets/work_card.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/smooth_route.dart';
import '../../core/models/work.dart';

class AnimeHomePage extends ConsumerStatefulWidget {
  const AnimeHomePage({super.key});

  @override
  ConsumerState<AnimeHomePage> createState() => _AnimeHomePageState();
}

class _AnimeHomePageState extends ConsumerState<AnimeHomePage> {
  static const _accent = Color(0xFF007AFF);
  static const _perPage = 25;
  static const _order = [AnimeFeed.season, AnimeFeed.trending, AnimeFeed.today];

  AnimeFeed _feed = AnimeFeed.season;
  bool _forward = true;
  final List<Work> _extra = [];
  int _page = 1;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _generation = 0;

  bool _onScrollNotification(ScrollNotification n) {
    if (n.metrics.pixels >= n.metrics.maxScrollExtent - 400 &&
        _hasMore &&
        !_loadingMore) {
      _loadMore();
    }
    return false;
  }

  void _selectFeed(AnimeFeed feed) {
    if (_feed == feed) return;
    setState(() {
      _forward = _order.indexOf(feed) > _order.indexOf(_feed);
      _feed = feed;
      _extra.clear();
      _page = 1;
      _hasMore = true;
      _loadingMore = false;
      _generation++;
    });
  }

  Future<void> _loadMore() async {
    final gen = _generation;
    final feed = _feed;
    final nextPage = _page + 1;
    setState(() => _loadingMore = true);
    try {
      final next =
          await ref.read(metadataServiceProvider).feed(feed, page: nextPage);
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

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(animeFeedProvider(_feed));
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        _pills(),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final offset = Tween<Offset>(
                begin: Offset(_forward ? 0.08 : -0.08, 0),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offset, child: child),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(_feed),
              child: async.when(
                loading: () => const ShimmerLoader(),
                error: (_, __) => EmptyState(
                  icon: Icons.cloud_off_rounded,
                  message: '加载失败',
                  actionLabel: '重试',
                  onAction: () => ref.invalidate(animeFeedProvider(_feed)),
                ),
                data: (works) {
                  final items = [...works, ..._extra];
                  return NotificationListener<ScrollNotification>(
                    onNotification: _onScrollNotification,
                    child: RefreshIndicator(
                      onRefresh: () async {
                        ref
                            .read(metadataServiceProvider)
                            .invalidate('feed:${_feed.name}:');
                        setState(() {
                          _extra.clear();
                          _page = 1;
                          _hasMore = true;
                          _loadingMore = false;
                          _generation++;
                        });
                        ref.invalidate(animeFeedProvider(_feed));
                      },
                      child: CustomScrollView(
                        primary: false,
                        slivers: [
                          _sectionTitle(_label, cs),
                          items.isEmpty
                              ? SliverToBoxAdapter(
                                  child: SizedBox(
                                    height: 300,
                                    child: EmptyState(
                                        icon: Icons.live_tv_rounded,
                                        message: '暂无内容'),
                                  ),
                                )
                              : SliverPadding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 24),
                                  sliver: SliverGrid(
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 5,
                                      mainAxisSpacing: 16,
                                      crossAxisSpacing: 16,
                                      childAspectRatio: 0.66,
                                    ),
                                    delegate: SliverChildBuilderDelegate(
                                      (_, i) => i >= items.length
                                          ? null
                                          : WorkCard(
                                              work: items[i],
                                              onTap: () => Navigator.push(
                                                  context,
                                                  smoothRoute(AnimeDetailPage(
                                                      work: items[i]))),
                                            ),
                                      childCount: items.length,
                                    ),
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
                                      color: _accent.withValues(alpha: 0.4),
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
              ),
            ),
          ),
        ),
      ],
    );
  }

  String get _label => switch (_feed) {
        AnimeFeed.trending => '热门推荐',
        AnimeFeed.season => '本季新番',
        AnimeFeed.today => '今日放送',
      };

  Widget _pills() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          _pill('本季新番', AnimeFeed.season),
          const SizedBox(width: 8),
          _pill('热门推荐', AnimeFeed.trending),
          const SizedBox(width: 8),
          _pill('今日放送', AnimeFeed.today),
        ],
      ),
    );
  }

  Widget _pill(String label, AnimeFeed feed) {
    final sel = _feed == feed;
    return GestureDetector(
      onTap: () => _selectFeed(feed),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? _accent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: sel ? null : Border.all(color: const Color(0xFFE5E5EA)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: sel ? Colors.white : const Color(0xFF8E8E93),
          ),
        ),
      ),
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
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
              height: 1.4),
        ),
      ),
    );
  }
}
