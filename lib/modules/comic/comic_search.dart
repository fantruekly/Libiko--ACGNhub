import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/comic/comic_source.dart';
import '../../core/widgets/adaptive_grid.dart';
import '../../core/widgets/chip_bar.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../core/widgets/smooth_route.dart';
import '../../core/widgets/search_toolbar.dart';
import 'comic_detail_page.dart';
import 'comic_home.dart';
import 'comic_providers.dart';

class ComicSearchPage extends ConsumerStatefulWidget {
  final String? initialKeyword;
  const ComicSearchPage({super.key, this.initialKeyword});

  @override
  ConsumerState<ComicSearchPage> createState() => _ComicSearchPageState();
}

class _ComicSearchPageState extends ConsumerState<ComicSearchPage> {
  final _ctrl = TextEditingController();
  String _keyword = '';
  String? _selectedSourceKey;

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
    final sourcesAsync = ref.watch(comicSourcesProvider);
    final searchable = (sourcesAsync.valueOrNull ?? const <ComicSource>[])
        .where((s) => s.canSearch)
        .toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _searchBar(),
            if (searchable.isNotEmpty) _sourceBar(searchable),
            Expanded(child: _body(sourcesAsync, searchable)),
          ],
        ),
      ),
    );
  }

  Widget _searchBar() => SearchToolbar(
        controller: _ctrl,
        hintText: '搜索漫画...',
        autofocus: widget.initialKeyword == null,
        onSearch: _search,
      );
  Widget _sourceBar(List<ComicSource> searchable) {
    final labels = ['全部', for (final s in searchable) s.name];
    var index = 0;
    if (_selectedSourceKey != null) {
      final i = searchable.indexWhere((s) => s.key == _selectedSourceKey);
      index = i < 0 ? 0 : i + 1;
    }
    return ChipBar(
      labels: labels,
      selectedIndex: index,
      onSelected: (i) => setState(() {
        _selectedSourceKey = i == 0 ? null : searchable[i - 1].key;
      }),
    );
  }

  Widget _body(AsyncValue<List<ComicSource>> sourcesAsync,
      List<ComicSource> searchable) {
    if (_keyword.isEmpty) {
      return const EmptyState(icon: Icons.search_rounded, message: '输入关键词搜索漫画');
    }
    if (sourcesAsync.isLoading && !sourcesAsync.hasValue) {
      return const ShimmerLoader(
        crossAxisCount: 6,
        mobileColumns: 3,
        itemCount: 12,
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
      );
    }
    if (sourcesAsync.hasError && !sourcesAsync.hasValue) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        message: '漫画源加载失败',
        actionLabel: '重试',
        onAction: () => ref.invalidate(allComicSourcesProvider),
      );
    }
    if (searchable.isEmpty) {
      return const EmptyState(
          icon: Icons.extension_off_rounded, message: '没有可搜索的漫画源');
    }

    final selected = searchable.any((s) => s.key == _selectedSourceKey)
        ? searchable.firstWhere((s) => s.key == _selectedSourceKey)
        : null;
    final grouped = selected == null;
    final sources = selected == null ? searchable : [selected];

    final states = <String, AsyncValue<List<ComicSearchResult>>>{
      for (final s in sources)
        s.key: ref.watch(comicSearchSourceProvider((s.key, _keyword))),
    };
    final hasData =
        states.values.any((v) => (v.valueOrNull?.isNotEmpty) ?? false);
    final loading = states.values.any((v) => v.isLoading);
    final allFailed = states.values.every((v) => v.hasError);

    if (!hasData && loading) {
      return const ShimmerLoader(
        crossAxisCount: 6,
        mobileColumns: 3,
        itemCount: 12,
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
      );
    }
    if (!hasData && allFailed) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        message: grouped ? '所有漫画源搜索失败' : '${sources.single.name} 搜索失败',
        actionLabel: '重试',
        onAction: () {
          for (final s in sources) {
            ref.invalidate(comicSearchSourceProvider((s.key, _keyword)));
          }
        },
      );
    }
    if (!hasData) {
      return const EmptyState(
          icon: Icons.search_off_rounded, message: '没有找到漫画');
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
            child: SearchResultSummary(
          count: states.values.fold<int>(
              0, (count, state) => count + (state.valueOrNull?.length ?? 0)),
          pending: loading,
        )),
        for (final s in sources) ...[
          if (grouped) _sectionHeader(s, states[s.key]!),
          _sectionContent(s, states[s.key]!),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _sectionHeader(
      ComicSource source, AsyncValue<List<ComicSearchResult>> state) {
    final cs = Theme.of(context).colorScheme;
    final String status;
    if (state.isLoading && !state.hasValue) {
      status = '搜索中…';
    } else if (state.hasError) {
      status = '失败';
    } else if ((state.valueOrNull?.isEmpty) ?? true) {
      status = '无结果';
    } else {
      status = '${state.valueOrNull!.length} 个结果';
    }
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Wrap(
          spacing: 10,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              source.name,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface),
            ),
            Text(status,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _sectionContent(
      ComicSource source, AsyncValue<List<ComicSearchResult>> state) {
    final cs = Theme.of(context).colorScheme;
    if (state.isLoading && !state.hasValue) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: LinearProgressIndicator(minHeight: 2),
        ),
      );
    }
    if (state.hasError) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Row(
            children: [
              Text('加载失败',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              TextButton(
                onPressed: () => ref.invalidate(
                    comicSearchSourceProvider((source.key, _keyword))),
                child: const Text('重试', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
      );
    }
    final results = state.valueOrNull ?? const <ComicSearchResult>[];
    if (results.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text('无结果',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        ),
      );
    }
    return SliverAdaptiveGrid(
      responsiveColumns: true,
      itemCount: results.length,
      mobileColumns: 3,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
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
