import 'package:flutter/material.dart';
import '../core/platform.dart';
import '../core/theme/app_theme.dart';
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
import 'app_sidebar.dart';
import 'app_bottom_bar.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
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

  void _openSettings() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const SettingsPage()));
  }

  @override
  Widget build(BuildContext context) {
    final collapsed = _sidebarState.collapsed;
    final content = Column(
      children: [
        _titleBar(collapsed),
        Expanded(
          child: Row(
            children: [
              if (isDesktop)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  width: collapsed ? 0 : 72,
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow),
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    minWidth: 72,
                    maxWidth: 72,
                    child: AppSidebar(
                      selectedIndex: _currentIndex,
                      onChanged: (i) => setState(() => _currentIndex = i),
                      onSettingsTap: _openSettings,
                    ),
                  ),
                ),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    for (var i = 0; i < _pages.length; i++)
                      IgnorePointer(
                        ignoring: i != _currentIndex,
                        child: AnimatedOpacity(
                          key: ValueKey('module-page-$i'),
                          opacity: i == _currentIndex ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          child: _pages[i],
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
      backgroundColor: kAppBackground,
      body: content,
      bottomNavigationBar: isDesktop
          ? null
          : AppBottomBar(
              selectedIndex: _currentIndex,
              onChanged: (i) => setState(() => _currentIndex = i),
            ),
    );
  }

  Widget _titleBar(bool collapsed) {
    final cs = Theme.of(context).colorScheme;
    final topInset = isDesktop ? 0.0 : MediaQuery.of(context).padding.top;
    return DesktopDragArea(
      child: GlassSurface(
        borderRadius: BorderRadius.zero,
        blur: 18,
        color: kAppBackground,
        child: Container(
          height: 48 + topInset,
          padding: EdgeInsets.only(top: topInset),
          child: Row(
            children: [
              if (isDesktop)
                SizedBox(
                  width: 72,
                  child: Center(
                    child: _SidebarToggleButton(
                      collapsed: collapsed,
                      onTap: () => _sidebarState.toggle(),
                    ),
                  ),
                )
              else
                const SizedBox(width: 16),
              Text(
                _titles[_currentIndex],
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                    height: 1.4),
              ),
              const Spacer(),
              if (_currentIndex >= 0 && _currentIndex <= 3)
                IconButton(
                  icon: const Icon(Icons.search_rounded, size: 20),
                  color: cs.onSurfaceVariant,
                  splashRadius: 20,
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => _currentIndex == 0
                              ? const AnimeSearchPage()
                              : _currentIndex == 1
                                  ? const ComicSearchPage()
                                  : _currentIndex == 2
                                      ? const NovelSearchPage()
                                      : const GameSearchPage())),
                ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  tooltip: '设置',
                  icon: const Icon(Icons.settings_rounded, size: 20),
                  color: cs.onSurfaceVariant,
                  splashRadius: 20,
                  onPressed: _openSettings,
                ),
              ),
              if (isDesktop) const WindowControls(),
            ],
          ),
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
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(scale: anim, child: child),
              ),
              child: Icon(
                collapsed ? Icons.chevron_right_rounded : Icons.menu_rounded,
                key: ValueKey<bool>(collapsed),
                size: 22,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
