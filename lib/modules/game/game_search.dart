import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform.dart';
import '../../core/widgets/adaptive_grid.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../core/widgets/smooth_route.dart';
import '../../core/widgets/search_toolbar.dart';
import 'game_detail_page.dart';
import 'game_grid.dart';
import 'game_home.dart';
import 'game_providers.dart';

int _searchColumns(double width) =>
    ((width - 32) / (260 + gameGridSpacing)).floor().clamp(1, gameGridColumns);

class GameSearchPage extends ConsumerStatefulWidget {
  final String? initialKeyword;
  const GameSearchPage({super.key, this.initialKeyword});

  @override
  ConsumerState<GameSearchPage> createState() => _GameSearchPageState();
}

class _GameSearchPageState extends ConsumerState<GameSearchPage> {
  final _ctrl = TextEditingController();
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialKeyword?.trim() ?? '';
    if (initial.isNotEmpty) {
      _ctrl.text = initial;
      _keyword = initial;
    }
  }

  void _search() {
    final k = _ctrl.text.trim();
    if (k.isEmpty) return;
    setState(() => _keyword = k);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _searchBar(),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _searchBar() => SearchToolbar(
        controller: _ctrl,
        hintText: '搜索游戏...',
        autofocus: widget.initialKeyword == null,
        onSearch: _search,
      );
  Widget _body() {
    final cs = Theme.of(context).colorScheme;
    if (_keyword.isEmpty) {
      return const EmptyState(icon: Icons.search_rounded, message: '输入关键词搜索游戏');
    }
    final sources = ref.watch(gameSourcesProvider);
    final results = <GameSearchResult>[];
    final seen = <(String, String)>{};
    var pending = 0;
    var failed = 0;
    Object? lastError;
    for (final source in sources) {
      final async = ref.watch(gameSearchSourceProvider((source.id, _keyword)));
      async.when(
        data: (list) {
          for (final r in list) {
            if (r.game.id.isEmpty || seen.add((r.sourceKey, r.game.id))) {
              results.add(r);
            }
          }
        },
        loading: () {
          pending++;
        },
        error: (error, __) {
          failed++;
          lastError = error;
        },
      );
    }
    if (results.isEmpty && pending > 0) {
      return LayoutBuilder(builder: (context, constraints) {
        final columns = _searchColumns(constraints.maxWidth);
        final cellW = gameGridCellWidth(constraints.maxWidth, columns: columns);
        final mobileCellW = constraints.maxWidth - 32;
        final mobileAspect =
            mobileCellW / (mobileCellW * 2 / 3 + gameGridTitleExtent);
        return ShimmerLoader(
            crossAxisCount: columns,
            mobileColumns: 1,
            itemCount: 8,
            aspectRatio: isDesktop
                ? cellW /
                    gameGridCellExtent(constraints.maxWidth, columns: columns)
                : mobileAspect,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24));
      });
    }
    if (results.isEmpty) {
      if (sources.isNotEmpty && failed == sources.length) {
        return EmptyState(
          icon: Icons.error_outline_rounded,
          message: lastError?.toString() ?? '搜索失败',
          actionLabel: '重试',
          onAction: () {
            for (final source in sources) {
              ref.invalidate(gameSearchSourceProvider((source.id, _keyword)));
            }
          },
        );
      }
      return const EmptyState(
          icon: Icons.search_off_rounded, message: '没有找到游戏');
    }
    return Column(
      children: [
        SearchResultSummary(count: results.length, pending: pending > 0),
        if (pending > 0)
          LinearProgressIndicator(
            minHeight: 2,
            color: cs.primary,
            backgroundColor: cs.outlineVariant,
          ),
        Expanded(child: _grid(results)),
      ],
    );
  }

  Widget _grid(List<GameSearchResult> results) {
    final names = {
      for (final source in ref.watch(gameSourcesProvider))
        source.id: source.name
    };
    return LayoutBuilder(builder: (context, constraints) {
      final columns = _searchColumns(constraints.maxWidth);
      final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
      Widget gameCell(BuildContext context, int i) {
        final r = results[i];
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('来源：${names[r.sourceKey] ?? r.sourceKey}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.primary)),
              const SizedBox(height: 4),
              Expanded(
                  child: GameCard(
                game: r.game,
                heroTag: 'game_${r.sourceKey}_${r.game.id}',
                onTap: () => Navigator.push(
                  context,
                  smoothRoute(GameDetailPage(
                    sourceKey: r.sourceKey,
                    gameId: r.game.id,
                    title: r.game.title,
                    cover: r.game.coverUrl,
                  )),
                ),
              )),
              if (r.game.extra['version'] is String)
                Text('版本：${r.game.extra['version']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11)),
            ]);
      }

      if (isDesktop) {
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 20,
              crossAxisSpacing: gameGridSpacing,
              mainAxisExtent: gameGridCellExtent(constraints.maxWidth,
                      columns: columns, textScale: scale) +
                  36 * scale),
          itemCount: results.length,
          itemBuilder: gameCell,
        );
      }
      return AdaptiveGridView(
        itemCount: results.length,
        mobileColumns: 1,
        mobileCoverRatio: 3 / 2,
        mobileTitleExtent: 82,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemBuilder: gameCell,
      );
    });
  }
}
