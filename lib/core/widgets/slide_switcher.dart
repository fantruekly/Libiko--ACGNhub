import 'package:flutter/material.dart';

class SlideSwitcher extends StatefulWidget {
  final Object id;
  final int index;
  final Widget child;
  final Duration duration;

  const SlideSwitcher({
    super.key,
    required this.id,
    required this.index,
    required this.child,
    this.duration = const Duration(milliseconds: 250),
  });

  @override
  State<SlideSwitcher> createState() => _SlideSwitcherState();
}

class _SlideSwitcherState extends State<SlideSwitcher> {
  bool _forward = true;

  @override
  void didUpdateWidget(SlideSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      _forward = widget.index > oldWidget.index;
    } else if (widget.id != oldWidget.id) {
      _forward = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: widget.duration,
      switchInCurve: Curves.easeInOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        fit: StackFit.expand,
        children: [
          for (final child in previousChildren)
            HeroMode(enabled: false, child: child),
          if (currentChild != null) currentChild,
        ],
      ),
      transitionBuilder: (child, animation) {
        final incoming = child.key == ValueKey(widget.id);
        final dir =
            incoming ? (_forward ? 1.0 : -1.0) : (_forward ? -1.0 : 1.0);
        return SlideTransition(
          position: Tween<Offset>(begin: Offset(dir, 0), end: Offset.zero)
              .animate(animation),
          child: child,
        );
      },
      child: KeyedSubtree(key: ValueKey(widget.id), child: widget.child),
    );
  }
}
