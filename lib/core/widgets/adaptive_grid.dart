import 'package:flutter/material.dart';

import '../platform.dart';

const double _kMainAxisSpacing = 20;
const double _kCrossAxisSpacing = 16;
const double _kDesktopAspectRatio = 0.60;

/// A grid of cards inside a [CustomScrollView]. Mobile lays the cards out on a
/// fixed-extent grid (uniform cover ratio plus a fixed title area) so columns
/// stay aligned; desktop keeps the fixed 6-column grid this app has always used.
class SliverAdaptiveGrid extends StatelessWidget {
  final int itemCount;
  final int mobileColumns;
  final int desktopColumns;
  final Widget Function(BuildContext, int) itemBuilder;
  final EdgeInsetsGeometry padding;
  final double desktopAspectRatio;
  final double mobileCoverRatio;
  final double mobileTitleExtent;
  final bool? desktop;

  const SliverAdaptiveGrid({
    super.key,
    required this.itemCount,
    required this.mobileColumns,
    required this.itemBuilder,
    this.desktopColumns = 6,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 24),
    this.desktopAspectRatio = _kDesktopAspectRatio,
    this.mobileCoverRatio = 2 / 3,
    this.mobileTitleExtent = 44,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    if (desktop ?? isDesktop) {
      return SliverPadding(
        padding: padding,
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: desktopColumns,
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
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final horizontal = padding.resolve(TextDirection.ltr).horizontal;
          final cellWidth = (constraints.crossAxisExtent -
                  horizontal -
                  _kCrossAxisSpacing * (mobileColumns - 1)) /
              mobileColumns;
          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: mobileColumns,
              mainAxisSpacing: _kMainAxisSpacing,
              crossAxisSpacing: _kCrossAxisSpacing,
              mainAxisExtent: cellWidth / mobileCoverRatio + mobileTitleExtent,
            ),
            delegate: SliverChildBuilderDelegate(itemBuilder,
                childCount: itemCount),
          );
        },
      ),
    );
  }
}

/// The same switch for a standalone scroll view.
class AdaptiveGridView extends StatelessWidget {
  final int itemCount;
  final int mobileColumns;
  final int desktopColumns;
  final Widget Function(BuildContext, int) itemBuilder;
  final EdgeInsetsGeometry padding;
  final double desktopAspectRatio;
  final double mobileCoverRatio;
  final double mobileTitleExtent;
  final bool? desktop;

  const AdaptiveGridView({
    super.key,
    required this.itemCount,
    required this.mobileColumns,
    required this.itemBuilder,
    this.desktopColumns = 6,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24),
    this.desktopAspectRatio = _kDesktopAspectRatio,
    this.mobileCoverRatio = 2 / 3,
    this.mobileTitleExtent = 44,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    if (desktop ?? isDesktop) {
      return GridView.builder(
        padding: padding,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: desktopColumns,
          mainAxisSpacing: _kMainAxisSpacing,
          crossAxisSpacing: _kCrossAxisSpacing,
          childAspectRatio: desktopAspectRatio,
        ),
        itemCount: itemCount,
        itemBuilder: itemBuilder,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = padding.resolve(TextDirection.ltr).horizontal;
        final cellWidth = (constraints.maxWidth -
                horizontal -
                _kCrossAxisSpacing * (mobileColumns - 1)) /
            mobileColumns;
        return GridView.builder(
          padding: padding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: mobileColumns,
            mainAxisSpacing: _kMainAxisSpacing,
            crossAxisSpacing: _kCrossAxisSpacing,
            mainAxisExtent: cellWidth / mobileCoverRatio + mobileTitleExtent,
          ),
          itemCount: itemCount,
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}
