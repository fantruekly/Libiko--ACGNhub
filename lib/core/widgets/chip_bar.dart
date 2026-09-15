import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class ChipBar extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final EdgeInsetsGeometry padding;

  const ChipBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  static const _accent = Color(0xFF007AFF);
  static const _muted = Color(0xFF5A5A5F);
  static const _hPad = 15.0;
  static const _gap = 10.0;
  static const _duration = Duration(milliseconds: 220);

  static TextStyle _style(bool selected) => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: selected ? Colors.white : _muted,
      );

  double _widthOf(BuildContext context, String label, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = (painter.width + _hPad * 2).ceilToDouble();
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    final index = selectedIndex.clamp(0, labels.length - 1);
    final base = DefaultTextStyle.of(context).style;
    TextStyle styleFor(bool selected) => base.merge(_style(selected));
    final widths = [
      for (final label in labels) _widthOf(context, label, styleFor(false)),
    ];
    final lefts = <double>[];
    var x = 0.0;
    for (final width in widths) {
      lefts.add(x);
      x += width + _gap;
    }
    return SizedBox(
      height: 48,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: const {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
          },
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: padding,
          child: KeyedSubtree(
            key: ValueKey(Object.hashAll(labels)),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                AnimatedPositioned(
                  duration: _duration,
                  curve: Curves.easeInOutCubic,
                  left: lefts[index],
                  top: 6,
                  width: widths[index],
                  height: 36,
                  child: const DecoratedBox(
                    key: ValueKey('chip-bar-pill'),
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < labels.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: _gap),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onSelected(i),
                          child: SizedBox(
                            width: widths[i],
                            height: 48,
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: _duration,
                                curve: Curves.easeInOutCubic,
                                style: styleFor(i == index),
                                child: Text(labels[i],
                                    maxLines: 1, softWrap: false),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
