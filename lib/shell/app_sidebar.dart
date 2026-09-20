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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 72,
      color: cs.surfaceContainerLow,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: cs.outlineVariant),
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

class _SidebarItem extends StatefulWidget {
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

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final idleIcon = cs.onSurfaceVariant.withValues(alpha: 0.7);
    final idleText = cs.onSurfaceVariant;
    final hoverBg = (!widget.selected && _hovered)
        ? cs.onSurface.withValues(alpha: 0.06)
        : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          key: ValueKey('sidebar-bg-${widget.label}'),
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: hoverBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(
                begin: widget.selected ? 1.0 : 0.0,
                end: widget.selected ? 1.0 : 0.0),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOutCubic,
            builder: (context, t, _) {
              final iconColor = Color.lerp(idleIcon, cs.primary, t)!;
              final textColor = Color.lerp(idleText, cs.primary, t)!;
              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    width: 72,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(widget.icon, size: 24, color: iconColor),
                        const SizedBox(height: 4),
                        Text(
                          widget.label,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: widget.selected
                                ? FontWeight.w600
                                : FontWeight.w500,
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
                        child: Container(width: 3, color: cs.primary),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
