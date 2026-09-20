import 'package:flutter/material.dart';

import '../platform.dart';

/// Lays [children] out in equal-width buttons that wrap to as many rows as
/// needed.
///
/// On phones (and when [desktop] is false) it keeps the original two columns,
/// capped at [maxWidth]. On desktop it keeps each button at [desktopButtonWidth],
/// fits as many as the row allows, and centres the whole block horizontally
/// (rows inside the block stay left-aligned).
class ButtonGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double maxWidth;
  final double desktopButtonWidth;
  final bool? desktop;

  const ButtonGrid({
    super.key,
    required this.children,
    this.spacing = 10,
    this.maxWidth = 420,
    this.desktopButtonWidth = 205,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        if (!(desktop ?? isDesktop)) {
          final capped = available < maxWidth ? available : maxWidth;
          final width = (capped - spacing) / 2;
          return Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: capped,
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
        }
        final n = ((available + spacing) / (desktopButtonWidth + spacing))
            .floor()
            .clamp(1, children.isEmpty ? 1 : children.length);
        final blockWidth = n * desktopButtonWidth + (n - 1) * spacing;
        return Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: blockWidth,
            child: Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final child in children)
                  SizedBox(width: desktopButtonWidth, child: child),
              ],
            ),
          ),
        );
      },
    );
  }
}
