import 'package:flutter/material.dart';

class TabStrip extends StatelessWidget {
  final List<String> labels;

  const TabStrip({super.key, required this.labels});

  static const _accent = Color(0xFF007AFF);
  static const _muted = Color(0xFF5A5A5F);
  static const _itemPad = 16.0;

  static TextStyle _style(bool selected) => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: selected ? _accent : _muted,
      );

  double _labelWidth(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: _style(false)),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final w = painter.width;
    painter.dispose();
    return w;
  }

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);
    final widths = [
      for (final label in labels)
        (_labelWidth(context, label) + _itemPad * 2).ceilToDouble(),
    ];
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        border:
            Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                _TabItem(
                  label: labels[i],
                  width: widths[i],
                  selected: controller.index == i,
                  onTap: () => controller.animateTo(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final double width;
  final bool selected;
  final VoidCallback onTap;

  const _TabItem({
    required this.label,
    required this.width,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: width,
        height: 44,
        padding: const EdgeInsets.only(left: TabStrip._itemPad),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? TabStrip._accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: TabStrip._style(selected),
        ),
      ),
    );
  }
}
