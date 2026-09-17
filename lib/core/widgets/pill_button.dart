import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'marquee_text.dart';

/// A tonal action button used for chapter / episode lists.
class PillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const PillButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.secondaryContainer,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        hoverColor: cs.primary.withValues(alpha: 0.12),
        child: Container(
          constraints: const BoxConstraints(minWidth: 104, maxWidth: 160),
          height: 40,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: MarqueeText(
            text: label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: cs.onSecondaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}
