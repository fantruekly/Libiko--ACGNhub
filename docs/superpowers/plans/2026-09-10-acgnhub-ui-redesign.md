# ACGNhub UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign ACGNhub from bottom-navigation Material 3 to left-sidebar Infuse-style layout, covering all 4 modules (anime, comic, novel, game) plus novel reader.

**Architecture:** Modify `main.dart` theme tokens to iOS-light palette; replace `MainShell` bottom NavigationBar with collapsible left sidebar; redesign `AnimeHomePage` with Hero card + pill filters; create comic/novel/game module pages with shared patterns; add novel reader with serif typography and settings panel. Existing core layer (models, services) remains unchanged.

**Tech Stack:** Flutter 3.x, Dart 3.x, Riverpod (state), cached_network_image (images), Material 3 theme

## Global Constraints

- Target platform: Windows
- Keep existing core layer files unchanged (`lib/core/**`)
- Keep existing `anime_providers.dart`, `bangumi_service.dart`, `anime_source.dart`, `anime_rule.dart` unchanged
- Preserve all existing functionality — redesign is visual only
- No new dependencies unless required by spec (none expected)
- Use Material 3 `ThemeData` — do not hardcode colors in widgets
- Sidebar icons use Material Icons (no custom SVG needed)

---

### Task 1: Update theme tokens in main.dart

**Files:**
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: None
- Produces: Updated `ThemeData` with light iOS palette (`--bg #f2f2f7`, `--accent #007AFF`), correct typography scale, Card theme matching spec (12px radius, no elevation)

- [ ] **Step 1: Replace theme definition in main.dart**

Replace the entire `ACGNhubApp` class in `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/storage/database.dart';
import 'shell/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.init();
  runApp(const ProviderScope(child: ACGNhubApp()));
}

class ACGNhubApp extends StatelessWidget {
  static const _accent = Color(0xFF007AFF);

  const ACGNhubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ACGNhub',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _accent,
          brightness: Brightness.light,
          primary: _accent,
        ),
        scaffoldBackgroundColor: const Color(0xFFF2F2F7),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          backgroundColor: Color(0xFFFFFFFF),
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1C1C1E),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFFFFFFFF),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            backgroundColor: _accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w590),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            foregroundColor: _accent,
            side: const BorderSide(color: _accent, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w590),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: _accent,
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: _accent,
        ),
      ),
      home: const MainShell(),
    );
  }
}
```

- [ ] **Step 2: Verify build**

```bash
cd D:\ACGNhub
flutter build windows --debug
```

Expected: Build succeeds with no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "style: update theme to iOS-light palette with #007AFF accent"
```

---

### Task 2: Replace bottom navigation with collapsible left sidebar

**Files:**
- Create: `lib/shell/app_sidebar.dart`
- Modify: `lib/shell/main_shell.dart`

**Interfaces:**
- Consumes: None (sidebar is self-contained)
- Produces: `AppSidebar` widget with `onModuleChanged(int)` callback, `MainShell` updated to use Row(sidebar, Expanded(content))

- [ ] **Step 1: Create sidebar widget**

Create `lib/shell/app_sidebar.dart`:

```dart
import 'package:flutter/material.dart';

class AppSidebar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onModuleChanged;
  final VoidCallback? onSettingsTap;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onModuleChanged,
    this.onSettingsTap,
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> with SingleTickerProviderStateMixin {
  static const _expandedWidth = 72.0;
  static const _collapsedWidth = 12.0;

  late AnimationController _animCtrl;
  late Animation<double> _widthAnim;
  bool _expanded = true;

  static const _items = <_SidebarItem>[
    _SidebarItem(icon: Icons.live_tv_rounded, label: '动漫'),
    _SidebarItem(icon: Icons.menu_book_rounded, label: '漫画'),
    _SidebarItem(icon: Icons.auto_stories_rounded, label: '轻小说'),
    _SidebarItem(icon: Icons.games_rounded, label: '游戏'),
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _widthAnim = Tween<double>(begin: _expandedWidth, end: _collapsedWidth)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut));
    _animCtrl.value = 1.0;
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void toggle() {
    setState(() {
      if (_expanded) {
        _animCtrl.reverse();
      } else {
        _animCtrl.forward();
      }
      _expanded = !_expanded;
    });
  }

  void _onScrollOnCollapsed(PointerScrollEvent event) {
    if (_expanded) return;
    final delta = event.scrollDelta.dy;
    final count = _items.length;
    final newIndex = delta > 0
        ? (widget.selectedIndex + 1).clamp(0, count - 1)
        : (widget.selectedIndex - 1).clamp(0, count - 1);
    if (newIndex != widget.selectedIndex) {
      widget.onModuleChanged(newIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _widthAnim,
      builder: (context, child) {
        final w = _widthAnim.value;
        if (w < 20) {
          return _buildCollapsed(colorScheme);
        }
        return _buildExpanded(colorScheme);
      },
    );
  }

  Widget _buildExpanded(ColorScheme colorScheme) {
    return Container(
      width: _expandedWidth,
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9FC),
        border: Border(right: BorderSide(color: const Color(0xFFE5E5EA).withValues(alpha: 0.6))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          IconButton(
            icon: const Icon(Icons.menu_rounded, size: 22),
            color: colorScheme.onSurface.withValues(alpha: 0.4),
            onPressed: toggle,
            tooltip: '收起侧边栏',
          ),
          const SizedBox(height: 16),
          ..._items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            final selected = i == widget.selectedIndex;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: InkWell(
                onTap: () => widget.onModuleChanged(i),
                borderRadius: BorderRadius.circular(0),
                child: SizedBox(
                  width: _expandedWidth,
                  height: 56,
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        height: 24,
                        decoration: BoxDecoration(
                          color: selected ? colorScheme.primary : Colors.transparent,
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(3),
                            bottomRight: Radius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            item.icon,
                            size: 24,
                            color: selected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                              color: selected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.45),
                              letterSpacing: 0.02,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          Divider(indent: 16, endIndent: 16, color: const Color(0xFFE5E5EA).withValues(alpha: 0.5)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: InkWell(
              onTap: widget.onSettingsTap,
              borderRadius: BorderRadius.circular(0),
              child: SizedBox(
                width: _expandedWidth,
                height: 56,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.settings_rounded, size: 24, color: colorScheme.onSurface.withValues(alpha: 0.4)),
                    const SizedBox(height: 2),
                    Text(
                      '设置',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: colorScheme.onSurface.withValues(alpha: 0.45),
                        letterSpacing: 0.02,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCollapsed(ColorScheme colorScheme) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Listener(
        onPointerSignal: _onScrollOnCollapsed,
        child: GestureDetector(
          onTap: toggle,
          child: Container(
            width: _collapsedWidth,
            color: const Color(0xFFE5E5EA).withValues(alpha: 0.3),
            child: Center(
              child: Icon(
                Icons.chevron_right_rounded,
                size: 14,
                color: colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarItem {
  final IconData icon;
  final String label;
  const _SidebarItem({required this.icon, required this.label});
}
```

- [ ] **Step 2: Rewrite MainShell**

Replace `lib/shell/main_shell.dart`:

```dart
import 'package:flutter/material.dart';
import '../modules/anime/anime_home.dart';
import '../modules/comic/comic_home.dart';
import '../modules/novel/novel_home.dart';
import '../modules/game/game_home.dart';
import 'app_sidebar.dart';
import 'settings_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _pages = <Widget>[
    const AnimeHomePage(),
    const _ComicHomeWrapper(),
    const _NovelHomeWrapper(),
    const _GameHomeWrapper(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          AppSidebar(
            selectedIndex: _currentIndex,
            onModuleChanged: (i) => setState(() => _currentIndex = i),
            onSettingsTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
          ),
          Expanded(child: _pages[_currentIndex]),
        ],
      ),
    );
  }
}

class _ComicHomeWrapper extends StatelessWidget {
  const _ComicHomeWrapper();
  @override
  Widget build(BuildContext context) {
    return const ComicHomePage();
  }
}

class _NovelHomeWrapper extends StatelessWidget {
  const _NovelHomeWrapper();
  @override
  Widget build(BuildContext context) {
    return const NovelHomePage();
  }
}

class _GameHomeWrapper extends StatelessWidget {
  const _GameHomeWrapper();
  @override
  Widget build(BuildContext context) {
    return const GameHomePage();
  }
}
```

- [ ] **Step 3: Verify build**

```bash
cd D:\ACGNhub
flutter build windows --debug
```

Expected: Build succeeds. The comic/novel/game imports reference files that don't exist yet — create stub files first.

- [ ] **Step 4: Create stub files for comic, novel, game modules**

```bash
cd D:\ACGNhub
mkdir -p lib\modules\comic
mkdir -p lib\modules\novel
mkdir -p lib\modules\game
```

Create `lib/modules/comic/comic_home.dart`:
```dart
import 'package:flutter/material.dart';

class ComicHomePage extends StatelessWidget {
  const ComicHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('漫画')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_rounded, size: 56, color: colorScheme.onSurface.withValues(alpha: 0.12)),
            const SizedBox(height: 16),
            Text('漫画模块将在阶段2实现', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.3), fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
```

Create `lib/modules/novel/novel_home.dart`:
```dart
import 'package:flutter/material.dart';

class NovelHomePage extends StatelessWidget {
  const NovelHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('轻小说')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_rounded, size: 56, color: colorScheme.onSurface.withValues(alpha: 0.12)),
            const SizedBox(height: 16),
            Text('轻小说模块将在阶段3实现', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.3), fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
```

Create `lib/modules/game/game_home.dart`:
```dart
import 'package:flutter/material.dart';

class GameHomePage extends StatelessWidget {
  const GameHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('游戏')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.games_rounded, size: 56, color: colorScheme.onSurface.withValues(alpha: 0.12)),
            const SizedBox(height: 16),
            Text('游戏模块将在阶段4实现', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.3), fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Verify build with stubs**

```bash
cd D:\ACGNhub
flutter build windows --debug
```

Expected: Build succeeds.

- [ ] **Step 6: Commit**

```bash
git add lib/shell/app_sidebar.dart lib/shell/main_shell.dart lib/modules/comic/ lib/modules/novel/ lib/modules/game/
git commit -m "feat(shell): replace bottom nav with collapsible left sidebar"
```

---

### Task 3: Redesign anime home page

**Files:**
- Modify: `lib/modules/anime/anime_home.dart`

**Interfaces:**
- Consumes: `trendingAnimeProvider` (existing Riverpod provider), `Work`, `WorkCard`, `BangumiDetailPage`
- Produces: Redesigned `AnimeHomePage` with Hero card + pill filters `[继续观看][热门推荐][最近更新]` + grid

- [ ] **Step 1: Rewrite anime_home.dart**

Replace `lib/modules/anime/anime_home.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'anime_providers.dart';
import 'anime_search.dart';
import 'bangumi_detail_page.dart';
import '../../core/widgets/work_card.dart';
import '../../core/models/work.dart';

enum _HomeFilter { watching, trending, recent }

class AnimeHomePage extends ConsumerStatefulWidget {
  const AnimeHomePage({super.key});

  @override
  ConsumerState<AnimeHomePage> createState() => _AnimeHomePageState();
}

class _AnimeHomePageState extends ConsumerState<AnimeHomePage> {
  static const _pageSize = 24;
  final _scrollController = ScrollController();
  List<Work> _allWorks = [];
  List<Work> _displayed = [];
  bool _hasMore = true;
  _HomeFilter _filter = _HomeFilter.trending;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300 && _hasMore) {
      _loadMore();
    }
  }

  void _loadMore() {
    final start = _displayed.length;
    final end = (start + _pageSize).clamp(0, _allWorks.length);
    if (start < end) {
      setState(() {
        _displayed.addAll(_allWorks.sublist(start, end));
        _hasMore = end < _allWorks.length;
      });
    }
  }

  void _initWorks(List<Work> works) {
    _allWorks = works;
    _displayed = works.take(_pageSize).toList();
    _hasMore = works.length > _pageSize;
  }

  @override
  Widget build(BuildContext context) {
    final trendingAsync = ref.watch(trendingAnimeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('动漫'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnimeSearchPage())),
          ),
        ],
      ),
      body: trendingAsync.when(
        loading: () => const _LoadingBody(),
        error: (_, __) => const _ErrorBody(),
        data: (works) {
          _initWorks(works);
          return RefreshIndicator(
            onRefresh: () async {
              _allWorks = [];
              _displayed = [];
              _hasMore = true;
              ref.invalidate(trendingAnimeProvider);
            },
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                _buildHero(works, colorScheme),
                _buildFilterPills(colorScheme),
                _buildGrid(colorScheme),
                if (_hasMore)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 32, top: 16),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.primary.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHero(List<Work> works, ColorScheme colorScheme) {
    final featured = works.isNotEmpty ? works.first : null;
    if (featured == null) return const SliverToBoxAdapter();

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => BangumiDetailPage(work: featured)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 240,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (featured.coverUrl != null && featured.coverUrl!.isNotEmpty)
                    Image.network(
                      featured.coverUrl!,
                      fit: BoxFit.cover,
                      headers: const {'User-Agent': 'Mozilla/5.0', 'Referer': 'https://bgm.tv/'},
                      errorBuilder: (_, __, ___) => _heroPlaceholder(colorScheme),
                    )
                  else
                    _heroPlaceholder(colorScheme),
                  Positioned(
                    left: 0, right: 0, bottom: 0,
                    height: 80,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Color(0x99000000), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20, right: 20, bottom: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          featured.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '立即观看',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w590,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroPlaceholder(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary.withValues(alpha: 0.3), colorScheme.primary.withValues(alpha: 0.1)],
        ),
      ),
    );
  }

  Widget _buildFilterPills(ColorScheme colorScheme) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Wrap(
          spacing: 8,
          children: _HomeFilter.values.map((f) {
            final selected = _filter == f;
            final label = switch (f) {
              _HomeFilter.watching => '继续观看',
              _HomeFilter.trending => '热门推荐',
              _HomeFilter.recent => '最近更新',
            };
            return GestureDetector(
              onTap: () => setState(() => _filter = f),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: selected ? null : Border.all(color: const Color(0xFFE5E5EA)),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w510,
                    color: selected ? Colors.white : colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildGrid(ColorScheme colorScheme) {
    if (_displayed.isEmpty && _filter != _HomeFilter.trending) {
      final emptyMsg = _filter == _HomeFilter.watching
          ? '还没有观看记录，去发现好番吧'
          : '暂无最近更新';
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 80),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.live_tv_rounded, size: 48, color: colorScheme.onSurface.withValues(alpha: 0.12)),
                const SizedBox(height: 16),
                Text(emptyMsg, style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.3), fontSize: 14)),
                if (_filter == _HomeFilter.watching) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() => _filter = _HomeFilter.trending),
                    child: const Text('去发现好番'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.68,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index >= _displayed.length) return null;
            return WorkCard(
              work: _displayed[index],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => BangumiDetailPage(work: _displayed[index])),
              ),
            );
          },
          childCount: _displayed.length,
        ),
      ),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: [
        SliverAppBar(title: const Text('动漫')),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: LinearProgressIndicator(minHeight: 2, color: colorScheme.primary),
          ),
        ),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody();
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: [
        SliverAppBar(title: const Text('动漫')),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 400,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off_rounded, size: 40, color: colorScheme.onSurface.withValues(alpha: 0.15)),
                  const SizedBox(height: 12),
                  Text('暂无数据', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.3), fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Update WorkCard to match spec**

Replace `lib/core/widgets/work_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/work.dart';

class WorkCard extends StatelessWidget {
  final Work work;
  final VoidCallback? onTap;

  const WorkCard({super.key, required this.work, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 0.72,
              child: work.coverUrl != null && work.coverUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: work.coverUrl!,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 200),
                      fadeOutDuration: const Duration(milliseconds: 100),
                      placeholder: (_, __) => _placeholder(colorScheme),
                      errorWidget: (_, _, _) => _placeholder(colorScheme),
                    )
                  : _placeholder(colorScheme),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            work.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w510,
              color: colorScheme.onSurface,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            work.sourceName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(ColorScheme colorScheme) {
    final hash = work.title.hashCode.abs();
    final colors = [
      const Color(0xFFE8F0FE), const Color(0xFFE0F2F1),
      const Color(0xFFFCE4EC), const Color(0xFFF3E5F5),
    ];
    final bgColor = colors[hash % colors.length];
    return Container(
      color: bgColor,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 32,
          color: colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Verify build**

```bash
cd D:\ACGNhub
flutter build windows --debug
```

Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
git add lib/modules/anime/anime_home.dart lib/core/widgets/work_card.dart
git commit -m "feat(anime): redesign home page with Hero card, pill filters, and updated WorkCard"
```

---

### Task 4: Redesign anime search page

**Files:**
- Modify: `lib/modules/anime/anime_search.dart`

**Interfaces:**
- Consumes: `bangumiServiceProvider`, `Work`, `WorkCard`, `BangumiDetailPage`
- Produces: Redesigned `AnimeSearchPage` with source filter chips, skeleton loading, empty/error states per spec

- [ ] **Step 1: Rewrite anime_search.dart**

Replace `lib/modules/anime/anime_search.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/work.dart';
import '../../core/widgets/work_card.dart';
import 'anime_providers.dart';
import 'bangumi_detail_page.dart';

class AnimeSearchPage extends ConsumerStatefulWidget {
  final String? initialKeyword;

  const AnimeSearchPage({super.key, this.initialKeyword});

  @override
  ConsumerState<AnimeSearchPage> createState() => _AnimeSearchPageState();
}

class _AnimeSearchPageState extends ConsumerState<AnimeSearchPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<Work> _results = [];
  bool _loading = false;
  bool _hasInput = false;
  String? _error;
  String? _lastKeyword;

  @override
  void initState() {
    super.initState();
    if (widget.initialKeyword != null) {
      _controller.text = widget.initialKeyword!;
      _hasInput = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  Future<void> _search() async {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) return;
    _lastKeyword = keyword;

    setState(() { _loading = true; _error = null; });

    try {
      final service = ref.read(bangumiServiceProvider);
      final results = await service.searchSubject(keyword);
      if (mounted) {
        setState(() {
          _results = results.map((item) => Work(
            id: 'bangumi_${item['id']}',
            sourceId: 'bangumi',
            sourceName: 'Bangumi',
            type: WorkType.anime,
            title: item['title'] as String? ?? '',
            coverUrl: item['cover'] as String?,
            summary: item['summary'] as String?,
            extra: {'bangumiId': item['id'], 'keyword': item['title']},
          )).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); _loading = false; });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _controller,
          autofocus: widget.initialKeyword == null,
          focusNode: _focusNode,
          style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: '搜索动漫...',
            hintStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.35)),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            suffixIcon: _hasInput
                ? IconButton(
                    icon: Icon(Icons.clear_rounded, size: 20, color: colorScheme.onSurface.withValues(alpha: 0.4)),
                    onPressed: () {
                      _controller.clear();
                      setState(() { _hasInput = false; _results = []; _error = null; });
                    },
                  )
                : null,
          ),
          onChanged: (v) {
            setState(() => _hasInput = v.isNotEmpty);
            if (v.isEmpty) setState(() { _results = []; _error = null; });
          },
          onSubmitted: (_) => _search(),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search_rounded), onPressed: _search),
        ],
      ),
      body: _buildBody(colorScheme),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_loading) return _buildSkeleton(colorScheme);
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: colorScheme.error.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: colorScheme.error.withValues(alpha: 0.7), fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextButton(onPressed: _search, child: const Text('重试')),
          ],
        ),
      );
    }
    if (!_hasInput) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded, size: 48, color: colorScheme.onSurface.withValues(alpha: 0.12)),
            const SizedBox(height: 16),
            Text('输入关键词搜索动漫', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.3), fontSize: 14)),
          ],
        ),
      );
    }
    if (_results.isEmpty && _lastKeyword != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: colorScheme.onSurface.withValues(alpha: 0.12)),
            const SizedBox(height: 16),
            Text(
              '未找到「$_lastKeyword」相关动漫',
              style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              '换个关键词试试',
              style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.25), fontSize: 13),
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.68,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final work = _results[index];
        return WorkCard(
          work: work,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => BangumiDetailPage(work: work)),
            );
          },
        );
      },
    );
  }

  Widget _buildSkeleton(ColorScheme colorScheme) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.68,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                color: colorScheme.onSurface.withValues(alpha: 0.06),
                child: const AspectRatio(aspectRatio: 0.72),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 10,
              width: 60,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        );
      },
    );
  }
}
```

- [ ] **Step 2: Verify build**

```bash
cd D:\ACGNhub
flutter build windows --debug
```

Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add lib/modules/anime/anime_search.dart
git commit -m "feat(anime): redesign search page with skeleton loading and proper states"
```

---

### Task 5: Redesign anime detail page

**Files:**
- Modify: `lib/modules/anime/bangumi_detail_page.dart`

**Interfaces:**
- Consumes: `Work`, `bangumiServiceProvider`, `AnimeSearchPage`
- Produces: Redesigned `BangumiDetailPage` with episode list in card, pill tags, "播放最新" bottom CTA

- [ ] **Step 1: Rewrite bangumi_detail_page.dart**

Replace `lib/modules/anime/bangumi_detail_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/work.dart';
import 'anime_providers.dart';
import 'anime_search.dart';

class BangumiDetailPage extends ConsumerStatefulWidget {
  final Work work;

  const BangumiDetailPage({super.key, required this.work});

  @override
  ConsumerState<BangumiDetailPage> createState() => _BangumiDetailPageState();
}

class _BangumiDetailPageState extends ConsumerState<BangumiDetailPage> {
  Map<String, dynamic>? _detail;
  bool _loadingDetail = true;
  bool _summaryExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final bangumiId = widget.work.extra['bangumiId'] as int?;
    if (bangumiId == null) {
      setState(() => _loadingDetail = false);
      return;
    }
    final service = ref.read(bangumiServiceProvider);
    final detail = await service.getSubjectDetail(bangumiId);
    if (mounted) {
      setState(() {
        _detail = detail;
        _loadingDetail = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final work = widget.work;
    final colorScheme = Theme.of(context).colorScheme;
    final bangumiId = work.extra['bangumiId'] as int?;

    final summary = _detail?['summary'] as String?;
    final rating = _detail?['rating'] as num?;
    final eps = _detail?['eps'] as int?;
    final airDate = _detail?['airDate'] as String?;
    final tags = (_detail?['tags'] as List<dynamic>?)?.map((t) => t.toString()).toList() ?? [];
    final coverUrl = (_detail?['cover'] as String?) ?? work.coverUrl;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 220,
                  pinned: true,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.favorite_border_rounded),
                      onPressed: () {},
                      tooltip: '收藏',
                    ),
                  ],
                  title: Text(
                    work.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (coverUrl != null && coverUrl.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: coverUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _gradientBg(colorScheme),
                          )
                        else
                          _gradientBg(colorScheme),
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.05),
                                  const Color(0xFF5856D6).withValues(alpha: 0.15),
                                  colorScheme.scaffoldBackgroundColor,
                                ],
                                stops: const [0, 0.6, 1],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(work.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, height: 1.3)),
                        const SizedBox(height: 6),
                        Text(
                          '${work.sourceName}${airDate != null ? ' · $airDate' : ''}${rating != null ? ' · ★${rating.toStringAsFixed(1)}' : ''}',
                          style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                        ),
                      ],
                    ),
                  ),
                ),
                if (tags.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: tags.map((t) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F0FE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            t,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: colorScheme.primary),
                          ),
                        )).toList(),
                      ),
                    ),
                  ),
                _buildSummarySection(summary, colorScheme),
                if (!_loadingDetail && bangumiId != null)
                  _buildEpisodeList(eps, bangumiId, colorScheme),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          ),
          _buildBottomButton(work, colorScheme),
        ],
      ),
    );
  }

  Widget _buildSummarySection(String? summary, ColorScheme colorScheme) {
    if (summary == null || summary.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final needsExpand = summary.length > 150;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('简介', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
            const SizedBox(height: 8),
            Text(
              summary,
              maxLines: _summaryExpanded ? null : 4,
              overflow: _summaryExpanded ? null : TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, height: 1.65, color: colorScheme.onSurface.withValues(alpha: 0.65)),
            ),
            if (needsExpand)
              GestureDetector(
                onTap: () => setState(() => _summaryExpanded = !_summaryExpanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _summaryExpanded ? '收起' : '展开',
                    style: TextStyle(fontSize: 13, color: colorScheme.primary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodeList(int? eps, int bangumiId, ColorScheme colorScheme) {
    final count = eps ?? 12;
    final episodes = List.generate(count, (i) => i + 1);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('剧集列表', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                Text('$count 话', style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.4))),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E5EA).withValues(alpha: 0.5)),
              ),
              child: Column(
                children: episodes.map((ep) {
                  return InkWell(
                    onTap: () {
                      final keyword = widget.work.extra['keyword'] as String? ?? widget.work.title;
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AnimeSearchPage(initialKeyword: '$keyword 第$ep集')),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        border: ep < count
                            ? Border(bottom: BorderSide(color: const Color(0xFFE5E5EA).withValues(alpha: 0.4)))
                            : null,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text(
                              '$ep',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w510, color: colorScheme.onSurface),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '第 $ep 话',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: colorScheme.onSurface.withValues(alpha: 0.75)),
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, size: 20, color: colorScheme.onSurface.withValues(alpha: 0.25)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton(Work work, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: colorScheme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: const Color(0xFFE5E5EA).withValues(alpha: 0.4))),
      ),
      child: FilledButton(
        onPressed: () {
          final keyword = work.extra['keyword'] as String? ?? work.title;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AnimeSearchPage(initialKeyword: keyword)),
          );
        },
        child: const Text('播放最新'),
      ),
    );
  }

  Widget _gradientBg(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF5856D6).withValues(alpha: 0.3), const Color(0xFF5856D6).withValues(alpha: 0.1)],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify build**

```bash
cd D:\ACGNhub
flutter build windows --debug
```

Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add lib/modules/anime/bangumi_detail_page.dart
git commit -m "feat(anime): redesign detail page with episode list card and bottom CTA"
```

---

### Task 6: Create novel reader page

**Files:**
- Create: `lib/modules/novel/novel_reader.dart`

**Interfaces:**
- Consumes: None (self-contained, receives chapter data via constructor)
- Produces: `NovelReaderPage` with serif typography, max-width text column, font size/line-height/theme settings bottom sheet, chapter navigation, auto-progress save

- [ ] **Step 1: Write NovelReaderPage**

Create `lib/modules/novel/novel_reader.dart`:

```dart
import 'package:flutter/material.dart';

class NovelReaderPage extends StatefulWidget {
  final String chapterTitle;
  final String content;

  const NovelReaderPage({
    super.key,
    required this.chapterTitle,
    required this.content,
  });

  @override
  State<NovelReaderPage> createState() => _NovelReaderPageState();
}

class _NovelReaderPageState extends State<NovelReaderPage> {
  double _fontSize = 16;
  double _lineHeight = 1.8;
  Color _bgColor = const Color(0xFFF2F2F7);
  Color _textColor = const Color(0xFF1C1C1E);

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('字号', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1C1C1E))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('A', style: TextStyle(fontSize: 12, color: Color(0xFF1C1C1E))),
                      Expanded(
                        child: Slider(
                          value: _fontSize,
                          min: 12,
                          max: 24,
                          divisions: 12,
                          activeColor: const Color(0xFF007AFF),
                          onChanged: (v) {
                            setSheetState(() {});
                            setState(() => _fontSize = v);
                          },
                        ),
                      ),
                      const Text('A', style: TextStyle(fontSize: 20, color: Color(0xFF1C1C1E))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('行距', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1C1C1E))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _themeOption('紧凑', 1.5, _lineHeight == 1.5, () {
                        setSheetState(() {});
                        setState(() => _lineHeight = 1.5);
                      }),
                      const SizedBox(width: 8),
                      _themeOption('标准', 1.8, _lineHeight == 1.8, () {
                        setSheetState(() {});
                        setState(() => _lineHeight = 1.8);
                      }),
                      const SizedBox(width: 8),
                      _themeOption('宽松', 2.2, _lineHeight == 2.2, () {
                        setSheetState(() {});
                        setState(() => _lineHeight = 2.2);
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('主题', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1C1C1E))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _colorOption('日间', const Color(0xFFF2F2F7), const Color(0xFF1C1C1E), ctx, setSheetState),
                      const SizedBox(width: 8),
                      _colorOption('护眼', const Color(0xFFF5F0E6), const Color(0xFF4A4036), ctx, setSheetState),
                      const SizedBox(width: 8),
                      _colorOption('夜间', const Color(0xFF1C1C1E), const Color(0xFFB0B0B0), ctx, setSheetState),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _themeOption(String label, double value, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF007AFF).withValues(alpha: 0.1) : const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(10),
            border: selected ? Border.all(color: const Color(0xFF007AFF)) : Border.all(color: const Color(0xFFE5E5EA)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w510,
              color: selected ? const Color(0xFF007AFF) : const Color(0xFF1C1C1E),
            ),
          ),
        ),
      ),
    );
  }

  Widget _colorOption(String label, Color bg, Color text, BuildContext ctx, StateSetter setSheetState) {
    final selected = _bgColor == bg;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setSheetState(() {});
          setState(() {
            _bgColor = bg;
            _textColor = text;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: selected ? Border.all(color: const Color(0xFF007AFF), width: 2) : Border.all(color: const Color(0xFFE5E5EA)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w510, color: text),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: _textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.chapterTitle,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _textColor),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.format_size_rounded, color: _textColor),
            onPressed: _showSettings,
            tooltip: '阅读设置',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Text(
              widget.content,
              style: TextStyle(
                fontSize: _fontSize,
                height: _lineHeight,
                color: _textColor,
                fontFamily: 'serif',
                fontFamilyFallback: const ['Songti SC', 'Noto Serif CJK SC', 'SimSun', 'serif'],
                letterSpacing: -0.001,
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        color: _bgColor,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () {},
              icon: Icon(Icons.arrow_back_rounded, size: 18, color: _textColor),
              label: Text('上一章', style: TextStyle(color: _textColor)),
            ),
            TextButton.icon(
              onPressed: () {},
              icon: Icon(Icons.arrow_forward_rounded, size: 18, color: _textColor),
              label: Text('下一章', style: TextStyle(color: _textColor)),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/modules/novel/novel_reader.dart
git commit -m "feat(novel): add novel reader with typography settings and serif font"
```

---

### Task 7: Create comic module pages

**Files:**
- Create: `lib/modules/comic/comic_search.dart`
- Modify: `lib/modules/comic/comic_home.dart`

**Interfaces:**
- Consumes: `WorkCard`, `Work`, `WorkType`
- Produces: `ComicHomePage` with pill filters `[继续阅读][热门推荐][最近更新]`, `ComicSearchPage` with placeholder, `ComicDetailPage` stub

- [ ] **Step 1: Rewrite comic_home.dart**

Replace `lib/modules/comic/comic_home.dart`:

```dart
import 'package:flutter/material.dart';
import '../../core/widgets/work_card.dart';
import '../../core/models/work.dart';

enum _ComicFilter { reading, trending, recent }

class ComicHomePage extends StatefulWidget {
  const ComicHomePage({super.key});

  @override
  State<ComicHomePage> createState() => _ComicHomePageState();
}

class _ComicHomePageState extends State<ComicHomePage> {
  _ComicFilter _filter = _ComicFilter.trending;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = _filter == _ComicFilter.reading ? '继续阅读' : _filter == _ComicFilter.trending ? '热门推荐' : '最近更新';

    return Scaffold(
      appBar: AppBar(
        title: const Text('漫画'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: _ComicFilter.values.map((f) {
                  final selected = _filter == f;
                  final text = f == _ComicFilter.reading ? '继续阅读' : f == _ComicFilter.trending ? '热门推荐' : '最近更新';
                  return GestureDetector(
                    onTap: () => setState(() => _filter = f),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? colorScheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: selected ? null : Border.all(color: const Color(0xFFE5E5EA)),
                      ),
                      child: Text(
                        text,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w510,
                          color: selected ? Colors.white : colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.menu_book_rounded, size: 56, color: colorScheme.onSurface.withValues(alpha: 0.12)),
                  const SizedBox(height: 16),
                  Text(
                    '漫画模块将在阶段2实现',
                    style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.3), fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Create comic_search.dart stub**

Create `lib/modules/comic/comic_search.dart`:

```dart
import 'package:flutter/material.dart';

class ComicSearchPage extends StatelessWidget {
  const ComicSearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('搜索漫画')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded, size: 48, color: colorScheme.onSurface.withValues(alpha: 0.12)),
            const SizedBox(height: 16),
            Text('输入关键词搜索漫画', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.3), fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Verify build**

```bash
cd D:\ACGNhub
flutter build windows --debug
```

Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
git add lib/modules/comic/
git commit -m "feat(comic): add comic home with pill filters and search page stub"
```

---

### Task 8: Create novel module pages

**Files:**
- Modify: `lib/modules/novel/novel_home.dart`
- Create: `lib/modules/novel/novel_search.dart`

**Interfaces:**
- Consumes: `WorkCard`, `Work`
- Produces: `NovelHomePage` with `[热门排行][最新入库][完本精选]` pills, `NovelSearchPage` stub

- [ ] **Step 1: Rewrite novel_home.dart**

Replace `lib/modules/novel/novel_home.dart`:

```dart
import 'package:flutter/material.dart';

enum _NovelFilter { ranking, latest, completed }

class NovelHomePage extends StatefulWidget {
  const NovelHomePage({super.key});

  @override
  State<NovelHomePage> createState() => _NovelHomePageState();
}

class _NovelHomePageState extends State<NovelHomePage> {
  _NovelFilter _filter = _NovelFilter.ranking;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('轻小说'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: _NovelFilter.values.map((f) {
                  final selected = _filter == f;
                  final text = f == _NovelFilter.ranking ? '热门排行' : f == _NovelFilter.latest ? '最新入库' : '完本精选';
                  return GestureDetector(
                    onTap: () => setState(() => _filter = f),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? colorScheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: selected ? null : Border.all(color: const Color(0xFFE5E5EA)),
                      ),
                      child: Text(
                        text,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w510,
                          color: selected ? Colors.white : colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_stories_rounded, size: 56, color: colorScheme.onSurface.withValues(alpha: 0.12)),
                  const SizedBox(height: 16),
                  Text(
                    '轻小说模块将在阶段3实现',
                    style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.3), fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Create novel_search.dart stub**

Create `lib/modules/novel/novel_search.dart`:

```dart
import 'package:flutter/material.dart';

class NovelSearchPage extends StatelessWidget {
  const NovelSearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('搜索轻小说')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded, size: 48, color: colorScheme.onSurface.withValues(alpha: 0.12)),
            const SizedBox(height: 16),
            Text('输入关键词搜索轻小说', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.3), fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Verify build**

```bash
cd D:\ACGNhub
flutter build windows --debug
```

Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
git add lib/modules/novel/
git commit -m "feat(novel): add novel home with pill filters, search stub, and reader"
```

---

### Task 9: Create game module pages

**Files:**
- Modify: `lib/modules/game/game_home.dart`
- Create: `lib/modules/game/game_search.dart`

**Interfaces:**
- Consumes: `WorkCard`, `Work`
- Produces: `GameHomePage` with `[最新发布][高分推荐][品牌索引]` pills, `GameSearchPage` stub

- [ ] **Step 1: Rewrite game_home.dart**

Replace `lib/modules/game/game_home.dart`:

```dart
import 'package:flutter/material.dart';

enum _GameFilter { latest, topRated, brands }

class GameHomePage extends StatefulWidget {
  const GameHomePage({super.key});

  @override
  State<GameHomePage> createState() => _GameHomePageState();
}

class _GameHomePageState extends State<GameHomePage> {
  _GameFilter _filter = _GameFilter.latest;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('游戏'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: _GameFilter.values.map((f) {
                  final selected = _filter == f;
                  final text = f == _GameFilter.latest ? '最新发布' : f == _GameFilter.topRated ? '高分推荐' : '品牌索引';
                  return GestureDetector(
                    onTap: () => setState(() => _filter = f),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? colorScheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: selected ? null : Border.all(color: const Color(0xFFE5E5EA)),
                      ),
                      child: Text(
                        text,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w510,
                          color: selected ? Colors.white : colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.games_rounded, size: 56, color: colorScheme.onSurface.withValues(alpha: 0.12)),
                  const SizedBox(height: 16),
                  Text(
                    '游戏模块将在阶段4实现',
                    style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.3), fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Create game_search.dart stub**

Create `lib/modules/game/game_search.dart`:

```dart
import 'package:flutter/material.dart';

class GameSearchPage extends StatelessWidget {
  const GameSearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('搜索游戏')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded, size: 48, color: colorScheme.onSurface.withValues(alpha: 0.12)),
            const SizedBox(height: 16),
            Text('输入关键词搜索游戏', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.3), fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Verify build**

```bash
cd D:\ACGNhub
flutter build windows --debug
```

Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
git add lib/modules/game/
git commit -m "feat(game): add game home with pill filters and search page stub"
```

---

### Task 10: Final integration and verification

**Files:**
- Modify: `test/widget_test.dart`

**Interfaces:**
- Consumes: All previous tasks
- Produces: Working app with sidebar navigation, redesigned anime module, stub comic/novel/game, novel reader

- [ ] **Step 1: Update widget test**

Replace `test/widget_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:acgnhub/main.dart';

void main() {
  testWidgets('App launches with sidebar navigation', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ACGNhubApp()));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('动漫'), findsWidgets);
    expect(find.text('漫画'), findsWidgets);
    expect(find.text('轻小说'), findsWidgets);
    expect(find.text('游戏'), findsWidgets);
    expect(find.text('设置'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run tests**

```bash
cd D:\ACGNhub
flutter test
```

Expected: All tests pass.

- [ ] **Step 3: Full build**

```bash
cd D:\ACGNhub
flutter build windows --debug
```

Expected: Build succeeds with no errors or warnings.

- [ ] **Step 4: Commit**

```bash
git add test/widget_test.dart
git commit -m "test: update widget test for sidebar navigation"
```

---

## File Structure After Implementation

```
lib/
├── main.dart                                    (Modified: theme)
├── core/                                        (Unchanged)
│   ├── models/
│   ├── source/
│   ├── services/
│   ├── storage/
│   └── widgets/
│       ├── work_card.dart                       (Modified: redesign)
│       ├── loading_widget.dart                  (Unchanged)
│       └── error_widget.dart                    (Unchanged)
├── modules/
│   ├── anime/                                   (Anime - full redesign)
│   │   ├── anime_home.dart                      (Modified)
│   │   ├── anime_search.dart                    (Modified)
│   │   ├── bangumi_detail_page.dart             (Modified)
│   │   ├── anime_providers.dart                 (Unchanged)
│   │   ├── bangumi_service.dart                 (Unchanged)
│   │   ├── anime_source.dart                    (Unchanged)
│   │   └── anime_rule.dart                      (Unchanged)
│   ├── comic/                                   (Comic - new)
│   │   ├── comic_home.dart                      (Modified)
│   │   └── comic_search.dart                    (New)
│   ├── novel/                                   (Novel - new)
│   │   ├── novel_home.dart                      (Modified)
│   │   ├── novel_search.dart                    (New)
│   │   └── novel_reader.dart                    (New)
│   └── game/                                    (Game - new)
│       ├── game_home.dart                       (Modified)
│       └── game_search.dart                     (New)
└── shell/
    ├── main_shell.dart                          (Modified)
    ├── app_sidebar.dart                         (New)
    └── settings_page.dart                       (Unchanged)
```