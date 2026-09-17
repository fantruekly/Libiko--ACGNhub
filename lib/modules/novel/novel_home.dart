import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/novel/linovelib_source.dart';
import '../../core/novel/models.dart';
import '../../core/novel/novel_favorite.dart';
import '../../core/novel/novel_history.dart';
import '../../core/novel/novel_source.dart';
import '../../core/widgets/adaptive_grid.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/chip_bar.dart';
import '../../core/widgets/pager_bar.dart';
import '../../core/widgets/ratio_cover.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../core/widgets/slide_switcher.dart';
import '../../core/widgets/smooth_route.dart';
import '../../core/widgets/tab_strip.dart';
import 'novel_detail_page.dart';
import 'novel_providers.dart';
import 'novel_reader_page.dart';

class NovelCard extends StatelessWidget {
  final Novel novel;
  final VoidCallback? onTap;
  final String? heroTag;
  const NovelCard({super.key, required this.novel, this.onTap, this.heroTag});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget image = RatioCover(
      url: novel.coverUrl,
      httpHeaders: novelImageHeaders,
      placeholderBuilder: (_) => _placeholder(cs),
      enabled: false,
    );
    if (heroTag != null) {
      image = Hero(tag: heroTag!, child: image);
    }
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: image),
          const SizedBox(height: 6),
          SizedBox(
            height: 38,
            child: Text(
              novel.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500, height: 1.45, color: cs.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(ColorScheme cs) {
    final hash = novel.title.hashCode.abs();
    const bg = [Color(0xFFF3E5F5), Color(0xFFEDE7F6), Color(0xFFE8EAF6), Color(0xFFE0F2F1)];
    return Container(
      color: bg[hash % bg.length],
      child: Center(
        child: Text(
          novel.title.isEmpty ? '书' : novel.title.characters.first,
          style: TextStyle(
              color: cs.primary.withValues(alpha: 0.2), fontSize: 28, fontWeight: FontWeight.w400),
        ),
      ),
    );
  }
}

class NovelHomePage extends ConsumerWidget {
  const NovelHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Builder(builder: (context) {
        final controller = DefaultTabController.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TabStrip(labels: ['探索', '收藏', '历史']),
            Expanded(
              child: TabBarView(
                children: [
                  _heroTab(controller, 0, const _ExploreTab()),
                  _heroTab(controller, 1, const _FavoritesTab()),
                  _heroTab(controller, 2, const _HistoryTab()),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  static Widget _heroTab(TabController controller, int index, Widget child) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) =>
          HeroMode(enabled: controller.index == index, child: child),
    );
  }
}

class _ExploreTab extends ConsumerStatefulWidget {
  const _ExploreTab();

  @override
  ConsumerState<_ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends ConsumerState<_ExploreTab>
    with AutomaticKeepAliveClientMixin {
  String _sourceId = 'linovelib';
  int _groupIndex = -1;
  int _optionIndex = 0;
  int _page = 1;
  bool? _lastHasMore;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final sources = ref.watch(novelSourcesProvider);
    final source = ref.watch(novelSourceManagerProvider).byId(_sourceId);
    final groups = source?.browseGroups ?? const <NovelBrowseGroup>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        _sourceChips(sources),
        _sectionChips(groups),
        if (_groupIndex >= 0 && _groupIndex < groups.length)
          _optionChips(groups[_groupIndex]),
        Expanded(child: _body(groups)),
      ],
    );
  }

  Widget _sourceChips(List<NovelSource> sources) {
    final labels = [for (final s in sources) s.name];
    final index = sources.indexWhere((s) => s.id == _sourceId);
    return ChipBar(
      labels: labels,
      selectedIndex: index < 0 ? 0 : index,
      onSelected: (i) => setState(() {
        _sourceId = sources[i].id;
        _groupIndex = -1;
        _optionIndex = 0;
        _page = 1;
        _lastHasMore = null;
      }),
    );
  }

  Widget _sectionChips(List<NovelBrowseGroup> groups) {
    final labels = ['推荐', for (final g in groups) g.label];
    return ChipBar(
      labels: labels,
      selectedIndex: _groupIndex + 1,
      onSelected: (i) => setState(() {
        _groupIndex = i - 1;
        _optionIndex = 0;
        _page = 1;
        _lastHasMore = null;
      }),
    );
  }

  Widget _optionChips(NovelBrowseGroup group) {
    final labels = [for (final o in group.options) o.label];
    return ChipBar(
      labels: labels,
      selectedIndex: _optionIndex,
      onSelected: (i) => setState(() {
        _optionIndex = i;
        _page = 1;
        _lastHasMore = null;
      }),
    );
  }

  Widget _body(List<NovelBrowseGroup> groups) {
    final sourceIndex =
        ref.watch(novelSourcesProvider).indexWhere((s) => s.id == _sourceId);
    if (_groupIndex < 0 || _groupIndex >= groups.length) {
      final async = ref.watch(novelHomeProvider(_sourceId));
      return Column(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: null,
              child: SlideSwitcher(
                id: (_sourceId, '__home__'),
                index: sourceIndex * 1000000,
                child: async.when(
                  loading: () => const ShimmerLoader(
                      crossAxisCount: 6,
                      mobileColumns: 3,
                      itemCount: 12,
                      aspectRatio: 0.58,
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 24)),
                  error: (_, __) => EmptyState(
                    icon: Icons.cloud_off_rounded,
                    message: '加载失败',
                    actionLabel: '重试',
                    onAction: () => ref.invalidate(novelHomeProvider(_sourceId)),
                  ),
                  data: (home) => _grid(flattenHome(home)),
                ),
              ),
            ),
          ),
        ],
      );
    }
    final group = groups[_groupIndex];
    if (group.options.isEmpty) {
      return const EmptyState(icon: Icons.menu_book_rounded, message: '暂无内容');
    }
    final option = group.options[_optionIndex.clamp(0, group.options.length - 1)];
    final async = ref.watch(novelBrowseProvider((_sourceId, option.key, _page)));
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragEnd: group.options.length > 1
                ? (details) {
                    final v = details.primaryVelocity ?? 0;
                    final delta = v < -100 ? 1 : (v > 100 ? -1 : 0);
                    if (delta == 0) return;
                    setState(() {
                      final next = (_optionIndex + delta)
                          .clamp(0, group.options.length - 1);
                      if (next == _optionIndex) return;
                      _optionIndex = next;
                      _page = 1;
                      _lastHasMore = null;
                    });
                  }
                : null,
            child: SlideSwitcher(
              id: (_sourceId, option.key, _page),
              index: sourceIndex * 1000000 +
                  (_groupIndex + 1) * 10000 +
                  _optionIndex * 100 +
                  _page,
              child: async.when(
                loading: () => const ShimmerLoader(
                    crossAxisCount: 6,
                    itemCount: 12,
                    aspectRatio: 0.58,
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 24)),
                error: (_, __) => EmptyState(
                  icon: Icons.cloud_off_rounded,
                  message: '加载失败',
                  actionLabel: '重试',
                  onAction: () => ref.invalidate(
                      novelBrowseProvider((_sourceId, option.key, _page))),
                ),
                data: (list) {
                  _lastHasMore = list.hasMore;
                  return _grid(list.items);
                },
              ),
            ),
          ),
        ),
        if (_lastHasMore != null) _pager(_lastHasMore!),
      ],
    );
  }

  Widget _pager(bool hasMore) {
    return PagerBar(
      label: '第 $_page 页',
      onPrevious: _page > 1 ? () => setState(() => _page--) : null,
      onNext: hasMore ? () => setState(() => _page++) : null,
    );
  }

  Widget _grid(List<Novel> items) {
    if (items.isEmpty) {
      return const EmptyState(icon: Icons.menu_book_rounded, message: '暂无内容');
    }
    return AdaptiveGridView(
      itemCount: items.length,
      mobileColumns: 3,
      desktopAspectRatio: 0.58,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemBuilder: (_, i) => NovelCard(
        novel: items[i],
        heroTag: 'novel_${_sourceId}_${items[i].id}',
        onTap: () => Navigator.push(
          context,
          smoothRoute(NovelDetailPage(
            sourceKey: _sourceId,
            novelId: items[i].id,
            title: items[i].title,
            cover: items[i].coverUrl,
          )),
        ),
      ),
    );
  }
}

class _FavoritesTab extends ConsumerWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(novelFavoritesProvider);
    if (favorites.isEmpty) {
      return const EmptyState(
          icon: Icons.favorite_border_rounded, message: '还没有收藏');
    }
    return AdaptiveGridView(
      itemCount: favorites.length,
      mobileColumns: 3,
      desktopAspectRatio: 0.58,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemBuilder: (_, i) => NovelCard(
        novel: Novel(
          id: favorites[i].novelId,
          title: favorites[i].title,
          coverUrl: favorites[i].cover,
        ),
        heroTag: 'novel_${favorites[i].sourceKey}_${favorites[i].novelId}',
        onTap: () => Navigator.push(
          context,
          smoothRoute(NovelDetailPage(
            sourceKey: favorites[i].sourceKey,
            novelId: favorites[i].novelId,
            title: favorites[i].title,
            cover: favorites[i].cover,
          )),
        ),
      ),
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final records = ref.watch(novelHistoryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Text('历史记录',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                      height: 1.4)),
              const Spacer(),
              TextButton(
                onPressed:
                    records.isEmpty ? null : () => _confirmClear(context, ref),
                child: const Text('清空历史'),
              ),
            ],
          ),
        ),
        Expanded(
          child: records.isEmpty
              ? const EmptyState(
                  icon: Icons.history_rounded, message: '还没有阅读记录')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: records.length,
                  itemBuilder: (_, i) => _historyRow(context, records[i]),
                ),
        ),
      ],
    );
  }
}

Widget _historyRow(BuildContext context, NovelHistoryEntry entry) {
  final cs = Theme.of(context).colorScheme;
  return InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: () => Navigator.push(
      context,
      smoothRoute(NovelReaderPage(
        sourceKey: entry.sourceKey,
        novelId: entry.novelId,
        chapterId: entry.chapterId,
        title: entry.title,
        cover: entry.cover,
      )),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56,
              height: 76,
              child: _cover(entry.cover, cs),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500, color: cs.onSurface),
                ),
                const SizedBox(height: 6),
                Text(
                  '读到 ${entry.chapterTitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  _relativeTime(entry.updatedAt),
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _cover(String? url, ColorScheme cs) {
  if (url == null || url.isEmpty) {
    return Container(color: cs.outlineVariant);
  }
  return CachedNetworkImage(
    imageUrl: url,
    fit: BoxFit.cover,
    memCacheWidth: 200,
    httpHeaders: novelImageHeaders,
    placeholder: (_, __) => Container(color: cs.outlineVariant),
    errorWidget: (_, __, ___) => Container(color: cs.outlineVariant),
  );
}

Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('清空历史记录？'),
      content: const Text('将删除全部阅读记录，且不可恢复。'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空')),
      ],
    ),
  );
  if (confirmed != true) return;
  await ref.read(novelHistoryProvider.notifier).clear();
}

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
  if (diff.inHours < 24) return '${diff.inHours} 小时前';
  if (diff.inDays < 30) return '${diff.inDays} 天前';
  final local = time.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}
