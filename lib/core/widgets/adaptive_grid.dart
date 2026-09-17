import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../platform.dart';

const double _kMainAxisSpacing = 20;
const double _kCrossAxisSpacing = 16;
const int _kDesktopColumns = 6;
const double _kDesktopAspectRatio = 0.60;

/// A grid of cards inside a [CustomScrollView]. Mobile lays the cards out as a
/// masonry grid (each card keeps its own height); desktop keeps the fixed
/// 6-column grid this app has always used.
class SliverAdaptiveGrid extends StatelessWidget {
  final int itemCount;
  final int mobileColumns;
  final Widget Function(BuildContext, int) itemBuilder;
  final EdgeInsetsGeometry padding;
  final double desktopAspectRatio;
  final bool? desktop;

  const SliverAdaptiveGrid({
    super.key,
    required this.itemCount,
    required this.mobileColumns,
    required this.itemBuilder,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 24),
    this.desktopAspectRatio = _kDesktopAspectRatio,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    if (desktop ?? isDesktop) {
      return SliverPadding(
        padding: padding,
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _kDesktopColumns,
            mainAxisSpacing: _kMainAxisSpacing,
            crossAxisSpacing: _kCrossAxisSpacing,
            childAspectRatio: desktopAspectRatio,
          ),
          delegate: SliverChildBuilderDelegate(itemBuilder,
              childCount: itemCount),
        ),
      );
    }
    return SliverPadding(
      padding: padding,
      sliver: SliverMasonryGrid.count(
        crossAxisCount: mobileColumns,
        mainAxisSpacing: _kMainAxisSpacing,
        crossAxisSpacing: _kCrossAxisSpacing,
        childCount: itemCount,
        itemBuilder: itemBuilder,
      ),
    );
  }
}

/// The same switch for a standalone scroll view.
class AdaptiveGridView extends StatelessWidget {
  final int itemCount;
  final int mobileColumns;
  final Widget Function(BuildContext, int) itemBuilder;
  final EdgeInsetsGeometry padding;
  final double desktopAspectRatio;
  final bool? desktop;

  const AdaptiveGridView({
    super.key,
    required this.itemCount,
    required this.mobileColumns,
    required this.itemBuilder,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24),
    this.desktopAspectRatio = _kDesktopAspectRatio,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    if (desktop ?? isDesktop) {
      return GridView.builder(
        padding: padding,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _kDesktopColumns,
          mainAxisSpacing: _kMainAxisSpacing,
          crossAxisSpacing: _kCrossAxisSpacing,
          childAspectRatio: desktopAspectRatio,
        ),
        itemCount: itemCount,
        itemBuilder: itemBuilder,
      );
    }
    return MasonryGridView.count(
      padding: padding,
      crossAxisCount: mobileColumns,
      mainAxisSpacing: _kMainAxisSpacing,
      crossAxisSpacing: _kCrossAxisSpacing,
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}
