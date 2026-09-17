import 'package:flutter/material.dart';

/// Lays [children] out in two equal-width columns, wrapping to as many rows as
/// needed. An odd trailing child keeps half width (it is not stretched).
class TwoColumnButtonGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;

  const TwoColumnButtonGrid({
    super.key,
    required this.children,
    this.spacing = 10,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}
