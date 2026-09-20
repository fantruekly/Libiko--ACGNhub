import 'package:flutter/material.dart';

/// A small primary-tinted tag chip used on detail pages.
class TagChip extends StatelessWidget {
  final String label;

  const TagChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: cs.primary)),
    );
  }
}
