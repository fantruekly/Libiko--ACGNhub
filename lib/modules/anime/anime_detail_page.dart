import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_selector/file_selector.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/account/sync_service.dart';
import '../../core/models/anime_extra.dart';
import '../../core/models/work.dart';
import '../../core/services/follow_manager.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/widgets/pill_button.dart';
import '../../core/widgets/rating_stars.dart';
import '../../core/widgets/smooth_route.dart';
import '../../core/widgets/window_controls.dart';
import '../../core/video/rule_store.dart';
import '../../core/video/stream_resolver.dart';
import '../../core/video/video_source.dart';
import '../../core/video/video_sources.dart';
import 'anime_providers.dart';
import 'video_player_page.dart';

enum _SourceStatus { loading, done, failed }

class _SourceResult {
  final VideoSource source;
  _SourceStatus status = _SourceStatus.loading;
  List<VideoItem> items = const [];
  int seq = 0;
  _SourceResult(this.source);
}

class AnimeDetailPage extends ConsumerStatefulWidget {
  final Work work;
  const AnimeDetailPage({super.key, required this.work});

  @override
  ConsumerState<AnimeDetailPage> createState() => _AnimeDetailPageState();
}

class _AnimeDetailPageState extends ConsumerState<AnimeDetailPage> {
  late Work _work;
  bool _loading = true;
  bool _expanded = false;
  List<_SourceResult> _sourceResults = const [];
  int _searchGen = 0;
  int _searchSeq = 0;
  VideoItem? _expandedItem;
  VideoSource? _expandedSource;
  List<VideoEpisode>? _episodes;
  bool _episodesLoading = false;
  String? _episodesError;
  List<AnimeCharacter>? _characters;
  List<RelatedWork>? _related;
  bool _loadingExtras = false;
  Timer? _searchTimer;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _work = widget.work;
    _load();
  }

  @override
  void dispose() {
    _disposed = true;
    _searchTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final enriched =
          await ref.read(metadataServiceProvider).detail(widget.work);
      if (mounted) {
        setState(() {
          _work = enriched;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
    _loadExtras();
    _scheduleSearch();
  }

  void _scheduleSearch() {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _searchAllSources();
    });
  }

  Future<void> _loadExtras() async {
    if (!mounted) return;
    setState(() => _loadingExtras = true);
    final svc = ref.read(metadataServiceProvider);
    final results = await Future.wait<Object>([
      svc.characters(_work),
      svc.related(_work),
    ]);
    if (!mounted) return;
    setState(() {
      _characters = results[0] as List<AnimeCharacter>;
      _related = results[1] as List<RelatedWork>;
      _loadingExtras = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final w = _work;
    final score = (w.extra['score'] as num?)?.toDouble();
    final episodes = w.extra['episodes'] as int?;
    final seasonYear = w.extra['seasonYear'] as int?;
    final format = w.extra['format'] as String?;
    final status = w.extra['status'] as String?;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Column(
        children: [
          _header(w, cs),
          Expanded(
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  _infoSection(
                      w, cs, score, episodes, seasonYear, format, status),
                  const TabBar(
                    labelColor: Color(0xFF007AFF),
                    unselectedLabelColor: Color(0xFF5A5A5F),
                    indicatorColor: Color(0xFF007AFF),
                    dividerColor: Color(0xFFE5E5EA),
                    tabs: [Tab(text: '概览'), Tab(text: '角色'), Tab(text: '关联')],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _overviewTab(w, cs),
                        _charactersTab(cs),
                        _relatedTab(cs),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewTab(Work w, ColorScheme cs) {
    return CustomScrollView(
      slivers: [
        if (w.tags.isNotEmpty) _tagsRow(w.tags),
        _summarySection(w.summary, cs),
        _playSection(w, cs),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _charactersTab(ColorScheme cs) {
    if (_loadingExtras) return const Center(child: CircularProgressIndicator());
    final chars = _characters ?? const <AnimeCharacter>[];
    if (chars.isEmpty) {
      return Center(child: Text('暂无角色信息', style: TextStyle(fontSize: 14, color: cs.onSurface.withValues(alpha: 0.4))));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: chars.length,
      itemBuilder: (context, i) {
        final c = chars[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(width: 56, height: 56, child: _image(c.image, cs)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (c.relation != null && c.relation!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(c.relation!, style: TextStyle(fontSize: 11, color: cs.primary)),
                          ),
                      ],
                    ),
                    for (final a in c.actors)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            ClipOval(child: SizedBox(width: 24, height: 24, child: _image(a.image, cs))),
                            const SizedBox(width: 8),
                            Text('CV: ${a.name}', style: TextStyle(fontSize: 12.5, color: cs.onSurface.withValues(alpha: 0.6))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _relatedTab(ColorScheme cs) {
    if (_loadingExtras) return const Center(child: CircularProgressIndicator());
    final rel = _related ?? const <RelatedWork>[];
    if (rel.isEmpty) {
      return Center(child: Text('暂无关联作品', style: TextStyle(fontSize: 14, color: cs.onSurface.withValues(alpha: 0.4))));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rel.length,
      itemBuilder: (context, i) {
        final r = rel[i];
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => Navigator.push(
            context,
            smoothRoute(
              AnimeDetailPage(
                work: Work(
                  id: 'bangumi_${r.bangumiId}',
                  sourceId: 'bangumi',
                  sourceName: 'Bangumi',
                  type: WorkType.anime,
                  title: r.title,
                  coverUrl: r.image,
                  extra: {'bangumiId': r.bangumiId},
                ),
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(width: 56, height: 80, child: _image(r.image, cs)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.35)),
                      if (r.relation != null && r.relation!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(r.relation!, style: TextStyle(fontSize: 12, color: cs.primary)),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: cs.onSurface.withValues(alpha: 0.2)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _image(String? url, ColorScheme cs) {
    if (url == null || url.isEmpty) {
      return Container(color: cs.primary.withValues(alpha: 0.08));
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: 160,
      placeholder: (_, __) => Container(color: cs.primary.withValues(alpha: 0.06)),
      errorWidget: (_, __, ___) => Container(color: cs.primary.withValues(alpha: 0.08)),
    );
  }

  Widget _header(Work w, ColorScheme cs) {
    return DragToMoveArea(
      child: Container(
        height: 48,
        padding: const EdgeInsets.only(left: 4),
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
              child: Text(
                w.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface),
              ),
            ),
            const WindowControls(),
          ],
        ),
      ),
    );
  }

  Widget _infoSection(
    Work w,
    ColorScheme cs,
    double? score,
    int? episodes,
    int? seasonYear,
    String? format,
    String? status,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: GlassSurface(
        blur: 0,
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(16),
        border: Border.all(color: const Color(0xFFE5E5EA)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, 6)),
        ],
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'work_${w.id}',
              child: RepaintBoundary(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 110,
                    height: 154,
                    child: w.coverUrl != null && w.coverUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: w.coverUrl!,
                            fit: BoxFit.cover,
                            memCacheWidth: 300,
                            errorWidget: (_, __, ___) => _coverPlaceholder(cs),
                          )
                        : _coverPlaceholder(cs),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    w.title,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        height: 1.35),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (_loading)
                    SizedBox(
                      width: 100,
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                      ),
                    )
                  else ...[
                    if (score != null) ...[
                      RatingStars(score: score),
                      const SizedBox(height: 14),
                    ],
                    _followButton(w),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (episodes != null)
                          _metaChip(Icons.live_tv_rounded, '$episodes 话',
                              const Color(0xFF007AFF)),
                        if (seasonYear != null)
                          _metaChip(Icons.calendar_today_rounded, '$seasonYear',
                              const Color(0xFF5856D6)),
                        if (status != null)
                          _metaChip(Icons.info_outline_rounded,
                              _statusLabel(status), Colors.teal),
                        if (format != null)
                          _metaChip(
                              Icons.movie_outlined, format, Colors.deepPurple),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _followButton(Work w) {
    return Consumer(builder: (context, ref, _) {
      final followed = ref.watch(followProvider).any((r) => r.work.id == w.id);
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          backgroundColor:
              followed ? const Color(0xFFE5E5EA) : const Color(0xFF007AFF),
          foregroundColor: followed ? const Color(0xFF5A5A5F) : Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () {
          ref.read(followProvider.notifier).toggle(w);
          ref.read(syncProvider).schedule();
        },
        icon: Icon(followed ? Icons.check_rounded : Icons.add_rounded, size: 16),
        label: Text(followed ? '已追番' : '追番',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      );
    });
  }

  Widget _metaChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _coverPlaceholder(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withValues(alpha: 0.1),
            cs.tertiary.withValues(alpha: 0.05)
          ],
        ),
      ),
      child: Center(
          child: Icon(Icons.image_outlined,
              size: 24, color: cs.primary.withValues(alpha: 0.2))),
    );
  }

  Widget _tagsRow(List<String> tags) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags
              .map((t) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFFE5E5EA), width: 0.5),
                    ),
                    child: Text(
                      t,
                      style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF3A3A3C),
                          fontWeight: FontWeight.w500),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _summarySection(String? summary, ColorScheme cs) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: GlassSurface(
          blur: 0,
          borderRadius: BorderRadius.circular(16),
          padding: const EdgeInsets.all(16),
          border: Border.all(color: const Color(0xFFE5E5EA)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, 6)),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('简介',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface)),
              const SizedBox(height: 8),
              if (_loading)
                SizedBox(
                  width: 100,
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                  ),
                )
              else if (summary == null || summary.isEmpty)
                Text('暂无简介',
                    style: TextStyle(
                        fontSize: 13.5,
                        color: cs.onSurface.withValues(alpha: 0.35)))
              else
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Text(
                    summary,
                    maxLines: _expanded ? null : 4,
                    overflow: _expanded ? null : TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13.5,
                        height: 1.65,
                        color: cs.onSurface.withValues(alpha: 0.7)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _searchAllSources() async {
    final List<VideoSource> sources;
    try {
      sources = await ref.read(videoSourcesProvider.future);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    final gen = ++_searchGen;
    setState(() {
      _sourceResults = [for (final s in sources) _SourceResult(s)];
      _expandedItem = null;
      _expandedSource = null;
      _episodes = null;
      _episodesError = null;
      _episodesLoading = false;
    });

    final queue = [..._sourceResults];
    var next = 0;
    Future<void> worker() async {
      while (next < queue.length) {
        if (_disposed) return;
        final r = queue[next];
        next++;
        await _searchOne(r, gen);
      }
    }

    await Future.wait([for (var i = 0; i < 3; i++) worker()]);
  }

  Future<void> _searchOne(_SourceResult r, int gen) async {
    if (_disposed) return;
    try {
      final items =
          await r.source.search(_work.title).timeout(const Duration(seconds: 25));
      if (!mounted || gen != _searchGen) return;
      setState(() {
        r.items = items;
        r.status = _SourceStatus.done;
        r.seq = ++_searchSeq;
      });
    } catch (_) {
      if (!mounted || gen != _searchGen) return;
      setState(() => r.status = _SourceStatus.failed);
    }
  }

  List<(VideoItem, VideoSource)> get _flatResults {
    final done = _sourceResults
        .where((r) => r.status == _SourceStatus.done)
        .toList()
      ..sort((a, b) => a.seq.compareTo(b.seq));
    return [
      for (final r in done)
        for (final item in r.items) (item, r.source),
    ];
  }

  Future<void> _expandItem(VideoItem item, VideoSource source) async {
    if (identical(_expandedItem, item)) {
      setState(() {
        _expandedItem = null;
        _expandedSource = null;
        _episodes = null;
        _episodesError = null;
        _episodesLoading = false;
      });
      return;
    }
    setState(() => _expandedItem = item);
    await _loadEpisodes(item, source);
  }

  Future<void> _loadEpisodes(VideoItem item, VideoSource source) async {
    setState(() {
      _expandedSource = source;
      _episodes = null;
      _episodesError = null;
      _episodesLoading = true;
    });
    try {
      final eps = await source.episodes(item.detailUrl);
      if (!mounted || !identical(_expandedItem, item)) return;
      setState(() {
        _episodes = eps;
        _episodesLoading = false;
      });
    } catch (_) {
      if (!mounted || !identical(_expandedItem, item)) return;
      setState(() {
        _episodesLoading = false;
        _episodesError = '获取剧集失败，请重试';
      });
    }
  }

  Future<void> _playEpisode(VideoEpisode ep) async {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final url = await StreamResolver().resolve(ep.playUrl);
    if (!mounted) return;
    Navigator.of(context).pop();
    if (url == null) {
      messenger.showSnackBar(const SnackBar(content: Text('无法解析播放地址')));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerPage(
          work: _work,
          episodes: _episodes ?? const [],
          initialIndex: ep.index,
        ),
      ),
    );
  }

  Future<void> _importRule() async {
    final messenger = ScaffoldMessenger.of(context);
    const typeGroup = XTypeGroup(label: 'Kazumi 规则', extensions: ['json']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;
    try {
      final rule = await ref.read(ruleStoreProvider).importJson(
            await file.readAsString(),
          );
      ref.invalidate(videoSourcesProvider);
      if (!mounted) return;
      messenger.showSnackBar(
          SnackBar(content: Text('已导入规则：${rule.name}')));
      _searchAllSources();
    } on FormatException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
          SnackBar(content: Text('规则无效：${e.message}')));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
          const SnackBar(content: Text('导入失败，请重试')));
    }
  }

  Widget _playSection(Work w, ColorScheme cs) {
    final results = _flatResults;
    final loading =
        _sourceResults.any((r) => r.status == _SourceStatus.loading);
    final doneCount =
        _sourceResults.where((r) => r.status != _SourceStatus.loading).length;
    final failed = _sourceResults
        .where((r) => r.status == _SourceStatus.failed ||
            (r.status == _SourceStatus.done && r.items.isEmpty))
        .toList();

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: GlassSurface(
          blur: 0,
          borderRadius: BorderRadius.circular(16),
          padding: const EdgeInsets.all(16),
          border: Border.all(color: const Color(0xFFE5E5EA)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, 6)),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('播放资源',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface)),
                  const SizedBox(width: 10),
                  if (loading)
                    Text('搜索中 $doneCount/${_sourceResults.length}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF5A5A5F)))
                  else
                    Text('共 ${results.length} 条',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF5A5A5F))),
                  const Spacer(),
                  if (loading)
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  IconButton(
                    tooltip: '导入规则',
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    onPressed: _importRule,
                    icon: const Icon(Icons.file_download_outlined),
                  ),
                  IconButton(
                    tooltip: '重新搜索',
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    onPressed: loading ? null : _searchAllSources,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_sourceResults.isEmpty)
                Text('正在准备播放源…',
                    style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.5)))
              else if (results.isEmpty && !loading)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('未找到播放资源',
                        style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withValues(alpha: 0.5))),
                    const SizedBox(height: 8),
                    TextButton(onPressed: _searchAllSources, child: const Text('重试')),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (item, source) in results)
                      _resourceCard(item, source),
                  ],
                ),
              if (failed.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${failed.length} 个源无结果或失败（${failed.map((r) => r.source.name).join('、')}）',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF5A5A5F)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _resourceCard(VideoItem item, VideoSource source) {
    final expanded = identical(_expandedItem, item);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _expandItem(item, source),
              borderRadius: BorderRadius.circular(12),
              hoverColor: const Color(0x14007AFF),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E5EA)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF1C1C1E)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        source.name,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF007AFF)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded) _episodeArea(),
        ],
      ),
    );
  }

  Widget _episodeArea() {
    if (_episodesLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
            child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (_episodesError != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Text(_episodesError!,
                style: const TextStyle(
                    fontSize: 12, color: Colors.redAccent)),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                final item = _expandedItem;
                final source = _expandedSource;
                if (item == null || source == null) return;
                _loadEpisodes(item, source);
              },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    final eps = _episodes ?? const <VideoEpisode>[];
    if (eps.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text('暂无剧集',
            style: TextStyle(fontSize: 12, color: Color(0xFF5A5A5F))),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final ep in eps)
            PillButton(label: ep.title, onTap: () => _playEpisode(ep)),
        ],
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
        'RELEASING' || 'Currently Airing' => '连载中',
        'FINISHED' || 'Finished Airing' => '已完结',
        'NOT_YET_RELEASED' || 'Not yet aired' => '未播出',
        'CANCELLED' => '已取消',
        'HIATUS' => '停更',
        _ => status,
      };
}
