import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SidebarState extends ChangeNotifier {
  bool _collapsed = false;
  static const _key = 'sidebar_collapsed';

  bool get collapsed => _collapsed;

  SidebarState() {
    _load();
  }

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
  final VoidCallback onSettingsTap;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
    required this.onSettingsTap,
  });

  static const _items = [
    (Icons.live_tv_rounded, '动漫'),
    (Icons.menu_book_rounded, '漫画'),
    (Icons.auto_stories_rounded, '轻小说'),
    (Icons.games_rounded, '游戏'),
  ];

  static const _sidebarBg = Color(0xFFF9F9FC);
  static const _border = Color(0xFFE5E5EA);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      color: _sidebarBg,
      child: Column(
        children: [
          const Spacer(),
          ...List.generate(
            _items.length,
            (i) => _SidebarItem(
              icon: _items[i].$1,
              label: _items[i].$2,
              selected: selectedIndex == i,
              onTap: () => onChanged(i),
            ),
          ),
          const Spacer(flex: 2),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: _border),
          ),
          const SizedBox(height: 4),
          _SidebarItem(
            icon: Icons.settings_rounded,
            label: '设置',
            selected: false,
            onTap: onSettingsTap,
          ),
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

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const _accent = Color(0xFF007AFF);
  static const _fg = Color(0xFF1C1C1E);

  @override
  Widget build(BuildContext context) {
    final idleIcon = _fg.withValues(alpha: 0.35);
    final idleText = _fg.withValues(alpha: 0.45);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(
            begin: selected ? 1.0 : 0.0, end: selected ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOutCubic,
        builder: (context, t, _) {
          final iconColor = Color.lerp(idleIcon, _accent, t)!;
          final textColor = Color.lerp(idleText, _accent, t)!;
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                width: 72,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 24, color: iconColor),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Opacity(
                  key: const ValueKey('sidebar-line'),
                  opacity: t,
                  child: Transform.scale(
                    scaleY: t,
                    alignment: Alignment.center,
                    child: Container(width: 3, color: _accent),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
