import 'package:flutter/material.dart';

class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final double gap;
  final double velocity;

  const MarqueeText({
    super.key,
    required this.text,
    this.style,
    this.gap = 40,
    this.velocity = 40,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _start(double overflow) {
    final distance = overflow + widget.gap;
    final ms = (distance / widget.velocity * 1000).round();
    _controller.duration = Duration(milliseconds: ms.clamp(400, 60000));
    _controller.repeat();
  }

  void _stop() {
    _controller.stop();
    _controller.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final overflow = painter.width - maxWidth;
        if (!maxWidth.isFinite || overflow <= 0) {
          return Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          );
        }
        return ClipRect(
          child: MouseRegion(
            onEnter: (_) => _start(overflow),
            onExit: (_) => _stop(),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Transform.translate(
                offset:
                    Offset(-_controller.value * (overflow + widget.gap), 0),
                child: Text(
                  widget.text,
                  maxLines: 1,
                  softWrap: false,
                  style: style,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
