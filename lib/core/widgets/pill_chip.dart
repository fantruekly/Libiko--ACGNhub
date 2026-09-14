import 'package:flutter/material.dart';

class PillChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const PillChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const _accent = Color(0xFF007AFF);
  static const _muted = Color(0xFF5A5A5F);
  static const _hPad = 12.0;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: selected ? Colors.white : _muted,
    );
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = (painter.width + _hPad * 2).ceilToDouble();
    painter.dispose();
    return Material(
      color: selected ? _accent : const Color(0xFFF2F2F7),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: width,
          height: 32,
          padding: const EdgeInsets.only(left: _hPad),
          alignment: Alignment.centerLeft,
          child: Text(label, maxLines: 1, softWrap: false, style: style),
        ),
      ),
    );
  }
}
