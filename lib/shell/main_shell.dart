import 'package:flutter/material.dart';
import '../core/platform.dart';
import '../core/widgets/desktop_drag_area.dart';
import '../core/widgets/glass_surface.dart';
import '../core/widgets/window_controls.dart';
import '../modules/anime/anime_home.dart';
import '../modules/anime/anime_search.dart';
import '../modules/comic/comic_home.dart';
import '../modules/comic/comic_search.dart';
import '../modules/novel/novel_home.dart';
import '../modules/novel/novel_search.dart';
import '../modules/game/game_home.dart';
import '../modules/game/game_search.dart';
import 'settings_page.dart';
import 'recent_activity_page.dart';
import 'app_sidebar.dart';
import 'app_bottom_bar.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final Set<int> _visited = {0};
  late final SidebarState _sidebarState;

  static const _titles = ['动漫', '漫画', '轻小说', '游戏'];

  final _pages = <Widget>[
    const AnimeHomePage(),
    const ComicHomePage(),
    const NovelHomePage(),
    const GameHomePage(),
  ];

  @override
  void initState() {
    super.initState();
    _sidebarState = SidebarState();
    _sidebarState.addListener(_onSidebarChanged);
  }

  void _onSidebarChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _sidebarState.removeListener(_onSidebarChanged);
    _sidebarState.dispose();
    super.dispose();
  }

  void _select(int i) {
    setState(() {
      _currentIndex = i;
      _visited.add(i);
    });
  }

  void _openSettings() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const SettingsPage()));
  }

  void _openRecent() {
    Navigator.push(context,
        MaterialPageRoute<void>(builder: (_) => const RecentActivityPage()));
  }

  void _openSearch() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => switch (_currentIndex) {
                  0 => const AnimeSearchPage(),
                  1 => const ComicSearchPage(),
                  2 => const NovelSearchPage(),
                  _ => const GameSearchPage(),
                }));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) =>
            _buildShell(context, constraints.maxWidth),
      );

  Widget _buildShell(BuildContext context, double width) {
    final cs = Theme.of(context).colorScheme;
    final desktopNavigation = isDesktop && width >= 700;
    final collapsed = _sidebarState.collapsed;
    final reduceMotion = MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final ambient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.alphaBlend(cs.primary.withValues(alpha: 0.14), cs.surface),
        Color.alphaBlend(cs.primary.withValues(alpha: 0.04), cs.surface),
        Color.alphaBlend(cs.tertiary.withValues(alpha: 0.08), cs.surface),
      ],
      stops: const [0, 0.55, 1],
    );
    final content = Column(
      children: [
        _titleBar(collapsed, desktopNavigation),
        Expanded(
          child: Row(
            children: [
              if (desktopNavigation)
                AnimatedContainer(
                  key: const ValueKey('sidebar-panel'),
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 260),
                  curve: Curves.easeInOutCubic,
                  width: collapsed ? 0 : AppSidebar.width,
                  clipBehavior: Clip.hardEdge,
                  decoration: const BoxDecoration(),
                  child: ExcludeFocus(
                    excluding: collapsed,
                    child: ExcludeSemantics(
                      excluding: collapsed,
                      child: OverflowBox(
                        alignment: Alignment.centerLeft,
                        minWidth: AppSidebar.width,
                        maxWidth: AppSidebar.width,
                        child: AppSidebar(
                          selectedIndex: _currentIndex,
                          onChanged: _select,
                          onRecentTap: _openRecent,
                          onSettingsTap: _openSettings,
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    for (final i in _visited)
                      IgnorePointer(
                        ignoring: i != _currentIndex,
                        child: ExcludeFocus(
                          excluding: i != _currentIndex,
                          child: ExcludeSemantics(
                            excluding: i != _currentIndex,
                            child: AnimatedOpacity(
                              key: ValueKey('module-page-$i'),
                              opacity: i == _currentIndex ? 1.0 : 0.0,
                              duration: reduceMotion
                                  ? Duration.zero
                                  : const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              child: _pages[i],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: ambient),
        child: content,
      ),
      bottomNavigationBar: desktopNavigation
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(gradient: ambient),
              child: AppBottomBar(
                  selectedIndex: _currentIndex, onChanged: _select),
            ),
    );
  }

  Widget _titleBar(bool collapsed, bool desktopNavigation) {
    final cs = Theme.of(context).colorScheme;
    final topInset = isDesktop ? 0.0 : MediaQuery.paddingOf(context).top;
    return GlassSurface(
      borderRadius: BorderRadius.zero,
      blur: 14,
      color: cs.surface.withValues(alpha: 0.76),
      border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.45))),
      child: Container(
        height: 56 + topInset,
        padding: EdgeInsets.only(top: topInset),
        child: Row(
          children: [
            if (desktopNavigation) ...[
              DesktopDragArea(
                  child: SizedBox(
                width: AppSidebar.width,
                height: 56,
                child: Padding(
                  padding: const EdgeInsets.only(left: 22),
                  child: Row(children: [
                    Icon(Icons.auto_awesome_mosaic_rounded,
                        size: 22, color: cs.primary),
                    const SizedBox(width: 9),
                    Text('Libiko',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface)),
                  ]),
                ),
              )),
              _SidebarToggleButton(
                  collapsed: collapsed, onTap: () => _sidebarState.toggle()),
              const SizedBox(width: 10),
            ] else
              const SizedBox(width: 20),
            Expanded(
              child: DesktopDragArea(
                  child: SizedBox(
                      height: 56,
                      child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _titles[_currentIndex],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                                height: 1.4),
                          )))),
            ),
            IconButton(
              key: const ValueKey('recent-activity'),
              tooltip: '最近观看与阅读',
              icon: const Icon(Icons.history_rounded, size: 20),
              color: cs.onSurfaceVariant,
              onPressed: _openRecent,
            ),
            IconButton(
              tooltip: '搜索',
              icon: const Icon(Icons.search_rounded, size: 20),
              color: cs.onSurfaceVariant,
              onPressed: _openSearch,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                tooltip: '设置',
                icon: const Icon(Icons.settings_outlined, size: 20),
                color: cs.onSurfaceVariant,
                onPressed: _openSettings,
              ),
            ),
            if (desktopNavigation) const WindowControls(),
          ],
        ),
      ),
    );
  }
}

class _SidebarToggleButton extends StatelessWidget {
  final bool collapsed;
  final VoidCallback onTap;

  const _SidebarToggleButton({required this.collapsed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('sidebar-toggle'),
      tooltip: collapsed ? '展开导航' : '收起导航',
      onPressed: onTap,
      icon: Icon(collapsed ? Icons.menu_open_rounded : Icons.menu_rounded,
          size: 20),
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}
