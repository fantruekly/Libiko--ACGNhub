import 'package:flutter/material.dart';

/// Wraps tags in chips, clamping to [maxLines] rows by default with an
/// expand/collapse toggle when they overflow.
///
/// Each chip's width is measured from [labelStyle] plus [chipHorizontalPadding]
/// (the chip's total left+right padding), so [chipBuilder] must render a chip
/// with that same style and padding for the packing to match.
class CollapsibleTagWrap extends StatefulWidget {
  final List<String> tags;
  final Widget Function(String tag) chipBuilder;
  final TextStyle labelStyle;
  final int maxLines;
  final double spacing;
  final double runSpacing;
  final double chipHorizontalPadding;

  const CollapsibleTagWrap({
    super.key,
    required this.tags,
    required this.chipBuilder,
    required this.labelStyle,
    this.maxLines = 2,
    this.spacing = 6,
    this.runSpacing = 6,
    this.chipHorizontalPadding = 16,
  });

  @override
  State<CollapsibleTagWrap> createState() => _CollapsibleTagWrapState();
}

class _CollapsibleTagWrapState extends State<CollapsibleTagWrap> {
  bool _expanded = false;

  double _chipWidth(BuildContext context, String tag, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: tag, style: widget.labelStyle),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = painter.width + widget.chipHorizontalPadding;
    painter.dispose();
    return width > maxWidth ? maxWidth : width;
  }

  int _fitCount(List<double> widths, double maxWidth) {
    if (!maxWidth.isFinite) return widths.length;
    var lines = 1;
    var lineWidth = 0.0;
    var count = 0;
    for (final w in widths) {
      final add = lineWidth == 0 ? w : w + widget.spacing;
      if (lineWidth == 0 || lineWidth + add <= maxWidth) {
        lineWidth += add;
        count++;
      } else {
        if (lines >= widget.maxLines) break;
        lines++;
        lineWidth = w;
        count++;
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final widths = [for (final t in widget.tags) _chipWidth(context, t, maxW)];
        final fit = _fitCount(widths, maxW);
        final fitsAll = fit >= widget.tags.length;
        final count = (_expanded || fitsAll) ? widget.tags.length : fit;
        final shown = widget.tags.take(count).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: widget.spacing,
              runSpacing: widget.runSpacing,
              children: [
                for (final t in shown)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxW),
                    child: widget.chipBuilder(t),
                  ),
              ],
            ),
            if (!fitsAll)
              GestureDetector(
                key: const ValueKey('tags-toggle'),
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _expanded ? '收起' : '展开',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
