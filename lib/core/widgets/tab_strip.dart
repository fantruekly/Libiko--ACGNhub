import 'package:flutter/material.dart';

class TabStrip extends StatelessWidget {
  final List<String> labels;

  const TabStrip({super.key, required this.labels});

  static const _accent = Color(0xFF007AFF);
  static const _muted = Color(0xFF5A5A5F);
  static const _selectedWeight = FontWeight.w500;
  static const _unselectedWeight = FontWeight.w400;

  double _labelWidth(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: _style(true)),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final w = painter.width;
    painter.dispose();
    return w;
  }

  static TextStyle _style(bool selected) => TextStyle(
        fontSize: 15,
        fontWeight: selected ? _selectedWeight : _unselectedWeight,
        color: selected ? _accent : _muted,
      );

  static TextStyle _itemStyle(double t, int k) {
    final d = (t - k).abs().clamp(0.0, 1.0).toDouble();
    return TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.lerp(_unselectedWeight, _selectedWeight, 1 - d),
      color: Color.lerp(_accent, _muted, d),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);
    final animation = controller.animation ?? const AlwaysStoppedAnimation(0);
    final widths = [for (final l in labels) _labelWidth(context, l)];
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        border:
            Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slot = constraints.maxWidth / labels.length;
          double labelLeft(int i) => i * slot + (slot - widths[i]) / 2;
          return AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final t = animation.value
                  .clamp(0.0, (labels.length - 1).toDouble())
                  .toDouble();
              final i = t.floor();
              final j = i + 1 < labels.length ? i + 1 : i;
              final f = t - i;
              final left = labelLeft(i) + (labelLeft(j) - labelLeft(i)) * f;
              final width = widths[i] + (widths[j] - widths[i]) * f;
              return Stack(
                children: [
                  Row(
                    children: [
                      for (var k = 0; k < labels.length; k++)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => controller.animateTo(k),
                            child: Center(
                              child: Text(
                                labels[k],
                                maxLines: 1,
                                softWrap: false,
                                style: _itemStyle(t, k),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  Positioned(
                    left: left,
                    bottom: 0,
                    width: width,
                    height: 3,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: _accent,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(3)),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
