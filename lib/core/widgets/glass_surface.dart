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
    final media = MediaQuery.maybeOf(context);
    final reduceEffects =
        media?.highContrast == true || media?.disableAnimations == true;
    final tint = reduceEffects
        ? (color ?? cs.surface).withValues(alpha: 1)
        : color ?? cs.surface.withValues(alpha: 0.82);
    final sigma = reduceEffects || tint.a == 1 ? 0.0 : blur.clamp(0.0, 24.0);
    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: borderRadius,
        border: border ??
            Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.55), width: 0.7),
      ),
      child: child,
    );
    // A BackdropFilter is expensive; skip it when no blur is requested.
    if (sigma > 0) {
      content = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: content,
      );
    }
    return DecoratedBox(
      decoration:
          BoxDecoration(borderRadius: borderRadius, boxShadow: boxShadow),
      child: ClipRRect(borderRadius: borderRadius, child: content),
    );
  }
}
