import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../platform.dart';

/// A window-drag region on desktop; a plain passthrough on mobile, where
/// `window_manager` has no implementation and dragging would throw.
class DesktopDragArea extends StatelessWidget {
  final Widget child;

  const DesktopDragArea({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) return child;
    return DragToMoveArea(child: child);
  }
}
