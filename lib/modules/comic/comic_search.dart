import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/adaptive_grid.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../core/widgets/smooth_route.dart';
import 'comic_detail_page.dart';
import 'comic_home.dart';
import 'comic_providers.dart';

const _muted = Color(0xFF5A5A5F);

class ComicSearchPage extends ConsumerStatefulWidget {
  final String? initialKeyword;
  const ComicSearchPage({super.key, this.initialKeyword});

  @override
  ConsumerState<ComicSearchPage> createState() => _ComicSearchPageState();
}

class _ComicSearchPageState extends ConsumerState<ComicSearchPage> {
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
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '搜索漫画...',
                        hintStyle: TextStyle(color: _muted, fontSize: 15),
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
    if (_keyword.isEmpty) {
      return const EmptyState(
          icon: Icons.search_rounded, message: '输入关键词搜索漫画');
    }
    final async = ref.watch(comicSearchProvider(_keyword));
    return async.when(
      loading: () => const ShimmerLoader(
        crossAxisCount: 6,
        mobileColumns: 3,
        itemCount: 12,
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
      ),
      error: (error, __) => EmptyState(
        icon: Icons.error_outline_rounded,
        message: error.toString(),
        actionLabel: '重试',
        onAction: () => ref.invalidate(comicSearchProvider(_keyword)),
      ),
      data: (results) {
        if (results.isEmpty) {
          return const EmptyState(
              icon: Icons.search_off_rounded, message: '没有找到漫画');
        }
        return _resultsGrid(results);
      },
    );
  }

  Widget _resultsGrid(List<ComicSearchResult> results) {
    return AdaptiveGridView(
      itemCount: results.length,
      mobileColumns: 3,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemBuilder: (context, index) {
        final result = results[index];
        return ComicCard(
          title: result.comic.title,
          cover: result.comic.cover,
          heroTag: 'comic_${result.sourceKey}_${result.comic.id}',
          onTap: () => Navigator.push(
            context,
            smoothRoute(ComicDetailPage(
              sourceKey: result.sourceKey,
              comicId: result.comic.id,
              title: result.comic.title,
              cover: result.comic.cover,
            )),
          ),
        );
      },
    );
  }
}
