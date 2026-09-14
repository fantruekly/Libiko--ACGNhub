import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/novel/linovelib_source.dart';
import '../../core/novel/models.dart';
import '../../core/novel/novel_favorite.dart';
import '../../core/novel/novel_history.dart';
import '../../core/novel/novel_source.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/pill_chip.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../core/widgets/smooth_route.dart';
import '../../core/widgets/tab_strip.dart';
import 'novel_detail_page.dart';
import 'novel_providers.dart';
import 'novel_reader_page.dart';

const _accent = Color(0xFF007AFF);
const _muted = Color(0xFF5A5A5F);
const _fg = Color(0xFF1C1C1E);

class NovelCard extends StatelessWidget {
  final Novel novel;
  final VoidCallback? onTap;
  const NovelCard({super.key, required this.novel, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: novel.coverUrl != null && novel.coverUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: novel.coverUrl!,
                      fit: BoxFit.cover,
                      memCacheWidth: 400,
                      httpHeaders: novelImageHeaders,
                      placeholder: (_, __) => _placeholder(),
                      errorWidget: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 38,
            child: Text(
              novel.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500, height: 1.45, color: _fg),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    final hash = novel.title.hashCode.abs();
    const bg = [Color(0xFFF3E5F5), Color(0xFFEDE7F6), Color(0xFFE8EAF6), Color(0xFFE0F2F1)];
    return Container(
      color: bg[hash % bg.length],
      child: Center(
        child: Text(
          novel.title.isEmpty ? '书' : novel.title.characters.first,
          style: TextStyle(
              color: _accent.withValues(alpha: 0.2), fontSize: 28, fontWeight: FontWeight.w400),
        ),
      ),
    );
  }
}

class NovelHomePage extends ConsumerWidget {
  const NovelHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabStrip(labels: ['探索', '收藏', '历史']),
          Expanded(
            child: TabBarView(
              children: [_ExploreTab(), _FavoritesTab(), _HistoryTab()],
            ),
          ),
        ],
      ),
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
    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (final s in sources)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _chip(s.name, s.id == _sourceId, () => setState(() {
                  _sourceId = s.id;
                  _groupIndex = -1;
                  _optionIndex = 0;
                  _page = 1;
                })),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionChips(List<NovelBrowseGroup> groups) {
    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _chip('推荐', _groupIndex < 0, () => setState(() {
                _groupIndex = -1;
                _page = 1;
              })),
            ),
            for (var i = 0; i < groups.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _chip(groups[i].label, _groupIndex == i, () => setState(() {
                  _groupIndex = i;
                  _optionIndex = 0;
                  _page = 1;
                })),
              ),
          ],
        ),
      ),
    );
  }

  Widget _optionChips(NovelBrowseGroup group) {
    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (var i = 0; i < group.options.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _chip(group.options[i].label, _optionIndex == i, () => setState(() {
                  _optionIndex = i;
                  _page = 1;
                })),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) =>
      PillChip(label: label, selected: selected, onTap: onTap);

  Widget _body(List<NovelBrowseGroup> groups) {
    if (_groupIndex < 0 || _groupIndex >= groups.length) {
      final async = ref.watch(novelHomeProvider(_sourceId));
      return async.when(
        loading: () => const ShimmerLoader(
            crossAxisCount: 6,
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
      );
    }
    final group = groups[_groupIndex];
    if (group.options.isEmpty) {
      return const EmptyState(icon: Icons.menu_book_rounded, message: '暂无内容');
    }
    final option = group.options[_optionIndex.clamp(0, group.options.length - 1)];
    final async = ref.watch(novelBrowseProvider((_sourceId, option.key, _page)));
    return async.when(
      loading: () => const ShimmerLoader(
          crossAxisCount: 6,
          itemCount: 12,
          aspectRatio: 0.58,
          padding: EdgeInsets.fromLTRB(16, 8, 16, 24)),
      error: (_, __) => EmptyState(
        icon: Icons.cloud_off_rounded,
        message: '加载失败',
        actionLabel: '重试',
        onAction: () =>
            ref.invalidate(novelBrowseProvider((_sourceId, option.key, _page))),
      ),
      data: (list) => Column(
        children: [
          Expanded(child: _grid(list.items)),
          _pager(list.hasMore),
        ],
      ),
    );
  }

  Widget _pager(bool hasMore) {
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
            onPressed: _page > 1 ? () => setState(() => _page--) : null,
          ),
          const SizedBox(width: 16),
          Text('第 $_page 页',
              style: const TextStyle(fontSize: 13, color: _muted)),
          const SizedBox(width: 16),
          IconButton(
            tooltip: '下一页',
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: hasMore ? () => setState(() => _page++) : null,
          ),
        ],
      ),
    );
  }

  Widget _grid(List<Novel> items) {
    if (items.isEmpty) {
      return const EmptyState(icon: Icons.menu_book_rounded, message: '暂无内容');
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6, mainAxisSpacing: 20, crossAxisSpacing: 16, childAspectRatio: 0.58),
      itemCount: items.length,
      itemBuilder: (_, i) => NovelCard(
        novel: items[i],
        onTap: () => Navigator.push(
          context,
          noTransitionRoute(NovelDetailPage(
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
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6, mainAxisSpacing: 20, crossAxisSpacing: 16, childAspectRatio: 0.58),
      itemCount: favorites.length,
      itemBuilder: (_, i) => NovelCard(
        novel: Novel(
          id: favorites[i].novelId,
          title: favorites[i].title,
          coverUrl: favorites[i].cover,
        ),
        onTap: () => Navigator.push(
          context,
          noTransitionRoute(NovelDetailPage(
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
    final records = ref.watch(novelHistoryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              const Text('历史记录',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: _fg,
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
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500, color: _fg),
                ),
                const SizedBox(height: 6),
                Text(
                  '读到 ${entry.chapterTitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
                const SizedBox(height: 4),
                Text(
                  _relativeTime(entry.updatedAt),
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

Widget _cover(String? url) {
  if (url == null || url.isEmpty) {
    return Container(color: const Color(0xFFE5E5EA));
  }
  return CachedNetworkImage(
    imageUrl: url,
    fit: BoxFit.cover,
    memCacheWidth: 200,
    httpHeaders: novelImageHeaders,
    placeholder: (_, __) => Container(color: const Color(0xFFE5E5EA)),
    errorWidget: (_, __, ___) => Container(color: const Color(0xFFE5E5EA)),
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
