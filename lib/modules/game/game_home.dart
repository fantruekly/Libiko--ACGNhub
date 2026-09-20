import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/game/game_image.dart';
import '../../core/game/game_source.dart';
import '../../core/game/models.dart';
import '../../core/platform.dart';
import '../../core/widgets/adaptive_grid.dart';
import '../../core/widgets/chip_bar.dart';
import '../../core/widgets/chip_nav.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/pager_bar.dart';
import '../../core/widgets/ratio_cover.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../core/widgets/slide_switcher.dart';
import '../../core/widgets/smooth_route.dart';
import 'game_detail_page.dart';
import 'game_grid.dart';
import 'game_providers.dart';

class GameCard extends StatelessWidget {
  final Game game;
  final VoidCallback? onTap;
  final String? heroTag;
  const GameCard({super.key, required this.game, this.onTap, this.heroTag});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget image = RatioCover(
      url: game.coverUrl,
      httpHeaders: gameImageHeadersFor(game.coverUrl),
      fallbackRatio: 3 / 2,
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
              game.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                  color: cs.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(ColorScheme cs) {
    final hash = game.title.hashCode.abs();
    const bg = [
      Color(0xFFF3E5F5),
      Color(0xFFEDE7F6),
      Color(0xFFE8EAF6),
      Color(0xFFE0F2F1),
    ];
    return Container(
      color: bg[hash % bg.length],
      child: Center(
        child: Text(
          game.title.isEmpty ? '游' : game.title.characters.first,
          style: TextStyle(
              color: cs.primary.withValues(alpha: 0.2),
              fontSize: 28,
              fontWeight: FontWeight.w400),
        ),
      ),
    );
  }
}

class GameHomePage extends ConsumerStatefulWidget {
  const GameHomePage({super.key});

  @override
  ConsumerState<GameHomePage> createState() => _GameHomePageState();
}

class _GameHomePageState extends ConsumerState<GameHomePage> {
  String _sourceId = 'galgamezywz';
  int _optionIndex = 0;
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(gameSourcesProvider);
    final source = ref.watch(gameSourceManagerProvider).byId(_sourceId);
    final options = source?.browseOptions ?? const <GameBrowseOption>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        _sourceChips(sources),
        _sectionChips(options),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragEnd: (details) {
              final v = details.primaryVelocity ?? 0;
              final delta = v < -100 ? 1 : (v > 100 ? -1 : 0);
              if (delta == 0) return;
              final sourceIndex =
                  sources.indexWhere((s) => s.id == _sourceId);
              final next = stepChipSelection(
                a: sourceIndex,
                aMin: 0,
                aMax: sources.length - 1,
                b: _optionIndex,
                bMin: 0,
                bMax: options.length - 1,
                c: 0,
                cMin: 0,
                cMax: 0,
                delta: delta,
              );
              if (next == null) return;
              setState(() {
                _sourceId = sources[next.a].id;
                _optionIndex = next.b;
                _page = 1;
              });
            },
            child: _body(options),
          ),
        ),
      ],
    );
  }

  Widget _sourceChips(List<GameSource> sources) {
    if (sources.isEmpty) return const SizedBox.shrink();
    final labels = [for (final s in sources) s.name];
    final index = sources.indexWhere((s) => s.id == _sourceId);
    return ChipBar(
      labels: labels,
      selectedIndex: index < 0 ? 0 : index,
      onSelected: (i) => setState(() {
        _sourceId = sources[i].id;
        _optionIndex = 0;
        _page = 1;
      }),
    );
  }

  Widget _sectionChips(List<GameBrowseOption> options) {
    final labels = [for (final o in options) o.label];
    if (labels.isEmpty) return const SizedBox.shrink();
    return ChipBar(
      labels: labels,
      selectedIndex: _optionIndex.clamp(0, labels.length - 1),
      onSelected: (i) => setState(() {
        _optionIndex = i;
        _page = 1;
      }),
    );
  }

  Widget _body(List<GameBrowseOption> options) {
    if (options.isEmpty) {
      return const EmptyState(icon: Icons.games_rounded, message: '暂无内容');
    }
    final option = options[_optionIndex.clamp(0, options.length - 1)];
    final sourceIndex =
        ref.watch(gameSourcesProvider).indexWhere((s) => s.id == _sourceId);
    final key = (_sourceId, option.key, _page);
    final async = ref.watch(gameBrowseProvider(key));
    final pageData = async.valueOrNull;
    return Column(
      children: [
        Expanded(
          child: SlideSwitcher(
            id: key,
            index: sourceIndex * 10000 + _optionIndex * 100 + _page,
            child: async.when(
              loading: () => LayoutBuilder(builder: (context, constraints) {
                final cellW = gameGridCellWidth(constraints.maxWidth);
                final mobileCellW = constraints.maxWidth - 32;
                final mobileAspect = mobileCellW /
                    (mobileCellW * 2 / 3 + gameGridTitleExtent);
                return ShimmerLoader(
                    crossAxisCount: gameGridColumns,
                    mobileColumns: 1,
                    itemCount: 8,
                    aspectRatio: isDesktop
                        ? cellW / gameGridCellExtent(constraints.maxWidth)
                        : mobileAspect,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24));
              }),
              error: (_, __) => EmptyState(
                icon: Icons.cloud_off_rounded,
                message: '加载失败',
                actionLabel: '重试',
                onAction: () => ref.invalidate(gameBrowseProvider(key)),
              ),
              data: (list) => _grid(list.items),
            ),
          ),
        ),
        if (pageData != null) _pager(pageData.hasMore),
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

  Widget _grid(List<Game> items) {
    if (items.isEmpty) {
      return const EmptyState(icon: Icons.games_rounded, message: '暂无内容');
    }
    return LayoutBuilder(builder: (context, constraints) {
      Widget gameCell(BuildContext context, int i) => GameCard(
            game: items[i],
            heroTag: 'game_${_sourceId}_${items[i].id}',
            onTap: () => Navigator.push(
              context,
              smoothRoute(GameDetailPage(
                sourceKey: _sourceId,
                gameId: items[i].id,
                title: items[i].title,
                cover: items[i].coverUrl,
              )),
            ),
          );
      if (isDesktop) {
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: gameGridColumns,
              mainAxisSpacing: 20,
              crossAxisSpacing: gameGridSpacing,
              mainAxisExtent: gameGridCellExtent(constraints.maxWidth)),
          itemCount: items.length,
          itemBuilder: gameCell,
        );
      }
      return AdaptiveGridView(
        itemCount: items.length,
        mobileColumns: 1,
        mobileCoverRatio: 3 / 2,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemBuilder: gameCell,
      );
    });
  }
}
