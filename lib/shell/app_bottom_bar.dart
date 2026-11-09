import 'package:flutter/material.dart';

import '../core/widgets/glass_surface.dart';

/// Four compact module buttons on a bounded translucent navigation surface.
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
    final scaledLabel = MediaQuery.textScalerOf(context).scale(12);
    final reduceMotion = MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    return GlassSurface(
      borderRadius: BorderRadius.zero,
      blur: 14,
      color: cs.surface.withValues(alpha: 0.8),
      border: Border(
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5))),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68 + (scaledLabel - 12).clamp(0.0, 24.0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                child: AnimatedAlign(
                  alignment: AlignmentDirectional(
                      -1 + 2 * selectedIndex / (_items.length - 1), 0),
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 360),
                  curve: Curves.easeInOutCubicEmphasized,
                  child: FractionallySizedBox(
                    widthFactor: 1 / _items.length,
                    heightFactor: 1,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
                      child: DecoratedBox(
                        key: const ValueKey('bar-selection'),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              cs.secondaryContainer,
                              Color.alphaBlend(
                                  cs.primary.withValues(alpha: 0.08),
                                  cs.secondaryContainer),
                            ],
                          ),
                          border: Border.all(
                              color: cs.primary.withValues(alpha: 0.14)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < _items.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 6),
                        child: _BarItem(
                          icon: _items[i].$1,
                          label: _items[i].$2,
                          selected: selectedIndex == i,
                          onTap: () => onChanged(i),
                        ),
                      ),
                    ),
                ],
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
    final reduceMotion = MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      onTap: onTap,
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: selected ? 1 : 0, end: selected ? 1 : 0),
          duration:
              reduceMotion ? Duration.zero : const Duration(milliseconds: 240),
          curve: Curves.easeInOutCubic,
          builder: (context, t, _) => Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              focusColor: cs.primary.withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Transform.translate(
                      offset: Offset(0, reduceMotion ? 0 : -1.5 * t),
                      child: Transform.scale(
                        scale: reduceMotion ? 1 : 1 + 0.1 * t,
                        child: Icon(icon,
                            size: 22,
                            color:
                                Color.lerp(cs.onSurfaceVariant, cs.primary, t)),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            height: 1.2,
                            fontWeight: FontWeight.w500,
                            color: Color.lerp(
                                cs.onSurfaceVariant, cs.primary, t))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
