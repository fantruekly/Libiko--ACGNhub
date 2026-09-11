import 'package:flutter/material.dart';

class RatingStars extends StatelessWidget {
  final double? score; // 0-10 scale
  final double size;

  const RatingStars({super.key, this.score, this.size = 18});

  static const _gold = Color(0xFFFFB300);

  @override
  Widget build(BuildContext context) {
    final s = score;
    if (s == null) return const SizedBox.shrink();

    final scaled = s.clamp(0, 10) / 2; // 0-5 stars
    final full = scaled.floor();
    final hasHalf = (scaled - full) >= 0.25;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Icon(
            i < full
                ? Icons.star_rounded
                : (i == full && hasHalf ? Icons.star_half_rounded : Icons.star_outline_rounded),
            size: size,
            color: _gold,
          ),
        const SizedBox(width: 6),
        Text(
          s.clamp(0, 10).toStringAsFixed(1),
          style: TextStyle(fontSize: size * 0.8, fontWeight: FontWeight.w600, color: _gold),
        ),
      ],
    );
  }
}
