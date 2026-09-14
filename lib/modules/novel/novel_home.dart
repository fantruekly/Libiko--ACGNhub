import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/novel/linovelib_source.dart';
import '../../core/novel/models.dart';
import '../../core/novel/novel_source.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../core/widgets/smooth_route.dart';
import 'novel_detail_page.dart';
import 'novel_providers.dart';

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

enum _NovelSection { recommend, ranking, bunko }

const _rankingOptions = <String, String>{
  'allvisit': '人气榜',
  'monthvisit': '月点击',
  'weekvisit': '周点击',
  'monthvote': '月推荐',
  'weekvote': '周推荐',
  'monthflower': '月鲜花',
  'weekflower': '周鲜花',
  'monthegg': '月鸡蛋',
  'weekegg': '周鸡蛋',
  'lastupdate': '最近更新',
  'postdate': '最新入库',
  'goodnum': '收藏榜',
  'newhot': '新书榜',
};

const _bunkoOptions = <String, String>{
  'dengekibunko': '电击',
  'fujimibunko': '富士见',
  'kadokawabunko': '角川',
  'emuefubunkojei': 'MF文库J',
  'famitsubunko': 'Fami通',
  'gagraphicbunko': 'GA',
  'hobbyjapanbunko': 'HJ',
  'ichijinsha': '一迅社',
  'shueisha': '集英社',
  'shogakukan': '小学馆',
  'kodansha': '讲谈社',
  'teenagebunko': '少女文库',
  'other': '其他文库',
  'chineselightnovel': '华文轻小说',
};

class NovelHomePage extends ConsumerStatefulWidget {
  const NovelHomePage({super.key});
  @override
  ConsumerState<NovelHomePage> createState() => _NovelHomePageState();
}

class _NovelHomePageState extends ConsumerState<NovelHomePage> {
  String _sourceId = 'linovelib';
  _NovelSection _section = _NovelSection.recommend;
  String _rankingKey = 'allvisit';
  String _bunkoKey = 'dengekibunko';
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(novelSourcesProvider);
    return Column(
      children: [
        const SizedBox(height: 8),
        _sourceChips(sources),
        _sectionChips(),
        if (_section == _NovelSection.ranking) _optionChips(_rankingOptions, _rankingKey, (k) => setState(() { _rankingKey = k; _page = 1; })),
        if (_section == _NovelSection.bunko) _optionChips(_bunkoOptions, _bunkoKey, (k) => setState(() { _bunkoKey = k; _page = 1; })),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _sourceChips(List<NovelSource> sources) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final s in sources)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _chip(s.name, s.id == _sourceId, () => setState(() {
                _sourceId = s.id;
                _page = 1;
              })),
            ),
        ],
      ),
    );
  }

  Widget _sectionChips() {
    const labels = {_NovelSection.recommend: '推荐', _NovelSection.ranking: '排行', _NovelSection.bunko: '文库'};
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final e in labels.entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _chip(e.value, e.key == _section, () => setState(() {
                _section = e.key;
                _page = 1;
              })),
            ),
        ],
      ),
    );
  }

  Widget _optionChips(Map<String, String> options, String selected, ValueChanged<String> onTap) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final e in options.entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _chip(e.value, e.key == selected, () => onTap(e.key)),
            ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      selectedColor: _accent,
      backgroundColor: const Color(0xFFF2F2F7),
      labelStyle: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w500, color: selected ? Colors.white : _muted),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _body() {
    if (_section == _NovelSection.recommend) {
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
    final kind = _section == _NovelSection.ranking ? NovelBrowseKind.ranking : NovelBrowseKind.bunko;
    final key = _section == _NovelSection.ranking ? _rankingKey : _bunkoKey;
    final async = ref.watch(novelBrowseProvider((_sourceId, kind, key, _page)));
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
        onAction: () => ref.invalidate(novelBrowseProvider((_sourceId, kind, key, _page))),
      ),
      data: (list) => Column(
        children: [
          Expanded(child: _grid(list.items)),
          _pager(list.hasMore),
        ],
      ),
    );
  }

  static final _pagerButtonStyle = OutlinedButton.styleFrom(
    minimumSize: const Size(84, 40),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  );

  Widget _pager(bool hasMore) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton(
            style: _pagerButtonStyle,
            onPressed: _page > 1 ? () => setState(() => _page--) : null,
            child: const Text('上一页'),
          ),
          const SizedBox(width: 16),
          Text('第 $_page 页',
              style: const TextStyle(fontSize: 13, color: _muted)),
          const SizedBox(width: 16),
          OutlinedButton(
            style: _pagerButtonStyle,
            onPressed: hasMore ? () => setState(() => _page++) : null,
            child: const Text('下一页'),
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
