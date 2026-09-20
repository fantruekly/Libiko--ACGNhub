import 'package:flutter/material.dart';

import '../../core/widgets/glass_surface.dart';

/// A shimmering skeleton shaped like the comic detail page (cover + info card +
/// chapter grid), shown while the detail loads.
class ComicDetailSkeleton extends StatefulWidget {
  const ComicDetailSkeleton({super.key});

  @override
  State<ComicDetailSkeleton> createState() => _ComicDetailSkeletonState();
}

class _ComicDetailSkeletonState extends State<ComicDetailSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _bar(double width, double height, double o) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E5EA).withValues(alpha: o),
          borderRadius: BorderRadius.circular(4),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final o = 0.3 +
            0.3 *
                (_ctrl.value < 0.5
                    ? _ctrl.value * 2
                    : (1 - _ctrl.value) * 2);
        return ListView(
          key: const ValueKey('comic-detail-skeleton'),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            GlassSurface(
              blur: 0,
              borderRadius: BorderRadius.circular(16),
              padding: const EdgeInsets.all(16),
              border: Border.all(color: cs.outlineVariant),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                        width: 110,
                        height: 154,
                        color: const Color(0xFFE5E5EA).withValues(alpha: o)),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _bar(double.infinity, 20, o),
                        const SizedBox(height: 10),
                        _bar(160, 20, o),
                        const SizedBox(height: 18),
                        _bar(96, 32, o),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (var i = 0; i < 6; i++) _bar(56, 20, o),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _bar(double.infinity, 12, o),
                        const SizedBox(height: 8),
                        _bar(double.infinity, 12, o),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassSurface(
              blur: 0,
              borderRadius: BorderRadius.circular(16),
              padding: const EdgeInsets.all(16),
              border: Border.all(color: cs.outlineVariant),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bar(120, 18, o),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (var i = 0; i < 6; i++)
                        _bar(150, 40, o),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
