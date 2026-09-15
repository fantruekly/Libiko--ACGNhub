import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../core/widgets/glass_surface.dart';
import '../core/widgets/window_controls.dart';
import '../modules/anime/anime_home.dart';
import '../modules/anime/anime_search.dart';
import '../modules/comic/comic_home.dart';
import '../modules/comic/comic_search.dart';
import '../modules/novel/novel_home.dart';
import '../modules/novel/novel_search.dart';
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

  static const _titles = ['动漫', '漫画', '轻小说', '游戏'];
  static const _fg = Color(0xFF1C1C1E);
  static const _muted = Color(0xFF5A5A5F);
  static const _border = Color(0xFFE5E5EA);
  static const _accent = Color(0xFF007AFF);

  final _pages = <Widget>[
    const AnimeHomePage(),
    const ComicHomePage(),
    const NovelHomePage(),
    _buildModulePlaceholder('游戏', Icons.games_rounded, '游戏模块',
        '浏览 Galgame 游戏资源与详细信息', const Color(0xFFAF52DE)),
  ];

  static Widget _buildModulePlaceholder(
      String title, IconData icon, String subtitle, String desc, Color accent) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20)),
            child: Icon(icon, size: 36, color: accent),
          ),
          const SizedBox(height: 24),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600, color: _fg)),
          const SizedBox(height: 8),
          Text(desc, style: const TextStyle(fontSize: 14, color: _muted)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('即将推出',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500, color: accent)),
          ),
        ],
      ),
    );
  }

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

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Column(
        children: [
          _titleBar(collapsed),
          Expanded(
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  width: collapsed ? 0 : 72,
                  clipBehavior: Clip.hardEdge,
                  decoration: const BoxDecoration(color: Color(0xFFF9F9FC)),
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
      ),
    );
  }

  Widget _titleBar(bool collapsed) {
    return DragToMoveArea(
      child: GlassSurface(
        borderRadius: BorderRadius.zero,
        blur: 18,
        color: const Color(0xF2FFFFFF),
        child: Container(
          height: 48,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _border, width: 0.5)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                child: Center(
                  child: _SidebarToggleButton(
                    collapsed: collapsed,
                    onTap: () => _sidebarState.toggle(),
                  ),
                ),
              ),
              Text(
                _titles[_currentIndex],
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: _fg,
                    height: 1.4),
              ),
              const Spacer(),
              if (_currentIndex >= 0 && _currentIndex <= 2)
                IconButton(
                  icon: const Icon(Icons.search_rounded, size: 20),
                  color: _muted,
                  splashRadius: 20,
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => _currentIndex == 0
                              ? const AnimeSearchPage()
                              : _currentIndex == 1
                                  ? const ComicSearchPage()
                                  : const NovelSearchPage())),
                ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: _openSettings,
                  child: const CircleAvatar(
                    radius: 15,
                    backgroundColor: Color(0xFFE8F0FE),
                    child: Text('A',
                        style: TextStyle(
                            fontSize: 13,
                            color: _accent,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const WindowControls(),
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

  static const _fg = Color(0xFF1C1C1E);

  @override
  Widget build(BuildContext context) {
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
                color: _fg.withValues(alpha: 0.55),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
