import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform.dart';
import '../../core/widgets/adaptive_grid.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../core/widgets/smooth_route.dart';
import 'game_detail_page.dart';
import 'game_grid.dart';
import 'game_home.dart';
import 'game_providers.dart';

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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          children: [
            _searchBar(cs),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _searchBar(ColorScheme cs) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        border:
            Border(bottom: BorderSide(color: cs.outlineVariant, width: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
            splashRadius: 20,
          ),
          Expanded(
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded,
                      size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: widget.initialKeyword == null,
                      style: TextStyle(fontSize: 15, color: cs.onSurface),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '搜索游戏...',
                        hintStyle:
                            TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => _search(),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (_ctrl.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _ctrl.clear();
                        setState(() {});
                      },
                      child: Icon(Icons.close_rounded,
                          size: 16, color: cs.onSurface.withValues(alpha: 0.3)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
              onPressed: _search,
              child: const Text('搜索', style: TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _body() {
    final cs = Theme.of(context).colorScheme;
    if (_keyword.isEmpty) {
      return const EmptyState(
          icon: Icons.search_rounded, message: '输入关键词搜索游戏');
    }
    final sources = ref.watch(gameSourcesProvider);
    final results = <GameSearchResult>[];
    final seen = <String>{};
    var pending = 0;
    var failed = 0;
    Object? lastError;
    for (final source in sources) {
      final async =
          ref.watch(gameSearchSourceProvider((source.id, _keyword)));
      async.when(
        data: (list) {
          for (final r in list) {
            if (seen.add(r.game.title.trim())) results.add(r);
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
        final cellW = gameGridCellWidth(constraints.maxWidth);
        final mobileCellW = constraints.maxWidth - 32;
        final mobileAspect =
            mobileCellW / (mobileCellW * 2 / 3 + gameGridTitleExtent);
        return ShimmerLoader(
            crossAxisCount: gameGridColumns,
            mobileColumns: 1,
            itemCount: 8,
            aspectRatio: isDesktop
                ? cellW / gameGridCellExtent(constraints.maxWidth)
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
    return LayoutBuilder(builder: (context, constraints) {
      Widget gameCell(BuildContext context, int i) {
        final r = results[i];
        return GameCard(
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
        );
      }

      if (isDesktop) {
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: gameGridColumns,
              mainAxisSpacing: 20,
              crossAxisSpacing: gameGridSpacing,
              mainAxisExtent: gameGridCellExtent(constraints.maxWidth)),
          itemCount: results.length,
          itemBuilder: gameCell,
        );
      }
      return AdaptiveGridView(
        itemCount: results.length,
        mobileColumns: 1,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemBuilder: gameCell,
      );
    });
  }
}
