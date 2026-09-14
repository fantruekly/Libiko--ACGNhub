import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../core/widgets/smooth_route.dart';
import 'novel_detail_page.dart';
import 'novel_home.dart';
import 'novel_providers.dart';

const _muted = Color(0xFF5A5A5F);

class NovelSearchPage extends ConsumerStatefulWidget {
  final String? initialKeyword;
  const NovelSearchPage({super.key, this.initialKeyword});

  @override
  ConsumerState<NovelSearchPage> createState() => _NovelSearchPageState();
}

class _NovelSearchPageState extends ConsumerState<NovelSearchPage> {
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
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        border:
            Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
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
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded,
                      size: 18, color: cs.onSurface.withValues(alpha: 0.3)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: widget.initialKeyword == null,
                      style: TextStyle(fontSize: 15, color: cs.onSurface),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '搜索轻小说...',
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
          icon: Icons.search_rounded, message: '输入关键词搜索轻小说');
    }
    final async = ref.watch(novelSearchProvider(_keyword));
    return async.when(
      loading: () => const ShimmerLoader(
        crossAxisCount: 6,
        itemCount: 12,
        aspectRatio: 0.58,
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
      ),
      error: (error, __) => EmptyState(
        icon: Icons.error_outline_rounded,
        message: error.toString(),
        actionLabel: '重试',
        onAction: () => ref.invalidate(novelSearchProvider(_keyword)),
      ),
      data: (results) {
        if (results.isEmpty) {
          return const EmptyState(
              icon: Icons.search_off_rounded, message: '没有找到轻小说');
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 20,
              crossAxisSpacing: 16,
              childAspectRatio: 0.58),
          itemCount: results.length,
          itemBuilder: (_, i) {
            final r = results[i];
            return NovelCard(
              novel: r.novel,
              onTap: () => Navigator.push(
                context,
                noTransitionRoute(NovelDetailPage(
                  sourceKey: r.sourceKey,
                  novelId: r.novel.id,
                  title: r.novel.title,
                  cover: r.novel.coverUrl,
                )),
              ),
            );
          },
        );
      },
    );
  }
}
