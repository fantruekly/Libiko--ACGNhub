import 'package:flutter/material.dart';

/// A slightly slower, smoother route transition (fade only) used for
/// card → detail navigation. A fade (rather than fade + slide) keeps the
/// repainted area small, so the shared-element (Hero) flight stays smooth.
Route<T> smoothRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
        child: child,
      );
    },
  );
}

/// An instant route (no transition) used when the destination's own top bar
/// visually continues the shell's title bar (so a fade would look like the
/// window controls jumped).
Route<T> noTransitionRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (_, __, ___) => page,
  );
}
