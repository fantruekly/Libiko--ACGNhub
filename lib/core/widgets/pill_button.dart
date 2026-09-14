import 'package:flutter/material.dart';

import 'marquee_text.dart';

/// A pill-shaped action button matching the comic source chips, sized a little
/// larger for chapter / episode lists.
class PillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const PillButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        hoverColor: const Color(0x1F007AFF),
        child: Container(
          constraints: const BoxConstraints(minWidth: 104, maxWidth: 160),
          height: 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E5EA)),
          ),
          child: MarqueeText(
            text: label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1C1C1E),
            ),
          ),
        ),
      ),
    );
  }
}
