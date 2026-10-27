import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/adaptive_grid.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../core/widgets/smooth_route.dart';
import '../../core/widgets/search_toolbar.dart';
import 'novel_detail_page.dart';
import 'novel_home.dart';
import 'novel_providers.dart';

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
        hintText: '搜索轻小说...',
        autofocus: widget.initialKeyword == null,
        onSearch: _search,
      );
  Widget _body() {
    final cs = Theme.of(context).colorScheme;
    if (_keyword.isEmpty) {
      return const EmptyState(
          icon: Icons.search_rounded, message: '输入关键词搜索轻小说');
    }
    final sources = ref.watch(novelSourcesProvider);
    final results = <NovelSearchResult>[];
    final seen = <(String, String)>{};
    var pending = 0;
    var failed = 0;
    Object? lastError;
    for (final source in sources) {
      final async = ref.watch(novelSearchSourceProvider((source.id, _keyword)));
      async.when(
        data: (list) {
          for (final r in list) {
            if (r.novel.id.isEmpty || seen.add((r.sourceKey, r.novel.id))) {
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
      return const ShimmerLoader(
        crossAxisCount: 6,
        mobileColumns: 3,
        itemCount: 12,
        aspectRatio: 0.58,
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
      );
    }
    if (results.isEmpty) {
      if (sources.isNotEmpty && failed == sources.length) {
        return EmptyState(
          icon: Icons.error_outline_rounded,
          message: lastError?.toString() ?? '搜索失败',
          actionLabel: '重试',
          onAction: () {
            for (final source in sources) {
              ref.invalidate(novelSearchSourceProvider((source.id, _keyword)));
            }
          },
        );
      }
      return const EmptyState(
          icon: Icons.search_off_rounded, message: '没有找到轻小说');
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

  Widget _grid(List<NovelSearchResult> results) {
    final names = {
      for (final source in ref.watch(novelSourcesProvider))
        source.id: source.name
    };
    return AdaptiveGridView(
      responsiveColumns: true,
      mobileTitleExtent: 84,
      itemCount: results.length,
      mobileColumns: 3,
      desktopAspectRatio: 0.58,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemBuilder: (_, i) {
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
                  child: NovelCard(
                novel: r.novel,
                heroTag: 'novel_${r.sourceKey}_${r.novel.id}',
                onTap: () => Navigator.push(
                  context,
                  smoothRoute(NovelDetailPage(
                    sourceKey: r.sourceKey,
                    novelId: r.novel.id,
                    title: r.novel.title,
                    cover: r.novel.coverUrl,
                  )),
                ),
              )),
              if (r.novel.author?.trim().isNotEmpty ?? false)
                Text('作者：${r.novel.author}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11)),
              if (r.novel.extra['version'] is String)
                Text('版本：${r.novel.extra['version']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11)),
            ]);
      },
    );
  }
}
