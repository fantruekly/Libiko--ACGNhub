import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/models/anime_extra.dart';
import '../../core/models/work.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/widgets/rating_stars.dart';
import '../../core/widgets/smooth_route.dart';
import '../../core/widgets/window_controls.dart';
import '../../core/video/agedm_source.dart';
import '../../core/video/gimy_source.dart';
import '../../core/video/video_source.dart';
import 'anime_providers.dart';
import 'video_player_page.dart';

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
  final List<VideoSource> _sources = [AgedmSource(), GimySource()];
  int _sourceIndex = 0;
  List<VideoItem>? _videoResults;
  List<VideoEpisode>? _videoEpisodes;
  bool _videoLoading = false;
  String? _videoError;
  int _videoGen = 0;
  VideoItem? _selectedItem;
  Future<void> Function()? _retry;
  List<AnimeCharacter>? _characters;
  List<RelatedWork>? _related;
  bool _loadingExtras = false;

  @override
  void initState() {
    super.initState();
    _work = widget.work;
    _load();
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
                    unselectedLabelColor: Color(0xFF8E8E93),
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
            const SizedBox(width: 16),
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
                      const SizedBox(height: 10),
                    ],
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

  Widget _playSection(Work w, ColorScheme cs) {
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
              Text('播放源',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (var i = 0; i < _sources.length; i++)
                    ChoiceChip(
                      label: Text(_sources[i].name),
                      selected: _sourceIndex == i,
                      showCheckmark: false,
                      selectedColor: cs.primary.withValues(alpha: 0.14),
                      backgroundColor: cs.primary.withValues(alpha: 0.05),
                      side: BorderSide(
                          color: cs.primary.withValues(
                              alpha: _sourceIndex == i ? 0.45 : 0.18)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      onSelected: (_) {
                        setState(() {
                          _videoGen++;
                          _sourceIndex = i;
                          _videoResults = null;
                          _videoEpisodes = null;
                          _videoError = null;
                          _selectedItem = null;
                          _videoLoading = false;
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_videoLoading)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(strokeWidth: 2)))
              else if (_videoError != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_videoError!,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 13)),
                    if (_retry != null)
                      TextButton(onPressed: _retry, child: const Text('重试')),
                  ],
                )
              else if (_videoEpisodes != null) ...[
                if (_selectedItem != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _videoEpisodes = null),
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('返回结果'),
                    ),
                  ),
                _episodeGrid(cs),
              ] else if (_videoResults != null)
                _resultList(cs)
              else
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    backgroundColor: const Color(0x14007AFF),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _searchVideos(w),
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('搜索播放资源'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultList(ColorScheme cs) {
    final results = _videoResults!;
    if (results.isEmpty) {
      return Text('未找到资源',
          style: TextStyle(
              fontSize: 13, color: cs.onSurface.withValues(alpha: 0.5)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in results)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title:
                Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _loadEpisodes(item),
          ),
      ],
    );
  }

  Widget _episodeGrid(ColorScheme cs) {
    final eps = _videoEpisodes!;
    if (eps.isEmpty) {
      return Text('暂无剧集',
          style: TextStyle(
              fontSize: 13, color: cs.onSurface.withValues(alpha: 0.5)));
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final ep in eps)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _playEpisode(ep),
              borderRadius: BorderRadius.circular(10),
              hoverColor: cs.primary.withValues(alpha: 0.12),
              splashColor: cs.primary.withValues(alpha: 0.16),
              child: Container(
                width: 104,
                height: 44,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.06),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  ep.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: cs.primary),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _searchVideos(Work w) async {
    final gen = ++_videoGen;
    final source = _sources[_sourceIndex];
    setState(() {
      _videoLoading = true;
      _videoError = null;
      _videoResults = null;
      _videoEpisodes = null;
      _retry = () => _searchVideos(w);
    });
    try {
      final results = await source.search(w.title);
      if (!mounted || gen != _videoGen) return;
      setState(() {
        _videoResults = results;
        _videoLoading = false;
        if (results.isEmpty) _videoError = '未找到资源';
      });
    } catch (e) {
      if (!mounted || gen != _videoGen) return;
      setState(() {
        _videoLoading = false;
        _videoError = '搜索失败，请重试';
      });
    }
  }

  Future<void> _loadEpisodes(VideoItem item) async {
    final gen = ++_videoGen;
    final source = _sources[_sourceIndex];
    setState(() {
      _selectedItem = item;
      _videoLoading = true;
      _videoError = null;
      _retry = () => _loadEpisodes(item);
    });
    try {
      final eps = await source.episodes(item.detailUrl);
      if (!mounted || gen != _videoGen) return;
      setState(() {
        _videoEpisodes = eps;
        _videoLoading = false;
      });
    } catch (e) {
      if (!mounted || gen != _videoGen) return;
      setState(() {
        _videoLoading = false;
        _videoError = '获取剧集失败，请重试';
      });
    }
  }

  void _playEpisode(VideoEpisode ep) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerPage(
          title: _work.title,
          episodes: _videoEpisodes ?? const [],
          initialIndex: ep.index,
        ),
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
