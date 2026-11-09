import 'package:flutter/material.dart';

import '../platform.dart';
import 'adaptive_grid.dart';
import 'poster_title.dart';

class ShimmerLoader extends StatefulWidget {
  final int itemCount;
  final int crossAxisCount;
  final int mobileColumns;
  final double aspectRatio;
  final EdgeInsets padding;
  final double? mobileTitleExtent;
  final Widget? mobileHeader;

  const ShimmerLoader({
    super.key,
    this.itemCount = 12,
    this.crossAxisCount = 5,
    this.mobileColumns = 3,
    this.aspectRatio = 0.60,
    this.padding = const EdgeInsets.all(16),
    this.mobileTitleExtent,
    this.mobileHeader,
  });

  @override
  State<ShimmerLoader> createState() => _ShimmerLoaderState();
}

class _ShimmerLoaderState extends State<ShimmerLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context)) {
      _ctrl.stop();
      _ctrl.value = 0.5;
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mobilePosters = !isDesktop && widget.mobileTitleExtent != null;
    final titleHeight = mobilePosters ? PosterTitle.heightOf(context) : 26.0;
    final barScale = (titleHeight / 26).clamp(0.0, 1.0);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final o = 0.3 +
            0.3 * (_ctrl.value < 0.5 ? _ctrl.value * 2 : (1 - _ctrl.value) * 2);
        final fill = cs.outlineVariant.withValues(alpha: o);
        Widget buildPlaceholder(BuildContext context, int index) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(mobilePosters ? 14 : 10),
                      color: fill,
                    ),
                  ),
                ),
                SizedBox(height: mobilePosters ? PosterTitle.gap : 6),
                SizedBox(
                  height: titleHeight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 12 * barScale,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: fill,
                        ),
                      ),
                      SizedBox(height: 4 * barScale),
                      FractionallySizedBox(
                        widthFactor: 0.62,
                        alignment: AlignmentDirectional.centerStart,
                        child: Container(
                          height: 10 * barScale,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: fill.withValues(alpha: o * 0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
        if (mobilePosters) {
          return CustomScrollView(
            slivers: [
              if (widget.mobileHeader != null)
                SliverToBoxAdapter(child: widget.mobileHeader),
              SliverAdaptiveGrid(
                itemCount: widget.itemCount,
                mobileColumns: widget.mobileColumns,
                mobileTitleExtent: widget.mobileTitleExtent!,
                responsiveColumns: true,
                padding: widget.padding,
                itemBuilder: buildPlaceholder,
              ),
            ],
          );
        }
        return GridView.builder(
          padding: widget.padding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:
                isDesktop ? widget.crossAxisCount : widget.mobileColumns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: widget.aspectRatio,
          ),
          itemCount: widget.itemCount,
          itemBuilder: buildPlaceholder,
        );
      },
    );
  }
}
