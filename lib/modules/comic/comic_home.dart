import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/comic/comic_favorite.dart';
import '../../core/comic/comic_history.dart';
import '../../core/comic/comic_source.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../core/widgets/smooth_route.dart';
import 'comic_detail_page.dart';
import 'comic_providers.dart';
import 'comic_reader_page.dart';
import 'comic_source_page.dart';

const _accent = Color(0xFF007AFF);
const _muted = Color(0xFF8E8E93);

class ComicHomePage extends ConsumerStatefulWidget {
  const ComicHomePage({super.key});

  @override
  ConsumerState<ComicHomePage> createState() => _ComicHomePageState();
}

class _ComicHomePageState extends ConsumerState<ComicHomePage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Builder(
        builder: (context) {
          final controller = DefaultTabController.of(context);
          return Column(
            children: [
              const TabBar(
                labelColor: _accent,
                unselectedLabelColor: _muted,
                indicatorColor: _accent,
                dividerColor: Color(0xFFE5E5EA),
                tabs: [Tab(text: '发现'), Tab(text: '收藏'), Tab(text: '历史')],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _heroTab(controller, 0, const _DiscoverTab()),
                    _heroTab(controller, 1, const _FavoritesTab()),
                    _heroTab(controller, 2, const _HistoryTab()),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Heroes are only registered for the visible tab, so the same comic mounted
  /// in two kept-alive tabs cannot collide on its `Hero` tag.
  static Widget _heroTab(TabController controller, int index, Widget child) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) =>
          HeroMode(enabled: controller.index == index, child: child),
    );
  }
}

class _DiscoverTab extends ConsumerStatefulWidget {
  const _DiscoverTab();

  @override
  ConsumerState<_DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends ConsumerState<_DiscoverTab>
    with AutomaticKeepAliveClientMixin {
  String? _selectedKey;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final sourcesAsync = ref.watch(comicSourcesProvider);

    return sourcesAsync.when(
      loading: () => const ShimmerLoader(crossAxisCount: 6),
      error: (_, __) => EmptyState(
        icon: Icons.cloud_off_rounded,
        message: '加载失败',
        actionLabel: '重试',
        onAction: () => ref.invalidate(comicSourcesProvider),
      ),
      data: (sources) {
        if (sources.isEmpty) {
          return EmptyState(
            icon: Icons.extension_off_rounded,
            message: '还没有添加漫画源',
            actionLabel: '添加源',
            onAction: () => _openSources(context),
          );
        }
        final selected = sources.firstWhere(
          (s) => s.key == _selectedKey,
          orElse: () => sources.first,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sourceHeader(sources, selected),
            Expanded(child: _explore(selected.key)),
          ],
        );
      },
    );
  }

  void _openSources(BuildContext context) {
    Navigator.push(context, smoothRoute(const ComicSourcePage()));
  }

  Widget _sourceHeader(List<ComicSource> sources, ComicSource selected) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
              child: Row(
                children: [
                  for (final source in sources)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child:
                          _sourceChip(source, source.key == selected.key),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: '源管理',
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => _openSources(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _sourceChip(ComicSource source, bool selected) {
    return ChoiceChip(
      label: Text(source.name),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => setState(() => _selectedKey = source.key),
      selectedColor: _accent,
      backgroundColor: const Color(0xFFF2F2F7),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: selected ? Colors.white : _muted,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _explore(String sourceKey) {
    final async = ref.watch(comicExploreProvider(sourceKey));
    return async.when(
      loading: () => const ShimmerLoader(
        crossAxisCount: 6,
        itemCount: 12,
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
      ),
      error: (_, __) => EmptyState(
        icon: Icons.cloud_off_rounded,
        message: '加载失败',
        actionLabel: '重试',
        onAction: () => ref.invalidate(comicExploreProvider(sourceKey)),
      ),
      data: (comics) {
        if (comics.isEmpty) {
          return const EmptyState(
              icon: Icons.image_not_supported_rounded, message: '暂无内容');
        }
        return _comicGrid(
          count: comics.length,
          itemBuilder: (i) => ComicCard(
            title: comics[i].title,
            cover: comics[i].cover,
            heroTag: 'comic_${sourceKey}_${comics[i].id}',
            onTap: () => Navigator.push(
              context,
              smoothRoute(ComicDetailPage(
                sourceKey: sourceKey,
                comicId: comics[i].id,
                title: comics[i].title,
                cover: comics[i].cover,
              )),
            ),
          ),
        );
      },
    );
  }
}

class _FavoritesTab extends ConsumerWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(comicFavoritesProvider);
    if (favorites.isEmpty) {
      return const EmptyState(
          icon: Icons.favorite_border_rounded, message: '还没有收藏');
    }
    return _comicGrid(
      count: favorites.length,
      itemBuilder: (i) => ComicCard(
        title: favorites[i].title,
        cover: favorites[i].cover,
        heroTag: 'comic_${favorites[i].sourceKey}_${favorites[i].comicId}',
        onTap: () => Navigator.push(
          context,
          smoothRoute(ComicDetailPage(
            sourceKey: favorites[i].sourceKey,
            comicId: favorites[i].comicId,
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
    final records = ref.watch(comicHistoryProvider);
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Text(
                '历史记录',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                    height: 1.4),
              ),
              const Spacer(),
              TextButton(
                onPressed: records.isEmpty
                    ? null
                    : () => _confirmClear(context, ref),
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

Widget _historyRow(BuildContext context, ComicHistoryEntry entry) {
  final cs = Theme.of(context).colorScheme;
  return InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: () => Navigator.push(
      context,
      smoothRoute(ComicReaderPage(
        sourceKey: entry.sourceKey,
        comicId: entry.comicId,
        chapterId: entry.chapterId,
        initialPage: entry.page,
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
              child: _cover(entry.cover),
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
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface),
                ),
                const SizedBox(height: 6),
                Text(
                  '看到 ${entry.chapterTitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
                const SizedBox(height: 4),
                Text(
                  _relativeTime(entry.readAt),
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
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
  await ref.read(comicHistoryProvider.notifier).clear();
}

Widget _comicGrid({
  required int count,
  required Widget Function(int) itemBuilder,
}) {
  return GridView.builder(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 6,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 0.66,
    ),
    itemCount: count,
    itemBuilder: (_, i) => itemBuilder(i),
  );
}

Widget _cover(String? url) {
  if (url == null || url.isEmpty) {
    return Container(color: const Color(0xFFE5E5EA));
  }
  return CachedNetworkImage(
    imageUrl: url,
    fit: BoxFit.cover,
    memCacheWidth: 200,
    placeholder: (_, __) => Container(color: const Color(0xFFE5E5EA)),
    errorWidget: (_, __, ___) => Container(color: const Color(0xFFE5E5EA)),
  );
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

class ComicCard extends StatelessWidget {
  final String title;
  final String? cover;
  final String? heroTag;
  final VoidCallback? onTap;

  const ComicCard({
    super.key,
    required this.title,
    this.cover,
    this.heroTag,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget image = RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: cover != null && cover!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: cover!,
                fit: BoxFit.cover,
                memCacheWidth: 400,
                fadeInDuration: const Duration(milliseconds: 200),
                placeholder: (_, __) => _placeholder(),
                errorWidget: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
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
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.45,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    final hash = title.hashCode.abs();
    final bgColors = const [
      Color(0xFFF3E5F5),
      Color(0xFFEDE7F6),
      Color(0xFFE8EAF6),
      Color(0xFFE0F2F1),
    ];
    return Container(
      color: bgColors[hash % bgColors.length],
      child: Center(
        child: Text(
          title.isEmpty ? '?' : title.characters.first,
          style: TextStyle(
              color: _accent.withValues(alpha: 0.2),
              fontSize: 28,
              fontWeight: FontWeight.w400),
        ),
      ),
    );
  }
}
