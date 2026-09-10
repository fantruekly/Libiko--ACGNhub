import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'anime_providers.dart';
import 'anime_detail_page.dart';
import '../../core/metadata/metadata_provider.dart';
import '../../core/widgets/work_card.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/models/work.dart';

class AnimeHomePage extends ConsumerStatefulWidget {
  const AnimeHomePage({super.key});

  @override
  ConsumerState<AnimeHomePage> createState() => _AnimeHomePageState();
}

class _AnimeHomePageState extends ConsumerState<AnimeHomePage> {
  static const _accent = Color(0xFF007AFF);
  static const _perPage = 25;

  AnimeFeed _feed = AnimeFeed.trending;
  final _scroll = ScrollController();
  final List<Work> _extra = [];
  int _page = 1;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400 && _hasMore && !_loadingMore) {
      _loadMore();
    }
  }

  void _selectFeed(AnimeFeed feed) {
    if (_feed == feed) return;
    setState(() {
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
      final next = await ref.read(metadataServiceProvider).feed(feed, page: nextPage);
      if (!mounted || gen != _generation) return;
      setState(() {
        _page = nextPage;
        _extra.addAll(next);
        _hasMore = next.length >= _perPage;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted && gen == _generation) {
        setState(() { _loadingMore = false; _hasMore = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(animeFeedProvider(_feed));
    final cs = Theme.of(context).colorScheme;

    return async.when(
      loading: () => const ShimmerLoader(),
      error: (_, __) => EmptyState(
        icon: Icons.cloud_off_rounded,
        message: '加载失败',
        actionLabel: '重试',
        onAction: () => ref.invalidate(animeFeedProvider(_feed)),
      ),
      data: (works) {
        final items = [...works, ..._extra];
        return RefreshIndicator(
          onRefresh: () async {
            ref.read(metadataServiceProvider).invalidate('feed:${_feed.name}:');
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
            controller: _scroll,
            slivers: [
              if (items.isNotEmpty) _hero(items.first),
              _pills(),
              _sectionTitle(_label, cs),
              items.isEmpty
                  ? SliverToBoxAdapter(
                      child: SizedBox(
                        height: 300,
                        child: EmptyState(icon: Icons.live_tv_rounded, message: '暂无内容'),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                                    MaterialPageRoute(builder: (_) => AnimeDetailPage(work: items[i])),
                                  ),
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
        );
      },
    );
  }

  String get _label => switch (_feed) {
        AnimeFeed.trending => '热门推荐',
        AnimeFeed.season => '本季新番',
        AnimeFeed.today => '今日放送',
      };

  Widget _hero(Work work) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AnimeDetailPage(work: work)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 240,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (work.coverUrl != null && work.coverUrl!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: work.coverUrl!,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 300),
                      errorWidget: (_, __, ___) => Container(color: const Color(0xFF1C1C1E)),
                    )
                  else
                    Container(color: const Color(0xFF1C1C1E)),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                          stops: const [0.5, 1],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          work.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          work.sourceName,
                          style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7)),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 36,
                          child: FilledButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => AnimeDetailPage(work: work)),
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(120, 36),
                              backgroundColor: _accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('查看详情', style: TextStyle(fontSize: 14)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pills() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          children: [
            _pill('热门推荐', AnimeFeed.trending),
            const SizedBox(width: 8),
            _pill('本季新番', AnimeFeed.season),
            const SizedBox(width: 8),
            _pill('今日放送', AnimeFeed.today),
          ],
        ),
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
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Text(
          title,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: cs.onSurface, height: 1.4),
        ),
      ),
    );
  }
}
