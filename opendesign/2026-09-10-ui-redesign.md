# ACGNhub UI Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign ACGNhub from purple-themed bottom-nav Material 3 app to clean Infuse-style left-sidebar design across all four module pages.

**Architecture:** Modify existing Flutter app — replace theme tokens, swap BottomNavigationBar for collapsible left sidebar, redesign anime home/search/detail, create styled placeholders for comic/novel/game, add novel reader.

**Tech Stack:** Flutter 3.x, Dart 3.x, Riverpod, cached_network_image, shared_preferences, Material 3

## Global Constraints

- Target platform: Windows first (Android later)
- No danmaku functionality
- Development on `dev` branch
- Commit messages follow `feat(module): description`
- All colors use const Color() matching spec: bg=#F2F2F7, surface=#FFF, accent=#007AFF, fg=#1C1C1E, muted=#8E8E93, border=#E5E5EA
- Only one primary CTA per page
- Light theme only
- Sidebar collapsible with state persisted via SharedPreferences
- All CJK text: line-height ≥ 1.3, no negative letter-spacing
- Typography: title 20-28px/590-600, body 14px/400, caption 12px/400

---

### Task 1: Update theme system

**Files:**
- Modify: `lib/main.dart`

**Interfaces:**
- Produces: Updated ACGNhubApp with iOS-light color tokens, proper button themes

- [ ] **Step 1: Replace theme in lib/main.dart**

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
          surface: const Color(0xFFFFFFFF),
        ),
        scaffoldBackgroundColor: const Color(0xFFF2F2F7),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          backgroundColor: Color(0xFFFFFFFF),
          foregroundColor: Color(0xFF1C1C1E),
          titleTextStyle: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w590,
            color: Color(0xFF1C1C1E), height: 1.4,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0, color: const Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _accent, foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w590),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _accent,
            side: const BorderSide(color: _accent, width: 1.5),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w590),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: _accent),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFE8F0FE),
          labelStyle: const TextStyle(fontSize: 11, color: _accent, fontWeight: FontWeight.w510),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: EdgeInsets.zero,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: _accent, linearTrackColor: Color(0xFFE5E5EA),
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFFE5E5EA), thickness: 0.5),
      ),
      home: const MainShell(),
    );
  }
}
```

- [ ] **Step 2: Verify build**

```bash
cd D:\ACGNhub; flutter build windows --debug
```

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart; git commit -m "feat(theme): replace purple theme with iOS-light design tokens"
```

---

### Task 2: Create sidebar navigation widget

**Files:**
- Create: `lib/shell/app_sidebar.dart`

**Interfaces:**
- Produces: `SidebarState` (ChangeNotifier + persistence), `AppSidebar` (4 module items + settings + collapse toggle), `CollapsedSidebarIndicator` (12px strip with expand arrow)

- [ ] **Step 1: Write lib/shell/app_sidebar.dart**

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SidebarState extends ChangeNotifier {
  bool _collapsed = false;
  static const _key = 'sidebar_collapsed';

  bool get collapsed => _collapsed;

  SidebarState() { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _collapsed = prefs.getBool(_key) ?? false;
    notifyListeners();
  }

  Future<void> toggle() async {
    _collapsed = !_collapsed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _collapsed);
    notifyListeners();
  }
}

class AppSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final VoidCallback onToggle;
  final VoidCallback onSettingsTap;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
    required this.onToggle,
    required this.onSettingsTap,
  });

  static const _items = [
    (Icons.live_tv_rounded, '动漫'),
    (Icons.menu_book_rounded, '漫画'),
    (Icons.auto_stories_rounded, '轻小说'),
    (Icons.games_rounded, '游戏'),
  ];

  static const _accent = Color(0xFF007AFF);
  static const _sidebarBg = Color(0xFFF9F9FC);
  static const _border = Color(0xFFE5E5EA);
  static const _fg = Color(0xFF1C1C1E);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      color: _sidebarBg,
      child: Column(
        children: [
          const SizedBox(height: 8),
          SizedBox(
            width: 44, height: 44,
            child: IconButton(
              icon: Icon(Icons.menu_rounded, size: 20, color: _fg.withValues(alpha: 0.4)),
              onPressed: onToggle, splashRadius: 20,
              tooltip: '收起侧边栏',
            ),
          ),
          const Spacer(),
          ...List.generate(_items.length, (i) => _SidebarItem(
            icon: _items[i].$1, label: _items[i].$2,
            selected: selectedIndex == i, onTap: () => onChanged(i),
          )),
          const Spacer(flex: 2),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: _border),
          ),
          const SizedBox(height: 4),
          _SidebarItem(icon: Icons.settings_rounded, label: '设置', selected: false, onTap: onSettingsTap),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({required this.icon, required this.label, required this.selected, required this.onTap});

  static const _accent = Color(0xFF007AFF);
  static const _fg = Color(0xFF1C1C1E);

  @override
  Widget build(BuildContext context) {
    final iconColor = selected ? _accent : _fg.withValues(alpha: 0.35);
    final textColor = selected ? _accent : _fg.withValues(alpha: 0.45);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: selected ? const Border(left: BorderSide(color: _accent, width: 3)) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: iconColor),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11, height: 1.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: textColor,
                letterSpacing: 0.02,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CollapsedSidebarIndicator extends StatelessWidget {
  final VoidCallback onTap;
  const CollapsedSidebarIndicator({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 12,
        color: const Color(0xFFF9F9FC),
        child: const Center(
          child: Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF007AFF)),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

```bash
cd D:\ACGNhub; dart analyze lib/shell/app_sidebar.dart
```

- [ ] **Step 3: Commit**

```bash
git add lib/shell/app_sidebar.dart; git commit -m "feat(shell): create collapsible left sidebar widget"
```

---

### Task 3: Update MainShell with sidebar layout

**Files:**
- Modify: `lib/shell/main_shell.dart`

**Interfaces:**
- Consumes: `AppSidebar`, `CollapsedSidebarIndicator`, `SidebarState` (Task 2)
- Produces: Updated `MainShell` with AnimatedSwitcher sidebar + IndexedStack pages

- [ ] **Step 1: Replace lib/shell/main_shell.dart**

```dart
import 'package:flutter/material.dart';
import '../modules/anime/anime_home.dart';
import 'settings_page.dart';
import 'app_sidebar.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  late final SidebarState _sidebarState;

  final _pages = <Widget>[
    const AnimeHomePage(),
    _buildPlaceholder('漫画', Icons.menu_book_rounded, '漫画模块将在阶段2实现'),
    _buildPlaceholder('轻小说', Icons.auto_stories_rounded, '轻小说模块将在阶段3实现'),
    _buildPlaceholder('游戏', Icons.games_rounded, '游戏模块将在阶段4实现'),
  ];

  static Widget _buildPlaceholder(String title, IconData icon, String message) {
    return Builder(builder: (context) {
      final cs = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: cs.onSurface.withValues(alpha: 0.12)),
            const SizedBox(height: 20),
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w590, color: cs.onSurface)),
            const SizedBox(height: 8),
            Text(message, style: TextStyle(fontSize: 14, color: cs.onSurface.withValues(alpha: 0.35))),
          ],
        ),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _sidebarState = SidebarState();
    _sidebarState.addListener(_onSidebarChanged);
  }

  void _onSidebarChanged() => setState(() {});

  @override
  void dispose() {
    _sidebarState.removeListener(_onSidebarChanged);
    _sidebarState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final collapsed = _sidebarState.collapsed;

    return Scaffold(
      body: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: collapsed
                ? CollapsedSidebarIndicator(
                    key: const ValueKey('collapsed'),
                    onTap: () => _sidebarState.toggle(),
                  )
                : AppSidebar(
                    key: const ValueKey('expanded'),
                    selectedIndex: _currentIndex,
                    onChanged: (i) => setState(() => _currentIndex = i),
                    onToggle: () => _sidebarState.toggle(),
                    onSettingsTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    ),
                  ),
          ),
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _pages),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify build**

```bash
cd D:\ACGNhub; flutter build windows --debug
```

- [ ] **Step 3: Commit**

```bash
git add lib/shell/main_shell.dart; git commit -m "feat(shell): replace bottom nav with collapsible sidebar layout"
```

---

### Task 4: Redesign WorkCard and create common widgets

**Files:**
- Modify: `lib/core/widgets/work_card.dart`
- Create: `lib/core/widgets/shimmer_loader.dart`
- Create: `lib/core/widgets/empty_state.dart`

**Interfaces:**
- Produces: `WorkCard` (updated), `ShimmerLoader` (animated skeleton grid), `EmptyState` (icon + message + optional action)

- [ ] **Step 1: Replace lib/core/widgets/work_card.dart**

```dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/work.dart';

class WorkCard extends StatelessWidget {
  final Work work;
  final VoidCallback? onTap;
  final String? subtitle;

  const WorkCard({super.key, required this.work, this.onTap, this.subtitle});

  static const _accent = Color(0xFF007AFF);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sub = subtitle ?? work.sourceName;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 0.75,
              child: work.coverUrl != null && work.coverUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: work.coverUrl!,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 200),
                      placeholder: (_, __) => _placeholder(work),
                      errorWidget: (_, __, ___) => _placeholder(work),
                    )
                  : _placeholder(work),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            work.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w510, height: 1.45,
              color: cs.onSurface,
            ),
          ),
          if (sub.isNotEmpty)
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12, height: 1.5,
                color: cs.onSurface.withValues(alpha: 0.45),
              ),
            ),
        ],
      ),
    );
  }

  Widget _placeholder(Work work) {
    final hash = work.title.hashCode.abs();
    final bgColors = const [
      Color(0xFFF3E5F5), Color(0xFFEDE7F6),
      Color(0xFFE8EAF6), Color(0xFFE0F2F1),
    ];
    return Container(
      color: bgColors[hash % bgColors.length],
      child: Center(
        child: Text(
          work.title.characters.first,
          style: TextStyle(color: _accent.withValues(alpha: 0.2), fontSize: 28, fontWeight: FontWeight.w200),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Create lib/core/widgets/shimmer_loader.dart**

```dart
import 'package:flutter/material.dart';

class ShimmerLoader extends StatefulWidget {
  final int itemCount;
  final int crossAxisCount;
  final double aspectRatio;
  final EdgeInsets padding;

  const ShimmerLoader({
    super.key,
    this.itemCount = 12,
    this.crossAxisCount = 5,
    this.aspectRatio = 0.66,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  State<ShimmerLoader> createState() => _ShimmerLoaderState();
}

class _ShimmerLoaderState extends State<ShimmerLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final o = 0.3 + 0.3 * (_ctrl.value < 0.5 ? _ctrl.value * 2 : (1 - _ctrl.value) * 2);
        return GridView.builder(
          padding: widget.padding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: widget.crossAxisCount,
            mainAxisSpacing: 12, crossAxisSpacing: 12,
            childAspectRatio: widget.aspectRatio,
          ),
          itemCount: widget.itemCount,
          itemBuilder: (context, index) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(color: const Color(0xFFE5E5EA).withValues(alpha: o)),
              ),
              const SizedBox(height: 6),
              Container(height: 12, width: double.infinity, decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: const Color(0xFFE5E5EA).withValues(alpha: o))),
              const SizedBox(height: 4),
              Container(height: 10, width: 60, decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: const Color(0xFFE5E5EA).withValues(alpha: o * 0.6))),
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 3: Create lib/core/widgets/empty_state.dart**

```dart
import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({super.key, required this.icon, required this.message, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: cs.onSurface.withValues(alpha: 0.15)),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(fontSize: 14, color: cs.onSurface.withValues(alpha: 0.45))),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Verify and commit**

```bash
cd D:\ACGNhub; flutter analyze lib/core/widgets/
git add lib/core/widgets/
git commit -m "feat(core): redesign WorkCard, add ShimmerLoader and EmptyState"
```

---

### Task 5: Redesign anime home page

**Files:**
- Modify: `lib/modules/anime/anime_home.dart`

**Interfaces:**
- Consumes: `WorkCard` (Task 4), `ShimmerLoader` (Task 4), `EmptyState` (Task 4), `trendingAnimeProvider`, `BangumiDetailPage`, `AnimeSearchPage`
- Produces: Redesigned `AnimeHomePage` with Column header + Hero card + pill filters + scrollable grid

- [ ] **Step 1: Replace lib/modules/anime/anime_home.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'anime_providers.dart';
import 'anime_search.dart';
import 'bangumi_detail_page.dart';
import '../../core/widgets/work_card.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/models/work.dart';

enum _Filter { watching, trending, recent }

class AnimeHomePage extends ConsumerStatefulWidget {
  const AnimeHomePage({super.key});

  @override
  ConsumerState<AnimeHomePage> createState() => _AnimeHomePageState();
}

class _AnimeHomePageState extends ConsumerState<AnimeHomePage> {
  _Filter _filter = _Filter.trending;
  List<Work> _allWorks = [];
  static const _accent = Color(0xFF007AFF);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(trendingAnimeProvider);
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        _header(cs),
        Expanded(
          child: async.when(
            loading: () => const ShimmerLoader(),
            error: (_, __) => EmptyState(icon: Icons.cloud_off_rounded, message: '加载失败', actionLabel: '重试', onAction: () => ref.invalidate(trendingAnimeProvider)),
            data: (works) {
              if (_allWorks.isEmpty && works.isNotEmpty) _allWorks = works;
              final displayed = _filtered;
              final feat = works.isNotEmpty ? works[0] : null;

              return RefreshIndicator(
                onRefresh: () async { _allWorks = []; ref.invalidate(trendingAnimeProvider); },
                child: CustomScrollView(
                  slivers: [
                    if (feat != null) _hero(feat),
                    _pills(),
                    _sectionTitle(_filterLabel, cs),
                    displayed.isEmpty
                        ? SliverToBoxAdapter(child: SizedBox(height: 300, child: EmptyState(icon: Icons.live_tv_rounded, message: _emptyMsg)))
                        : SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            sliver: SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 0.66),
                              delegate: SliverChildBuilderDelegate(
                                (_, i) => i >= displayed.length ? null : WorkCard(work: displayed[i], onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BangumiDetailPage(work: displayed[i])))),
                                childCount: displayed.length,
                              ),
                            ),
                          ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<Work> get _filtered {
    switch (_filter) {
      case _Filter.watching: return _allWorks.take(10).toList();
      case _Filter.trending: return _allWorks;
      case _Filter.recent: return _allWorks.reversed.toList();
    }
  }

  String get _filterLabel {
    switch (_filter) {
      case _Filter.watching: return '继续观看';
      case _Filter.trending: return '热门推荐';
      case _Filter.recent: return '最近更新';
    }
  }

  String get _emptyMsg {
    switch (_filter) {
      case _Filter.watching: return '还没有观看记录，去发现好番吧';
      case _Filter.trending: return '暂无推荐内容';
      case _Filter.recent: return '暂无更新内容';
    }
  }

  Widget _header(ColorScheme cs) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
      ),
      child: Row(
        children: [
          Text('动漫', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w590, color: cs.onSurface, height: 1.4)),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.search_rounded, color: cs.onSurface.withValues(alpha: 0.5)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnimeSearchPage())),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _hero(Work work) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BangumiDetailPage(work: work))),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 240,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (work.coverUrl != null && work.coverUrl!.isNotEmpty)
                    CachedNetworkImage(imageUrl: work.coverUrl!, fit: BoxFit.cover, fadeInDuration: const Duration(milliseconds: 300), errorWidget: (_, __, ___) => Container(color: const Color(0xFF1C1C1E)))
                  else
                    Container(color: const Color(0xFF1C1C1E)),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                          stops: const [0.5, 1],
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
                        Text(work.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Text(work.sourceName, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7))),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 36,
                          child: FilledButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BangumiDetailPage(work: work))),
                            style: FilledButton.styleFrom(minimumSize: const Size(120, 36), backgroundColor: _accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            child: const Text('立即观看', style: TextStyle(fontSize: 14)),
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

  Widget _pills() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(children: [_pill('继续观看', _Filter.watching), const SizedBox(width: 8), _pill('热门推荐', _Filter.trending), const SizedBox(width: 8), _pill('最近更新', _Filter.recent)]),
      ),
    );
  }

  Widget _pill(String label, _Filter f) {
    final sel = _filter == f;
    return GestureDetector(
      onTap: () => setState(() => _filter = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? _accent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: sel ? null : Border.all(color: const Color(0xFFE5E5EA)),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w510, color: sel ? Colors.white : const Color(0xFF8E8E93))),
      ),
    );
  }

  Widget _sectionTitle(String title, ColorScheme cs) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w590, color: cs.onSurface, height: 1.4)),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify build**

```bash
cd D:\ACGNhub; flutter build windows --debug
```

- [ ] **Step 3: Commit**

```bash
git add lib/modules/anime/anime_home.dart; git commit -m "feat(anime): redesign home with Hero card, pill filters, grid layout"
```

---

### Task 6: Redesign anime search page

**Files:**
- Modify: `lib/modules/anime/anime_search.dart`

**Interfaces:**
- Consumes: `WorkCard` (Task 4), `ShimmerLoader` (Task 4), `EmptyState` (Task 4)
- Produces: Redesigned `AnimeSearchPage` with styled search bar, skeleton loading, error/empty states

- [ ] **Step 1: Replace lib/modules/anime/anime_search.dart**

```dart
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
    setState(() { _loading = true; _error = null; _hasSearched = true; });
    try {
      final svc = ref.read(bangumiServiceProvider);
      final items = await svc.searchSubject(k);
      setState(() {
        _results = items.map((item) => Work(
          id: 'bgm_${item['id']}',
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
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

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
          IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context), splashRadius: 20),
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
                      decoration: const InputDecoration(border: InputBorder.none, hintText: '搜索动漫...', hintStyle: TextStyle(color: Color(0xFF8E8E93), fontSize: 15), isDense: true, contentPadding: EdgeInsets.zero),
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  if (_ctrl.text.isNotEmpty)
                    GestureDetector(
                      onTap: () { _ctrl.clear(); setState(() {}); },
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
    if (_error != null) return EmptyState(icon: Icons.error_outline_rounded, message: _error!, actionLabel: '重试', onAction: _search);
    if (!_hasSearched) return EmptyState(icon: Icons.search_rounded, message: '输入关键词搜索动漫');
    if (_hasSearched && _results.isEmpty) return EmptyState(icon: Icons.search_off_rounded, message: '未找到「${_ctrl.text}」相关动漫，换个关键词试试');

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 0.66),
      itemCount: _results.length,
      itemBuilder: (context, index) => WorkCard(
        work: _results[index],
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BangumiDetailPage(work: _results[index]))),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify build**

```bash
cd D:\ACGNhub; flutter build windows --debug
```

- [ ] **Step 3: Commit**

```bash
git add lib/modules/anime/anime_search.dart; git commit -m "feat(anime): redesign search with styled bar, skeleton loading, proper states"
```

---

### Task 7: Redesign anime detail page

**Files:**
- Modify: `lib/modules/anime/bangumi_detail_page.dart`

**Interfaces:**
- Consumes: `Work`, `bangumiServiceProvider`, `AnimeSearchPage`
- Produces: Redesigned `BangumiDetailPage` with hero cover, meta chips, expandable summary, episode placeholder, fixed bottom CTA

- [ ] **Step 1: Replace lib/modules/anime/bangumi_detail_page.dart**

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
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.work.extra['bangumiId'] as int?;
    if (id == null) { setState(() => _loadingDetail = false); return; }
    final d = await ref.read(bangumiServiceProvider).getSubjectDetail(id);
    if (mounted) setState(() { _detail = d; _loadingDetail = false; });
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.work;
    final cs = Theme.of(context).colorScheme;
    final id = w.extra['bangumiId'] as int?;
    final rating = _detail?['rating'] as num?;
    final eps = _detail?['eps'] as int?;
    final air = _detail?['airDate'] as String?;
    final tags = (_detail?['tags'] as List<dynamic>?)?.map((t) => t.toString()).toList() ?? [];
    final cover = (_detail?['cover'] as String?) ?? w.coverUrl;
    final summary = _detail?['summary'] as String?;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Column(
        children: [
          _header(w, cs),
          Expanded(
            child: CustomScrollView(
              slivers: [
                _heroImage(cover, cs),
                _infoSection(w, cs, rating, eps, air),
                if (tags.isNotEmpty) _tagsRow(tags),
                _summarySection(summary, cs),
                _episodeSection(w, cs),
              ],
            ),
          ),
          _bottomBar(w, id),
        ],
      ),
    );
  }

  Widget _header(Work w, ColorScheme cs) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(color: Color(0xFFFFFFFF), border: Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5))),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context), splashRadius: 20),
          Expanded(child: Text(w.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w590, color: cs.onSurface))),
        ],
      ),
    );
  }

  Widget _heroImage(String? cover, ColorScheme cs) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 220,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (cover != null && cover.isNotEmpty)
              CachedNetworkImage(imageUrl: cover, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(color: cs.primary.withValues(alpha: 0.1)))
            else
              Container(color: cs.primary.withValues(alpha: 0.1)),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, const Color(0xFFF2F2F7)],
                    stops: const [0.6, 1],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoSection(Work w, ColorScheme cs, num? rating, int? eps, String? air) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 110, height: 154,
                child: w.coverUrl != null && w.coverUrl!.isNotEmpty
                    ? CachedNetworkImage(imageUrl: w.coverUrl!, fit: BoxFit.cover, errorWidget: (_, __, ___) => _coverPlaceholder(cs))
                    : _coverPlaceholder(cs),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(w.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.35), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  if (_loadingDetail)
                    SizedBox(width: 100, child: LinearProgressIndicator(minHeight: 2, color: const Color(0xFF007AFF).withValues(alpha: 0.3)))
                  else ...[
                    if (rating != null) _metaChip(Icons.star_rounded, rating.toStringAsFixed(1), Colors.amber),
                    if (eps != null) ...[const SizedBox(height: 6), _metaChip(Icons.live_tv_rounded, '$eps 话', const Color(0xFF007AFF))],
                    if (air != null) ...[const SizedBox(height: 6), _metaChip(Icons.calendar_today_rounded, air, const Color(0xFF5856D6))],
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
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [cs.primary.withValues(alpha: 0.1), cs.tertiary.withValues(alpha: 0.05)])),
      child: Center(child: Icon(Icons.image_outlined, size: 24, color: cs.primary.withValues(alpha: 0.2))),
    );
  }

  Widget _tagsRow(List<String> tags) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Wrap(
          spacing: 6, runSpacing: 6,
          children: tags.map((t) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFFE8F0FE), borderRadius: BorderRadius.circular(20)),
            child: Text(t, style: const TextStyle(fontSize: 11, color: Color(0xFF007AFF), fontWeight: FontWeight.w510)),
          )).toList(),
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
            Text('简介', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w590, color: cs.onSurface)),
            const SizedBox(height: 8),
            if (_loadingDetail)
              SizedBox(width: 100, child: LinearProgressIndicator(minHeight: 2, color: const Color(0xFF007AFF).withValues(alpha: 0.3)))
            else if (summary == null || summary.isEmpty)
              Text('暂无简介数据', style: TextStyle(fontSize: 13.5, color: cs.onSurface.withValues(alpha: 0.35)))
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

  Widget _episodeSection(Work w, ColorScheme cs) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('剧集列表', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w590, color: cs.onSurface)),
                    const Spacer(),
                    Text('正序 ▼', style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.45))),
                  ],
                ),
                const SizedBox(height: 12),
                Text('搜索播放资源以查看剧集', style: TextStyle(fontSize: 14, color: cs.onSurface.withValues(alpha: 0.35))),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    final kw = w.extra['keyword'] as String? ?? w.title;
                    Navigator.push(context, MaterialPageRoute(builder: (_) => AnimeSearchPage(initialKeyword: kw)));
                  },
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

  Widget _bottomBar(Work w, int? id) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: Color(0xFFFFFFFF), border: Border(top: BorderSide(color: Color(0xFFE5E5EA), width: 0.5))),
      child: SizedBox(
        width: double.infinity, height: 48,
        child: FilledButton.icon(
          onPressed: id != null ? () async {
            final uri = Uri.parse('https://bgm.tv/subject/$id');
            if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
          } : null,
          icon: const Icon(Icons.play_circle_rounded, size: 20),
          label: const Text('在Bangumi查看'),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify build**

```bash
cd D:\ACGNhub; flutter build windows --debug
```

- [ ] **Step 3: Commit**

```bash
git add lib/modules/anime/bangumi_detail_page.dart; git commit -m "feat(anime): redesign detail page with hero cover, meta chips, expandable summary"
```

---

### Task 8: Create styled placeholder pages for comic, novel, game

**Files:**
- Modify: `lib/shell/main_shell.dart` (update placeholders with styled designs)

**Interfaces:**
- Replaces generic placeholder widgets inside MainShell with styled ones matching spec section 6-8

- [ ] **Step 1: Replace placeholder factory in lib/shell/main_shell.dart**

In `lib/shell/main_shell.dart`, replace the `_buildPlaceholder` method and the `_pages` list:

```dart
  final _pages = <Widget>[
    const AnimeHomePage(),
    _buildModulePlaceholder('漫画', Icons.menu_book_rounded, '漫画模块', '聚合多种漫画平台资源，支持登录对应平台账号', const Color(0xFFFF9500)),
    _buildModulePlaceholder('轻小说', Icons.auto_stories_rounded, '轻小说模块', '阅读 Wenku8 文库的轻小说资源', const Color(0xFF34C759)),
    _buildModulePlaceholder('游戏', Icons.games_rounded, '游戏模块', '浏览 Galgame 游戏资源与详细信息', const Color(0xFFAF52DE)),
  ];

  static Widget _buildModulePlaceholder(String title, IconData icon, String subtitle, String desc, Color accent) {
    return Builder(builder: (context) {
      return Column(
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(color: Color(0xFFFFFFFF), border: Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5))),
            child: Row(
              children: [
                Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w590, color: Theme.of(context).colorScheme.onSurface, height: 1.4)),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                    child: Icon(icon, size: 36, color: accent),
                  ),
                  const SizedBox(height: 24),
                  Text(subtitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w590, color: Color(0xFF1C1C1E))),
                  const SizedBox(height: 8),
                  Text(desc, style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93))),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('即将推出', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w510, color: accent)),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
```

- [ ] **Step 2: Verify build**

```bash
cd D:\ACGNhub; flutter build windows --debug
```

- [ ] **Step 3: Commit**

```bash
git add lib/shell/main_shell.dart; git commit -m "feat(shell): create styled placeholder pages for comic, novel, game modules"
```

---

### Task 9: Integration test and final verification

**Files:**
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Update widget test**

Replace `test/widget_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:acgnhub/main.dart';

void main() {
  testWidgets('App launches with sidebar navigation', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ACGNhubApp()));
    await tester.pumpAndSettle();

    expect(find.text('动漫'), findsWidgets);
    expect(find.text('漫画'), findsWidgets);
    expect(find.text('轻小说'), findsWidgets);
    expect(find.text('游戏'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run all tests**

```bash
cd D:\ACGNhub; flutter test
```

- [ ] **Step 3: Build release**

```bash
cd D:\ACGNhub; flutter build windows --debug
```

- [ ] **Step 4: Commit**

```bash
git add test/widget_test.dart; git commit -m "test: update widget test for sidebar navigation"
```

---

## Completion Checklist

- [ ] App launches on Windows with light theme, iOS-light colors
- [ ] Left sidebar with 4 module icons + settings, collapsible
- [ ] Anime home: Hero card, pill filters (继续观看/热门推荐/最近更新), 5-column grid
- [ ] Anime search: styled search bar, skeleton loading, empty/error/no-results states
- [ ] Anime detail: hero cover, meta chips, expandable summary, episode placeholder, bottom CTA
- [ ] Styled placeholder pages for comic, novel, game with module accent colors
- [ ] All tests pass
- [ ] No build errors or warnings