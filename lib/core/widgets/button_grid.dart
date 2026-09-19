import 'package:flutter/material.dart';

/// Lays [children] out in two equal-width columns, wrapping to as many rows as
/// needed. An odd trailing child keeps half width (it is not stretched).
///
/// The grid is capped at [maxWidth] so a wide desktop window does not stretch
/// each button across half the screen; on phones the cap has no effect.
class TwoColumnButtonGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double maxWidth;

  const TwoColumnButtonGrid({
    super.key,
    required this.children,
    this.spacing = 10,
    this.maxWidth = 420,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth < maxWidth
            ? constraints.maxWidth
            : maxWidth;
        final width = (available - spacing) / 2;
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: available,
            child: Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final child in children)
                  SizedBox(width: width, child: child),
              ],
            ),
          ),
        );
      },
    );
  }
}
