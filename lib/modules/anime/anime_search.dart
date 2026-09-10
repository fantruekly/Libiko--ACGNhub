import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/work.dart';
import '../../core/widgets/work_card.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../core/widgets/empty_state.dart';
import 'anime_providers.dart';
import 'bangumi_detail_page.dart';

class AnimeSearchPage extends ConsumerStatefulWidget {
  final String? initialKeyword;
  const AnimeSearchPage({super.key, this.initialKeyword});

  @override
  ConsumerState<AnimeSearchPage> createState() => _AnimeSearchPageState();
}

class _AnimeSearchPageState extends ConsumerState<AnimeSearchPage> {
  final _ctrl = TextEditingController();
  List<Work> _results = [];
  bool _loading = false;
  String? _error;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialKeyword != null) {
      _ctrl.text = widget.initialKeyword!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  Future<void> _search() async {
    final k = _ctrl.text.trim();
    if (k.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _hasSearched = true;
    });
    try {
      final svc = ref.read(bangumiServiceProvider);
      final items = await svc.searchSubject(k);
      setState(() {
        _results = items
            .map((item) => Work(
                  id: 'bgm_${item['id']}',
                  sourceId: 'bangumi',
                  sourceName: 'Bangumi',
                  type: WorkType.anime,
                  title: item['title'] as String? ?? '',
                  coverUrl: item['cover'] as String?,
                  summary: item['summary'] as String?,
                  extra: {'bangumiId': item['id'], 'keyword': item['title']},
                ))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
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
            Expanded(child: _body(cs)),
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
        border: Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
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
                  Icon(Icons.search_rounded, size: 18, color: cs.onSurface.withValues(alpha: 0.3)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: widget.initialKeyword == null,
                      style: TextStyle(fontSize: 15, color: cs.onSurface),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '搜索动漫...',
                        hintStyle: TextStyle(color: Color(0xFF8E8E93), fontSize: 15),
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
                      child: Icon(Icons.close_rounded, size: 16, color: cs.onSurface.withValues(alpha: 0.3)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: _search, child: const Text('搜索', style: TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _body(ColorScheme cs) {
    if (_loading) return const ShimmerLoader();
    if (_error != null) {
      return EmptyState(icon: Icons.error_outline_rounded, message: _error!, actionLabel: '重试', onAction: _search);
    }
    if (!_hasSearched) {
      return const EmptyState(icon: Icons.search_rounded, message: '输入关键词搜索动漫');
    }
    if (_hasSearched && _results.isEmpty) {
      return EmptyState(icon: Icons.search_off_rounded, message: '未找到「${_ctrl.text}」相关动漫，换个关键词试试');
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.66,
      ),
      itemCount: _results.length,
      itemBuilder: (context, index) => WorkCard(
        work: _results[index],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BangumiDetailPage(work: _results[index])),
        ),
      ),
    );
  }
}