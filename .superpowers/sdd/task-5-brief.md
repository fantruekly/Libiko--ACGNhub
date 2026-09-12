### Task 5: Detail-page resource section (auto-search + cards + episodes)

**Files:**
- Modify: `lib/modules/anime/anime_detail_page.dart`

**Interfaces:**
- Consumes: `videoSourcesProvider` (Task 4); `VideoSource`, `VideoItem`, `VideoEpisode` (existing); `StreamResolver` (existing); `VideoPlayerPage` (existing).
- Produces: nothing consumed by later tasks (UI only).

- [ ] **Step 1: Update imports and state fields**

In `lib/modules/anime/anime_detail_page.dart`, replace the video imports (lines 11–13) with:

```dart
import '../../core/video/stream_resolver.dart';
import '../../core/video/video_source.dart';
import '../../core/video/video_sources.dart';
```

Replace the state fields (lines 29–36) — delete `_sources`, `_sourceIndex`, `_videoResults`, `_videoEpisodes`, `_videoLoading`, `_videoError`, `_videoGen`, `_selectedItem`, `_retry` and add:

```dart
  List<_SourceResult> _sourceResults = const [];
  int _searchGen = 0;
  int _searchSeq = 0;
  VideoItem? _expandedItem;
  VideoSource? _expandedSource;
  List<VideoEpisode>? _episodes;
  bool _episodesLoading = false;
  String? _episodesError;
```

Add these top-level types after the imports (before `class AnimeDetailPage`):

```dart
enum _SourceStatus { loading, done, failed }

class _SourceResult {
  final VideoSource source;
  _SourceStatus status = _SourceStatus.loading;
  List<VideoItem> items = const [];
  int seq = 0;
  _SourceResult(this.source);
}
```

- [ ] **Step 2: Trigger the search after the detail loads**

In `_load()`, replace the final line `_loadExtras();` with:

```dart
    _loadExtras();
    _scheduleSearch();
```

Add this method to `_AnimeDetailPageState`:

```dart
  void _scheduleSearch() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _searchAllSources();
    });
  }
```

- [ ] **Step 3: Replace the playback methods**

Delete `_searchVideos`, `_loadEpisodes`, `_playEpisode` and the old `_playSection` / `_resultList` / `_episodeGrid`, and add:

```dart
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
      _episodes = null;
      _episodesError = null;
      _episodesLoading = false;
    });

    final queue = [..._sourceResults];
    var next = 0;
    Future<void> worker() async {
      while (next < queue.length) {
        final r = queue[next];
        next++;
        await _searchOne(r, gen);
      }
    }

    await Future.wait([for (var i = 0; i < 3; i++) worker()]);
  }

  Future<void> _searchOne(_SourceResult r, int gen) async {
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
        _episodes = null;
        _episodesError = null;
        _episodesLoading = false;
      });
      return;
    }
    setState(() {
      _expandedItem = item;
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
          title: _work.title,
          episodes: _episodes ?? const [],
          initialIndex: ep.index,
        ),
      ),
    );
  }
```

- [ ] **Step 4: Replace `_playSection` with the aggregated resource section**

Replace the whole `_playSection` method with:

```dart
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
                            fontSize: 12, color: Color(0xFF8E8E93)))
                  else
                    Text('共 ${results.length} 条',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF8E8E93))),
                  const Spacer(),
                  if (loading)
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
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
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
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
                _expandItem(item, source);
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
            style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final ep in eps)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _playEpisode(ep),
                borderRadius: BorderRadius.circular(10),
                hoverColor: const Color(0x1F007AFF),
                child: Container(
                  width: 104,
                  height: 44,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0x0F007AFF),
                    border: Border.all(color: const Color(0x4D007AFF)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    ep.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF007AFF)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
```

Note: `_expandedSource` is set in `_expandItem` (Step 3) and read by the retry above.

- [ ] **Step 5: Verify it compiles**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter analyze lib`
Expected: `No issues found!`

- [ ] **Step 6: Build**

Run: `$env:Path = "C:\flutter\bin;$env:Path"; flutter build windows --debug`
Expected: `Built build\windows\x64\runner\Debug\acgnhub.exe`

- [ ] **Step 7: Commit**

```bash
git add lib/modules/anime/anime_detail_page.dart
git commit -m "feat(anime): aggregate all playback sources in the detail page"
```

---
