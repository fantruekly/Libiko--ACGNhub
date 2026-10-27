import 'package:flutter/material.dart';

import '../platform.dart';

const double _kMainAxisSpacing = 20;
const double _kCrossAxisSpacing = 16;
const double _kDesktopAspectRatio = 0.60;

SliverGridDelegateWithFixedCrossAxisCount _responsiveDelegate(
    BuildContext context, double width, double coverRatio, double titleExtent) {
  final columns = ((width + _kCrossAxisSpacing) / 184).floor().clamp(2, 8);
  final cellWidth = ((width - _kCrossAxisSpacing * (columns - 1)) / columns)
      .clamp(0.0, double.infinity);
  final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    mainAxisSpacing: 24,
    crossAxisSpacing: _kCrossAxisSpacing,
    mainAxisExtent: cellWidth / coverRatio + titleExtent * scale,
  );
}

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

  /// Opt in to width-based poster columns and space for scaled titles.
  final bool responsiveColumns;

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
    this.responsiveColumns = false,
  });

  @override
  Widget build(BuildContext context) {
    if (responsiveColumns) {
      return SliverPadding(
        padding: padding,
        sliver: SliverLayoutBuilder(
            builder: (context, constraints) => SliverGrid(
                  gridDelegate: _responsiveDelegate(
                      context,
                      constraints.crossAxisExtent,
                      mobileCoverRatio,
                      mobileTitleExtent),
                  delegate: SliverChildBuilderDelegate(itemBuilder,
                      childCount: itemCount),
                )),
      );
    }
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
          delegate:
              SliverChildBuilderDelegate(itemBuilder, childCount: itemCount),
        ),
      );
    }
    return SliverPadding(
      padding: padding,
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final cellWidth = (constraints.crossAxisExtent -
                  _kCrossAxisSpacing * (mobileColumns - 1)) /
              mobileColumns;
          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: mobileColumns,
              mainAxisSpacing: _kMainAxisSpacing,
              crossAxisSpacing: _kCrossAxisSpacing,
              mainAxisExtent: cellWidth / mobileCoverRatio + mobileTitleExtent,
            ),
            delegate:
                SliverChildBuilderDelegate(itemBuilder, childCount: itemCount),
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
  final bool responsiveColumns;

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
    this.responsiveColumns = false,
  });

  @override
  Widget build(BuildContext context) {
    if (responsiveColumns) {
      return LayoutBuilder(
          builder: (context, constraints) => GridView.builder(
                padding: padding,
                gridDelegate: _responsiveDelegate(
                    context,
                    constraints.maxWidth -
                        padding.resolve(Directionality.of(context)).horizontal,
                    mobileCoverRatio,
                    mobileTitleExtent),
                itemCount: itemCount,
                itemBuilder: itemBuilder,
              ));
    }
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
