import 'package:flutter/material.dart';

/// A thin vertical position indicator: a track with a draggable thumb whose
/// position reflects [progress] (0..1). Tapping or dragging reports the
/// vertical fraction via [onSeek].
class ReaderProgressBar extends StatelessWidget {
  final double progress;
  final Color trackColor;
  final Color thumbColor;
  final ValueChanged<double> onSeek;

  const ReaderProgressBar({
    super.key,
    required this.progress,
    required this.trackColor,
    required this.thumbColor,
    required this.onSeek,
  });

  static const double _thumbHeight = 40;
  static const double _trackWidth = 4;
  static const double _thumbWidth = 10;
  static const double _width = 24;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.maxHeight.isFinite) {
          return const SizedBox(width: _width);
        }
        final height = constraints.maxHeight;
        final span = height - _thumbHeight;
        final top =
            span <= 0 ? 0.0 : span * progress.clamp(0.0, 1.0);
        return GestureDetector(
          key: const ValueKey('reader-progress-bar'),
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => onSeek(_fraction(details.localPosition.dy, span)),
          onVerticalDragUpdate: (details) =>
              onSeek(_fraction(details.localPosition.dy, span)),
          child: SizedBox(
            width: _width,
            child: Stack(
              children: [
                Positioned(
                  key: const ValueKey('reader-progress-track'),
                  right: (_width - _trackWidth) / 2,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: _trackWidth,
                    decoration: BoxDecoration(
                      color: trackColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Positioned(
                  key: const ValueKey('reader-progress-thumb'),
                  right: (_width - _thumbWidth) / 2,
                  top: top,
                  child: Container(
                    width: _thumbWidth,
                    height: _thumbHeight,
                    decoration: BoxDecoration(
                      color: thumbColor,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _fraction(double dy, double span) {
    if (span <= 0) return 0;
    return ((dy - _thumbHeight / 2) / span).clamp(0.0, 1.0);
  }
}
