import 'dart:ui';
import 'package:flutter/material.dart';

class GlassSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsets? padding;
  final double blur;
  final Color? color;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;

  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.padding,
    this.blur = 14,
    this.color,
    this.border,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? cs.surface.withValues(alpha: 0.97),
        borderRadius: borderRadius,
        border: border,
      ),
      child: child,
    );
    // A BackdropFilter is expensive; skip it when no blur is requested.
    if (blur > 0) {
      content = ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: content,
        ),
      );
    }
    return DecoratedBox(
      decoration:
          BoxDecoration(borderRadius: borderRadius, boxShadow: boxShadow),
      child: content,
    );
  }
}
