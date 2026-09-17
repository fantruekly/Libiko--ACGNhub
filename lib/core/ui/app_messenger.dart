import 'package:flutter/material.dart';

/// Global messenger used by non-widget code (e.g. the comic-source JS bridge)
/// to surface short messages.
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void showAppMessage(String message) {
  appMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(message)));
}
