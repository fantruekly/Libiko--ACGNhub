### Task 12: Create anime search and detail pages

**Files:**
- Create: `lib/modules/anime/anime_search.dart`
- Create: `lib/modules/anime/anime_detail.dart`

**Interfaces:**
- Consumes: `SourceManager`, `SearchEngine`, `AnimeSource`, `WorkCard` (Tasks 3, 6, 7, 9)
- Produces: `AnimeSearchPage`, `AnimeDetailPage` widgets

- [ ] **Step 1: Write AnimeSearchPage**

Create `lib/modules/anime/anime_search.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/work.dart';
import '../../core/services/search_engine.dart';
import '../../core/widgets/work_card.dart';
import 'anime_providers.dart';
import 'anime_detail.dart';

class AnimeSearchPage extends ConsumerStatefulWidget {
  const AnimeSearchPage({super.key});

  @override
  ConsumerState<AnimeSearchPage> createState() => _AnimeSearchPageState();
}

class _AnimeSearchPageState extends ConsumerState<AnimeSearchPage> {
  final _controller = TextEditingController();
  final _searchEngine = SearchEngine(SourceManager());
  List<Work> _results = [];
  bool _loading = false;
  String? _error;

  Future<void> _search() async {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final manager = ref.read(sourceManagerProvider);
      final engine = SearchEngine(manager);
      final results = await engine.getAggregatedResults(WorkType.anime, keyword);
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '鎼滅储鍔ㄦ极...',
            border: InputBorder.none,
          ),
          onSubmitted: (_) => _search(),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: _search),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _search, child: const Text('閲嶈瘯')),
                    ],
                  ),
                )
              : _results.isEmpty
                  ? const Center(child: Text('杈撳叆鍏抽敭璇嶆悳绱㈠姩婕?))
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.65,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final work = _results[index];
                        return WorkCard(
                          work: work,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AnimeDetailPage(work: work),
                              ),
                            );
                          },
                        );
                      },
                    ),
    );
  }
}
```

- [ ] **Step 2: Write AnimeDetailPage**

Create `lib/modules/anime/anime_detail.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/models/work.dart';
import '../../core/models/chapter.dart';
import 'anime_player.dart';

class AnimeDetailPage extends StatefulWidget {
  final Work work;

  const AnimeDetailPage({super.key, required this.work});

  @override
  State<AnimeDetailPage> createState() => _AnimeDetailPageState();
}

class _AnimeDetailPageState extends State<AnimeDetailPage> {
  List<Chapter> _chapters = [];
  bool _loadingChapters = false;

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    setState(() => _loadingChapters = true);
    try {
      // TODO: Fetch chapters from source in Task 13
      setState(() => _loadingChapters = false);
    } catch (e) {
      setState(() => _loadingChapters = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final work = widget.work;
    return Scaffold(
      appBar: AppBar(title: Text(work.title)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (work.coverUrl != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: work.coverUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.grey[900]),
                  errorWidget: (_, __, ___) => Container(color: Colors.grey[900]),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(work.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (work.author != null)
                    Text('浣滆€? ${work.author}', style: TextStyle(color: Colors.grey[400])),
                  const SizedBox(height: 4),
                  Text('鏉ユ簮: ${work.sourceName}', style: TextStyle(color: Colors.grey[500])),
                  if (work.tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: work.tags.map((tag) => Chip(
                            label: Text(tag, style: const TextStyle(fontSize: 12)),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          )).toList(),
                    ),
                  ],
                  if (work.summary != null && work.summary!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('绠€浠?, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(work.summary!, style: const TextStyle(fontSize: 14, height: 1.5)),
                  ],
                  const SizedBox(height: 24),
                  const Text('鍓ч泦鍒楄〃', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_loadingChapters)
                    const Center(child: CircularProgressIndicator())
                  else if (_chapters.isEmpty)
                    const Text('鏆傛棤鍓ч泦淇℃伅', style: TextStyle(color: Colors.grey))
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _chapters.length,
                      itemBuilder: (context, index) {
                        final ch = _chapters[index];
                        return ListTile(
                          leading: CircleAvatar(child: Text('${index + 1}')),
                          title: Text(ch.title),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AnimePlayerPage(
                                  chapterTitle: ch.title,
                                  videoUrl: ch.url ?? '',
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Update anime_home.dart to use the new search page**

Replace the inline `AnimeSearchPage` stub in `lib/modules/anime/anime_home.dart` with an import:

```dart
import 'anime_search.dart';
```

Remove the stub `AnimeSearchPage` class from `anime_home.dart`.

- [ ] **Step 4: Commit**

```bash
git add lib/modules/anime/
git commit -m "feat(anime): add search and detail pages"
```

---


