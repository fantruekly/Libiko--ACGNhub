import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_selector/file_selector.dart';
import '../../core/account/sync_service.dart';
import '../../core/models/anime_extra.dart';
import '../../core/models/work.dart';
import '../../core/models/watch_record.dart';
import '../../core/platform.dart';
import '../../core/services/cache_manager.dart';
import '../../core/services/follow_manager.dart';
import '../../core/widgets/button_grid.dart';
import '../../core/widgets/desktop_drag_area.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/widgets/pill_button.dart';
import '../../core/widgets/rating_stars.dart';
import '../../core/widgets/smooth_route.dart';
import '../../core/widgets/window_controls.dart';
import '../../core/video/cancellation.dart';
import '../../core/video/playback_error.dart';
import '../../core/video/rule_store.dart';
import '../../core/video/stream_resolver.dart';
import '../../core/video/title_match.dart';
import '../../core/video/video_source.dart';
import '../../core/video/video_sources.dart';
import 'anime_providers.dart';
import 'resolve_dialog.dart';
import 'video_player_page.dart';

enum _SourceStatus { loading, done, failed }

class _SourceResult {
  final VideoSource source;
  _SourceStatus status = _SourceStatus.loading;
  List<VideoItem> items = const [];
  VideoItem? best;
  List<VideoItem> alternatives = const [];
  int seq = 0;
  _SourceResult(this.source);
}

EdgeInsets _detailInsets(BuildContext context,
    {double top = 20, double bottom = 24}) {
  final side = ((MediaQuery.sizeOf(context).width - 1120) / 2)
      .clamp(16.0, double.infinity)
      .toDouble();
  return EdgeInsets.fromLTRB(side, top, side, bottom);
}

class AnimeDetailPage extends ConsumerStatefulWidget {
  final Work work;
  final WatchRecord? resumeRecord;
  final bool autoResume;
  const AnimeDetailPage(
      {super.key,
      required this.work,
      this.resumeRecord,
      this.autoResume = false});

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
  bool _moreOpen = false;
  final _confirmingSources = <String>{};
  bool _autoResumeAttempted = false;
  VideoSource? _expandedSource;
  List<VideoEpisode>? _episodes;
  bool _episodesLoading = false;
  String? _episodesError;
  List<AnimeCharacter>? _characters;
  List<RelatedWork>? _related;
  bool _loadingExtras = false;
  Timer? _searchTimer;
  bool _disposed = false;
  final _searchCancel = CancellationToken();

  @override
  void initState() {
    super.initState();
    _work = widget.work;
    _load();
  }

  @override
  void dispose() {
    _disposed = true;
    _searchCancel.cancel();
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
                  TabBar(
                    labelColor: cs.primary,
                    unselectedLabelColor: cs.onSurfaceVariant,
                    indicatorColor: cs.primary,
                    dividerColor: cs.outlineVariant,
                    tabs: const [
                      Tab(text: '概览'),
                      Tab(text: '角色'),
                      Tab(text: '关联')
                    ],
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
        if (w.tags.isNotEmpty) _tagsRow(w.tags, cs),
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
      return Center(
          child: Text('暂无角色信息',
              style: TextStyle(
                  fontSize: 14, color: cs.onSurface.withValues(alpha: 0.4))));
    }
    return ListView.builder(
      padding: _detailInsets(context),
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
                child:
                    SizedBox(width: 56, height: 56, child: _image(c.image, cs)),
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
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (c.relation != null && c.relation!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(c.relation!,
                                style:
                                    TextStyle(fontSize: 11, color: cs.primary)),
                          ),
                      ],
                    ),
                    for (final a in c.actors)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            ClipOval(
                                child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: _image(a.image, cs))),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text('CV: ${a.name}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        color: cs.onSurfaceVariant))),
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
      return Center(
          child: Text('暂无关联作品',
              style: TextStyle(
                  fontSize: 14, color: cs.onSurface.withValues(alpha: 0.4))));
    }
    return ListView.builder(
      padding: _detailInsets(context),
      itemCount: rel.length,
      itemBuilder: (context, i) {
        final r = rel[i];
        return InkWell(
          borderRadius: BorderRadius.circular(14),
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
                  child: SizedBox(
                      width: 56, height: 80, child: _image(r.image, cs)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              height: 1.35)),
                      if (r.relation != null && r.relation!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(r.relation!,
                              style:
                                  TextStyle(fontSize: 12, color: cs.primary)),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: cs.onSurface.withValues(alpha: 0.2)),
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
      cacheManager: AppCacheManager(),
      placeholder: (_, __) =>
          Container(color: cs.primary.withValues(alpha: 0.06)),
      errorWidget: (_, __, ___) =>
          Container(color: cs.primary.withValues(alpha: 0.08)),
    );
  }

  Widget _header(Work w, ColorScheme cs) {
    final topInset = isDesktop ? 0.0 : MediaQuery.of(context).padding.top;
    return DesktopDragArea(
      child: Container(
        height: 48 + topInset,
        padding: EdgeInsets.only(left: 4, top: topInset),
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
            if (isDesktop) const WindowControls(),
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
    final compact = MediaQuery.sizeOf(context).width < 560;
    return Padding(
      padding: _detailInsets(context, top: 20, bottom: 12),
      child: GlassSurface(
        blur: 0,
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'work_${w.id}',
              child: RepaintBoundary(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: compact ? 76 : 110,
                    height: compact ? 108 : 154,
                    child: w.coverUrl != null && w.coverUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: w.coverUrl!,
                            fit: BoxFit.cover,
                            memCacheWidth: 300,
                            cacheManager: AppCacheManager(),
                            errorWidget: (_, __, ___) => _coverPlaceholder(cs),
                          )
                        : _coverPlaceholder(cs),
                  ),
                ),
              ),
            ),
            SizedBox(width: compact ? 14 : 24),
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
                        color: cs.primary.withValues(alpha: 0.3),
                      ),
                    )
                  else ...[
                    if (score != null) ...[
                      RatingStars(score: score, size: compact ? 16 : 18),
                      const SizedBox(height: 14),
                    ],
                    _followButton(w),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (episodes != null)
                          _metaChip(
                              Icons.live_tv_rounded, '$episodes 话', cs.primary),
                        if (seasonYear != null)
                          _metaChip(Icons.calendar_today_rounded, '$seasonYear',
                              cs.primary),
                        if (status != null)
                          _metaChip(Icons.info_outline_rounded,
                              _statusLabel(status), cs.primary),
                        if (format != null)
                          _metaChip(Icons.movie_outlined, format, cs.primary),
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
      final cs = Theme.of(context).colorScheme;
      return FilledButton.icon(
        style: followed
            ? FilledButton.styleFrom(
                backgroundColor: cs.surfaceContainerHighest,
                foregroundColor: cs.onSurfaceVariant,
              )
            : null,
        onPressed: () {
          ref.read(followProvider.notifier).toggle(w);
          ref.read(syncProvider).schedule();
        },
        icon:
            Icon(followed ? Icons.check_rounded : Icons.add_rounded, size: 16),
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
          borderRadius: BorderRadius.circular(14)),
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
            cs.primary.withValues(alpha: 0.04)
          ],
        ),
      ),
      child: Center(
          child: Icon(Icons.image_outlined,
              size: 24, color: cs.primary.withValues(alpha: 0.2))),
    );
  }

  Widget _tagsRow(List<String> tags, ColorScheme cs) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: _detailInsets(context, top: 12, bottom: 12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags
              .map((t) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outlineVariant, width: 0.5),
                    ),
                    child: Text(
                      t,
                      style: TextStyle(
                          fontSize: 12.5,
                          color: cs.onSurfaceVariant,
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
        padding: _detailInsets(context, top: 4, bottom: 12),
        child: GlassSurface(
          blur: 0,
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          padding: const EdgeInsets.all(16),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
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
                    color: cs.primary.withValues(alpha: 0.3),
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
      _confirmingSources.clear();
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
    if (mounted &&
        gen == _searchGen &&
        widget.autoResume &&
        widget.resumeRecord != null &&
        !_autoResumeAttempted) {
      _autoResumeAttempted = true;
      await _resumeHistory();
    }
  }

  Future<void> _searchOne(_SourceResult r, int gen) async {
    if (_disposed) return;
    try {
      final queries = titleSearchQueries(_work.title, _work.extra);
      final items = <VideoItem>[];
      final seen = <String>{};
      final clock = Stopwatch()..start();
      var succeeded = false;
      for (final query in queries) {
        if (_disposed || gen != _searchGen) return;
        final remaining = const Duration(seconds: 12) - clock.elapsed;
        if (remaining <= Duration.zero) break;
        try {
          final found = await r.source
              .search(query, cancel: _searchCancel)
              .timeout(remaining);
          succeeded = true;
          for (final item in found) {
            if (seen.add(item.detailUrl)) items.add(item);
          }
        } catch (_) {
          // Another metadata alias may still be searchable on this source.
        }
        if (bestMatchIndex(_work.title, [for (final it in items) it.title],
                aliases: queries.skip(1),
                format: _work.extra['format'] as String?) >=
            0) {
          break;
        }
      }
      if (!succeeded) throw StateError('搜索源未返回结果');
      if (!mounted || gen != _searchGen) return;
      setState(() {
        r.items = items;
        if (items.isEmpty) {
          r.best = null;
          r.alternatives = const [];
        } else {
          final idx = bestMatchIndex(
              _work.title, [for (final it in items) it.title],
              aliases: queries.skip(1),
              format: _work.extra['format'] as String?);
          r.best = idx < 0 ? null : items[idx];
          r.alternatives = [
            for (var i = 0; i < items.length; i++)
              if (i != idx) items[i],
          ];
        }
        r.status = _SourceStatus.done;
        r.seq = ++_searchSeq;
      });
    } catch (_) {
      if (!mounted || gen != _searchGen) return;
      setState(() => r.status = _SourceStatus.failed);
    }
  }

  List<(VideoItem, VideoSource, List<VideoItem>, bool)> get _flatResults {
    final done = _sourceResults
        .where((r) => r.status == _SourceStatus.done && r.items.isNotEmpty)
        .toList()
      ..sort((a, b) => a.seq.compareTo(b.seq));
    return [
      for (final r in done)
        (
          r.best ?? r.items.first,
          r.source,
          r.best == null ? r.items.skip(1).toList() : r.alternatives,
          r.best == null
        ),
    ];
  }

  void _confirmMatch(VideoItem item, VideoSource source) {
    setState(() {
      final result = _sourceResults.firstWhere((r) => r.source.id == source.id);
      result.best = item;
      result.alternatives =
          result.items.where((it) => !identical(it, item)).toList();
      _confirmingSources.remove(source.id);
    });
    _expandItem(item, source);
  }

  Future<void> _expandItem(VideoItem item, VideoSource source) async {
    if (identical(_expandedItem, item)) {
      setState(() {
        _expandedItem = null;
        _expandedSource = null;
        _episodes = null;
        _episodesError = null;
        _episodesLoading = false;
        _moreOpen = false;
      });
      return;
    }
    setState(() {
      _expandedItem = item;
      _moreOpen = false;
    });
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
      final eps = await source.episodes(item.detailUrl, cancel: _searchCancel);
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

  Future<void> _playEpisode(VideoEpisode ep,
      {Duration initialPosition = Duration.zero}) async {
    final episodes = List<VideoEpisode>.of(_episodes ?? const []);
    final sourceName = _expandedSource?.name ?? '';
    final index = episodes.indexOf(ep);
    if (index < 0) return;
    final messenger = ScaffoldMessenger.of(context);
    final cancel = CancellationToken();
    final outcome = await showResolveDialog(
      context,
      resolve: StreamResolver().resolve(ep.playUrl,
          userAgent: ep.userAgent,
          referer: ep.referer,
          legacy: ep.useLegacyParser,
          cancel: cancel),
      cancel: cancel,
    );
    if (!mounted || outcome.cancelled) return;
    final result = outcome.result;
    if (result == null || !result.ok) {
      messenger.showSnackBar(SnackBar(
        content: Text(resolveFailureMessage(
            _expandedSource?.name ?? '', result?.failure)),
        action: SnackBarAction(
          label: '重试',
          onPressed: () => _playEpisode(ep),
        ),
      ));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerPage(
          work: _work,
          episodes: episodes,
          initialIndex: index,
          initialCandidates: result.candidates,
          sourceName: sourceName,
          initialPosition: initialPosition,
        ),
      ),
    );
  }

  Future<void> _resumeHistory() async {
    final record = widget.resumeRecord;
    if (record == null) return;
    _SourceResult? found;
    for (final result in _sourceResults) {
      if (result.source.id == record.sourceId && result.best != null) {
        found = result;
        break;
      }
    }
    if (found == null) {
      final needsConfirmation = _sourceResults.any((result) =>
          result.source.id == record.sourceId &&
          result.items.isNotEmpty &&
          result.best == null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(needsConfirmation
            ? '原播放源的作品匹配待确认，请手动核对后继续观看'
            : '原播放源暂不可用，请手动选择线路与集数'),
      ));
      return;
    }
    setState(() {
      _expandedItem = found!.best;
    });
    await _loadEpisodes(found.best!, found.source);
    if (!mounted) return;
    if (!identical(_expandedItem, found.best) ||
        _expandedSource != found.source) {
      return;
    }
    final matches = (_episodes ?? const <VideoEpisode>[])
        .where((episode) =>
            episode.lineId == record.lineId &&
            (record.episodeKey != null
                ? episode.episodeKey == record.episodeKey
                : episode.title == record.episodeTitle))
        .toList();
    if (matches.length != 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('无法确定上次观看的剧集，请手动选集'),
      ));
      return;
    }
    await _playEpisode(matches.single,
        initialPosition: record.completed
            ? Duration.zero
            : Duration(milliseconds: record.positionMs));
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
      ref.invalidate(allVideoSourcesProvider);
      ref.invalidate(videoSourcesProvider);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('已导入规则：${rule.name}')));
      _searchAllSources();
    } on FormatException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('规则无效：${e.message}')));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('导入失败，请重试')));
    }
  }

  Widget _playSection(Work w, ColorScheme cs) {
    final results = _flatResults;
    final loading =
        _sourceResults.any((r) => r.status == _SourceStatus.loading);
    final doneCount =
        _sourceResults.where((r) => r.status != _SourceStatus.loading).length;
    final failed = _sourceResults
        .where((r) =>
            r.status == _SourceStatus.failed ||
            (r.status == _SourceStatus.done && r.items.isEmpty))
        .toList();

    return SliverToBoxAdapter(
      child: Padding(
        padding: _detailInsets(context, top: 4, bottom: 12),
        child: GlassSurface(
          blur: 0,
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          padding: const EdgeInsets.all(16),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                      child: Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('播放资源',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface)),
                      if (loading)
                        Text('搜索中 $doneCount/${_sourceResults.length}',
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant))
                      else
                        Text('共 ${results.length} 条',
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant)),
                    ],
                  )),
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
              if (widget.resumeRecord != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('resume-playback'),
                    onPressed:
                        loading || _episodesLoading ? null : _resumeHistory,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text('继续观看 · ${widget.resumeRecord!.episodeTitle}'),
                  ),
                ),
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
                    TextButton(
                        onPressed: _searchAllSources, child: const Text('重试')),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (item, source, alternatives, needsConfirmation)
                        in results)
                      _resourceCard(item, source, alternatives, cs,
                          needsConfirmation: needsConfirmation),
                  ],
                ),
              if (failed.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${failed.length} 个源无结果或失败（${failed.map((r) => r.source.name).join('、')}）',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _resourceCard(VideoItem item, VideoSource source,
      List<VideoItem> alternatives, ColorScheme cs,
      {bool needsConfirmation = false}) {
    final expanded = identical(_expandedItem, item) ||
        alternatives.any((a) => identical(a, _expandedItem));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (needsConfirmation) {
                  setState(() {
                    if (!_confirmingSources.add(source.id)) {
                      _confirmingSources.remove(source.id);
                    }
                  });
                } else {
                  _expandItem(item, source);
                }
              },
              borderRadius: BorderRadius.circular(12),
              hoverColor: cs.primary.withValues(alpha: 0.08),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.55)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, color: cs.onSurface),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (needsConfirmation) ...[
                      Text('待确认匹配',
                          style: TextStyle(fontSize: 12, color: cs.error)),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        source.name,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: cs.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (needsConfirmation && _confirmingSources.contains(source.id))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('标题或季数暂未可靠匹配，请核对后选择作品：'),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final candidate in [item, ...alternatives])
                        ActionChip(
                            label: Text(candidate.title),
                            onPressed: () => _confirmMatch(candidate, source)),
                    ]),
                  ]),
            ),
          if (expanded && !needsConfirmation) ...[
            if (alternatives.isNotEmpty) ...[
              Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const ValueKey('more-results-toggle'),
                  onTap: () => setState(() => _moreOpen = !_moreOpen),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('更多结果',
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant)),
                        Icon(
                          _moreOpen
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 16,
                          color: cs.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_moreOpen) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 4),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final alt in alternatives)
                        ActionChip(
                          label: Text(alt.title, maxLines: 1),
                          onPressed: () => _expandItem(alt, source),
                        ),
                    ],
                  ),
                ),
              ],
            ],
            _episodeArea(cs),
          ],
        ],
      ),
    );
  }

  Widget _episodeArea(ColorScheme cs) {
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
                style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
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
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('暂无剧集',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      );
    }
    final lines = <String, List<VideoEpisode>>{};
    for (final ep in eps) {
      lines.putIfAbsent(ep.lineId ?? '', () => []).add(ep);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in lines.values)
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (lines.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(line.first.lineName ?? '默认线路',
                        style: TextStyle(
                            color: cs.primary, fontWeight: FontWeight.w600)),
                  ),
                ButtonGrid(children: [
                  for (final ep in line)
                    PillButton(label: ep.title, onTap: () => _playEpisode(ep)),
                ]),
              ],
            ),
          ),
      ],
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
