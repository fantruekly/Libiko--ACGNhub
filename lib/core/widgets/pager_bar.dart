import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The bottom page switcher: tonal rounded prev/next buttons around a label.
class PagerBar extends StatelessWidget {
  final String label;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const PagerBar({
    super.key,
    required this.label,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PagerButton(
            icon: Icons.chevron_left_rounded,
            tooltip: '上一页',
            onTap: onPrevious,
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.onSecondaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _PagerButton(
            icon: Icons.chevron_right_rounded,
            tooltip: '下一页',
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

class _PagerButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _PagerButton({required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: enabled
            ? cs.secondaryContainer
            : cs.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: SizedBox(
            width: 40,
            height: 32,
            child: Icon(
              icon,
              size: 20,
              color: enabled
                  ? cs.onSecondaryContainer
                  : cs.onSecondaryContainer.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}
