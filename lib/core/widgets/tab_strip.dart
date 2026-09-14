import 'package:flutter/material.dart';

class TabStrip extends StatelessWidget {
  final List<String> labels;

  const TabStrip({super.key, required this.labels});

  static const _accent = Color(0xFF007AFF);
  static const _muted = Color(0xFF5A5A5F);

  static TextStyle _style(bool selected) => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: selected ? _accent : _muted,
      );

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);
    final animation = controller.animation ?? const AlwaysStoppedAnimation(0);
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        border:
            Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slot = constraints.maxWidth / labels.length;
          return AnimatedBuilder(
            animation: animation,
            builder: (context, _) => Stack(
              children: [
                Row(
                  children: [
                    for (var i = 0; i < labels.length; i++)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => controller.animateTo(i),
                          child: Center(
                            child: Text(
                              labels[i],
                              maxLines: 1,
                              softWrap: false,
                              style: _style(controller.index == i),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Positioned(
                  left: animation.value * slot,
                  bottom: 0,
                  width: slot,
                  height: 2.5,
                  child: const ColoredBox(color: _accent),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
