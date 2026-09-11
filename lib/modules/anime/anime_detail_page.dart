import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/work.dart';
import '../../core/widgets/rating_stars.dart';
import '../../core/video/agedm_source.dart';
import '../../core/video/gimy_source.dart';
import '../../core/video/stream_resolver.dart';
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

  @override
  void initState() {
    super.initState();
    _work = widget.work;
    _load();
  }

  Future<void> _load() async {
    try {
      final enriched = await ref.read(metadataServiceProvider).detail(widget.work);
      if (mounted) setState(() { _work = enriched; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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
            child: CustomScrollView(
              slivers: [
                _infoSection(w, cs, score, episodes, seasonYear, format, status),
                if (w.tags.isNotEmpty) _tagsRow(w.tags),
                _summarySection(w.summary, cs),
                _playSection(w, cs),
              ],
            ),
          ),
          _bottomBar(w),
        ],
      ),
    );
  }

  Widget _header(Work w, ColorScheme cs) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4),
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
            child: Text(
              w.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface),
            ),
          ),
        ],
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
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 110,
                height: 154,
                child: w.coverUrl != null && w.coverUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: w.coverUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _coverPlaceholder(cs),
                      )
                    : _coverPlaceholder(cs),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    w.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.35),
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
                        if (episodes != null) _metaChip(Icons.live_tv_rounded, '$episodes 话', const Color(0xFF007AFF)),
                        if (seasonYear != null) _metaChip(Icons.calendar_today_rounded, '$seasonYear', const Color(0xFF5856D6)),
                        if (status != null) _metaChip(Icons.info_outline_rounded, _statusLabel(status), Colors.teal),
                        if (format != null) _metaChip(Icons.movie_outlined, format, Colors.deepPurple),
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
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
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
          colors: [cs.primary.withValues(alpha: 0.1), cs.tertiary.withValues(alpha: 0.05)],
        ),
      ),
      child: Center(child: Icon(Icons.image_outlined, size: 24, color: cs.primary.withValues(alpha: 0.2))),
    );
  }

  Widget _tagsRow(List<String> tags) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: tags
              .map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFE8F0FE), borderRadius: BorderRadius.circular(20)),
                    child: Text(t, style: const TextStyle(fontSize: 11, color: Color(0xFF007AFF), fontWeight: FontWeight.w500)),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('简介', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface)),
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
              Text('暂无简介', style: TextStyle(fontSize: 13.5, color: cs.onSurface.withValues(alpha: 0.35)))
            else
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Text(
                  summary,
                  maxLines: _expanded ? null : 4,
                  overflow: _expanded ? null : TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, height: 1.65, color: cs.onSurface.withValues(alpha: 0.7)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _playSection(Work w, ColorScheme cs) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('播放源', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (var i = 0; i < _sources.length; i++)
                      ChoiceChip(
                        label: Text(_sources[i].name),
                        selected: _sourceIndex == i,
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
                  const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)))
                else if (_videoError != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_videoError!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
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
                    onPressed: () => _searchVideos(w),
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('搜索播放资源'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultList(ColorScheme cs) {
    final results = _videoResults!;
    if (results.isEmpty) {
      return Text('未找到资源', style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.5)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in results)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _loadEpisodes(item),
          ),
      ],
    );
  }

  Widget _episodeGrid(ColorScheme cs) {
    final eps = _videoEpisodes!;
    if (eps.isEmpty) {
      return Text('暂无剧集', style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.5)));
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final ep in eps)
          InkWell(
            onTap: () => _playEpisode(ep),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 104,
              height: 44,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.06),
                border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                ep.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.primary),
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

  Future<void> _playEpisode(VideoEpisode ep) async {
    final messenger = ScaffoldMessenger.of(context);
    var cancelled = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: const Row(
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 16),
            Text('正在解析播放地址…'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              cancelled = true;
              Navigator.of(dialogContext).pop();
            },
            child: const Text('取消'),
          ),
        ],
      ),
    );
    final url = await StreamResolver().resolve(ep.playUrl);
    if (!mounted) return;
    if (cancelled) return;
    Navigator.of(context).pop();
    if (url == null) {
      messenger.showSnackBar(const SnackBar(content: Text('无法解析播放地址')));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VideoPlayerPage(title: _work.title, streamUrl: url)),
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

  Widget _bottomBar(Work w) {
    final anilistId = w.anilistId;
    final malId = w.malId;
    final hasLink = anilistId != null || malId != null;
    final label = anilistId != null ? '在 AniList 查看' : '在 MyAnimeList 查看';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        border: Border(top: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton.icon(
          onPressed: hasLink
              ? () async {
                  final uri = anilistId != null
                      ? Uri.parse('https://anilist.co/anime/$anilistId')
                      : Uri.parse('https://myanimelist.net/anime/$malId');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              : null,
          icon: const Icon(Icons.open_in_new_rounded, size: 20),
          label: Text(label),
        ),
      ),
    );
  }
}
