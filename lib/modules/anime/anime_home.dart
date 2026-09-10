import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'anime_providers.dart';
import 'bangumi_detail_page.dart';
import '../../core/widgets/work_card.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/models/work.dart';

enum _Filter { watching, trending, recent }

class AnimeHomePage extends ConsumerStatefulWidget {
  const AnimeHomePage({super.key});

  @override
  ConsumerState<AnimeHomePage> createState() => _AnimeHomePageState();
}

class _AnimeHomePageState extends ConsumerState<AnimeHomePage> {
  _Filter _filter = _Filter.trending;
  List<Work> _allWorks = [];
  static const _accent = Color(0xFF007AFF);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(trendingAnimeProvider);
    final cs = Theme.of(context).colorScheme;

    return async.when(
      loading: () => const ShimmerLoader(),
            error: (_, __) => EmptyState(
              icon: Icons.cloud_off_rounded,
              message: '加载失败',
              actionLabel: '重试',
              onAction: () => ref.invalidate(trendingAnimeProvider),
            ),
            data: (works) {
              if (_allWorks.isEmpty && works.isNotEmpty) _allWorks = works;
              final displayed = _filtered;
              final feat = works.isNotEmpty ? works[0] : null;

              return RefreshIndicator(
                onRefresh: () async {
                  _allWorks = [];
                  ref.invalidate(trendingAnimeProvider);
                },
                child: CustomScrollView(
                  slivers: [
                    if (feat != null) _hero(feat),
                    _pills(),
                    _sectionTitle(_filterLabel, cs),
                    displayed.isEmpty
                        ? SliverToBoxAdapter(
                            child: SizedBox(
                              height: 300,
                              child: EmptyState(icon: Icons.live_tv_rounded, message: _emptyMsg),
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
                                (_, i) => i >= displayed.length
                                    ? null
                                    : WorkCard(
                                        work: displayed[i],
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => BangumiDetailPage(work: displayed[i])),
                                        ),
                                      ),
                                childCount: displayed.length,
                              ),
                            ),
                          ),
                  ],
                ),
              );
            },
    );
  }

  List<Work> get _filtered {
    switch (_filter) {
      case _Filter.watching:
        return _allWorks.take(10).toList();
      case _Filter.trending:
        return _allWorks;
      case _Filter.recent:
        return _allWorks.reversed.toList();
    }
  }

  String get _filterLabel {
    switch (_filter) {
      case _Filter.watching:
        return '继续观看';
      case _Filter.trending:
        return '热门推荐';
      case _Filter.recent:
        return '最近更新';
    }
  }

  String get _emptyMsg {
    switch (_filter) {
      case _Filter.watching:
        return '还没有观看记录，去发现好番吧';
      case _Filter.trending:
        return '暂无推荐内容';
      case _Filter.recent:
        return '暂无更新内容';
    }
  }

  Widget _hero(Work work) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BangumiDetailPage(work: work))),
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
                          work.sourceName.isNotEmpty ? work.sourceName : 'Bangumi',
                          style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7)),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 36,
                          child: FilledButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => BangumiDetailPage(work: work)),
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(120, 36),
                              backgroundColor: _accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('立即观看', style: TextStyle(fontSize: 14)),
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
            _pill('继续观看', _Filter.watching),
            const SizedBox(width: 8),
            _pill('热门推荐', _Filter.trending),
            const SizedBox(width: 8),
            _pill('最近更新', _Filter.recent),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, _Filter f) {
    final sel = _filter == f;
    return GestureDetector(
      onTap: () => setState(() => _filter = f),
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
        child: Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: cs.onSurface, height: 1.4)),
      ),
    );
  }
}