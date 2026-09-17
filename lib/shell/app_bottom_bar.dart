import 'package:flutter/material.dart';

import '../core/widgets/glass_surface.dart';

/// The phone navigation bar. Four module buttons over a translucent surface.
class AppBottomBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const AppBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
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
    return GlassSurface(
      borderRadius: BorderRadius.zero,
      blur: 18,
      color: cs.surface.withValues(alpha: 0.92),
      border: Border(
        top: BorderSide(color: cs.outlineVariant, width: 0.5),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _BarItem(
                    icon: _items[i].$1,
                    label: _items[i].$2,
                    selected: selectedIndex == i,
                    onTap: () => onChanged(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final idle = cs.onSurfaceVariant;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: selected ? 1 : 0),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOutCubic,
        builder: (context, t, _) {
          final color = Color.lerp(idle, cs.primary, t)!;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
