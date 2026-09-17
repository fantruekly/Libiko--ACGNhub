import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/comic/comic_favorite.dart';
import '../../core/comic/comic_history.dart';
import '../../core/comic/comic_source.dart';
import '../../core/comic/explore_result.dart';
import '../../core/platform.dart';
import '../../core/widgets/adaptive_grid.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/chip_bar.dart';
import '../../core/widgets/ratio_cover.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../core/widgets/slide_switcher.dart';
import '../../core/widgets/smooth_route.dart';
import '../../core/widgets/tab_strip.dart';
import 'comic_detail_page.dart';
import 'comic_providers.dart';
import 'comic_reader_page.dart';
import 'comic_source_page.dart';

const _accent = Color(0xFF007AFF);
const _muted = Color(0xFF5A5A5F);

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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TabStrip(labels: ['发现', '收藏', '历史']),
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
  int _selectedSection = 0;
  int _selectedPart = 0;
  int _page = 1;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final sourcesAsync = ref.watch(comicSourcesProvider);

    return sourcesAsync.when(
      loading: () => const ShimmerLoader(crossAxisCount: 6, mobileColumns: 3),
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
        final section = selected.sections.isEmpty
            ? 0
            : _selectedSection.clamp(0, selected.sections.length - 1);
        final meta = section < selected.sections.length
            ? selected.sections[section]
            : null;
        final clientPaged =
            meta?.usesLoadNext != true && meta?.type != 'multiPageComicList';
        final parts = clientPaged
            ? (ref
                    .watch(comicExploreAllProvider((selected.key, section)))
                    .valueOrNull
                    ?.parts ??
                const <ComicPart>[])
            : const <ComicPart>[];
        final part = parts.isEmpty ? 0 : _selectedPart.clamp(0, parts.length - 1);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sourceHeader(sources, selected),
            _sectionChips(selected, section),
            if (parts.length > 1) _partChips(parts, part),
            Expanded(child: _explore(selected, section, part, sources.indexOf(selected))),
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
            child: ChipBar(
              labels: [for (final source in sources) source.name],
              selectedIndex: sources.indexOf(selected),
              onSelected: (i) {
                final source = sources[i];
                setState(() {
                  _selectedKey = source.key;
                  _selectedSection = 0;
                  _selectedPart = 0;
                  _page = 1;
                });
              },
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

  Widget _sectionChips(ComicSource source, int section) {
    if (source.sections.length <= 1) return const SizedBox.shrink();
    final labels = [
      for (var i = 0; i < source.sections.length; i++)
        source.sections[i].title.isEmpty
            ? '分区 ${i + 1}'
            : source.sections[i].title,
    ];
    return ChipBar(
      labels: labels,
      selectedIndex: section,
      onSelected: (i) => setState(() {
        _selectedSection = i;
        _selectedPart = 0;
        _page = 1;
      }),
    );
  }

  Widget _partChips(List<ComicPart> parts, int selected) {
    final labels = [
      for (var i = 0; i < parts.length; i++)
        parts[i].title.isEmpty ? '分区 ${i + 1}' : parts[i].title,
    ];
    return ChipBar(
      labels: labels,
      selectedIndex: selected,
      onSelected: (i) => setState(() {
        _selectedPart = i;
        _page = 1;
      }),
    );
  }

  Widget _explore(ComicSource source, int section, int part, int sourceIndex) {
    final async = ref
        .watch(comicExploreProvider((source.key, section, part, _page)));
    final pageData = async.valueOrNull;

    if (pageData != null &&
        pageData.maxPage != null &&
        _page > pageData.maxPage!) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _page = pageData.maxPage!);
      });
    }

    return Column(
      children: [
        Expanded(
          child: SlideSwitcher(
            id: (source.key, section, part, _page),
            index: sourceIndex * 1000000 +
                section * 10000 +
                part * 100 +
                _page,
            child: async.when(
              loading: () => const ShimmerLoader(
                crossAxisCount: 6,
                mobileColumns: 3,
                itemCount: 12,
                padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
              ),
              error: (_, __) => EmptyState(
                icon: Icons.cloud_off_rounded,
                message: '加载失败',
                actionLabel: '重试',
                onAction: () {
                  clearExploreCache(source.key, section);
                  ref.invalidate(comicSourcePageProvider);
                  ref.invalidate(
                      comicExploreAllProvider((source.key, section)));
                  ref.invalidate(comicExploreProvider(
                      (source.key, section, part, _page)));
                },
              ),
              data: (data) {
                if (data.comics.isEmpty) {
                  return const EmptyState(
                      icon: Icons.image_not_supported_rounded, message: '暂无内容');
                }
                return _comicGrid(
                  count: data.comics.length,
                  itemBuilder: (i) => ComicCard(
                    title: data.comics[i].title,
                    cover: data.comics[i].cover,
                    heroTag: 'comic_${source.key}_${data.comics[i].id}',
                    onTap: () => Navigator.push(
                      context,
                      smoothRoute(ComicDetailPage(
                        sourceKey: source.key,
                        comicId: data.comics[i].id,
                        title: data.comics[i].title,
                        cover: data.comics[i].cover,
                      )),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (pageData != null && (pageData.hasNext || pageData.page > 1))
          _paginationBar(pageData),
      ],
    );
  }

  Widget _paginationBar(ComicExplorePage data) {
    final label = data.maxPage == null
        ? '第 ${data.page} 页'
        : '第 ${data.page} / ${data.maxPage} 页';
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: '上一页',
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed:
                data.page > 1 ? () => setState(() => _page = data.page - 1) : null,
          ),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(fontSize: 13, color: _muted)),
          const SizedBox(width: 16),
          IconButton(
            tooltip: '下一页',
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: data.hasNext
                ? () => setState(() => _page = data.page + 1)
                : null,
          ),
        ],
      ),
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
  return AdaptiveGridView(
    itemCount: count,
    mobileColumns: 3,
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
    Widget image = RatioCover(
      url: cover,
      placeholderBuilder: (_) => _placeholder(),
      fadeInDuration: const Duration(milliseconds: 200),
    );
    if (heroTag != null) {
      image = Hero(tag: heroTag!, child: image);
    }

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isDesktop) Expanded(child: image) else image,
          const SizedBox(height: 6),
          SizedBox(
            height: 38,
            child: Text(
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
