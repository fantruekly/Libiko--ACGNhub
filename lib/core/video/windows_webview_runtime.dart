import 'dart:io';

import 'package:flutter/services.dart';

/// WebView2 must be created on an initialized STA platform thread. Check on
/// that thread, rather than initializing COM on the Dart isolate's thread.
class WindowsWebViewRuntime {
  static const _channel = MethodChannel('libiko/windows_webview_runtime');
  static int recoveries = 0;

  static Future<void> ensureReady({bool? windows}) async {
    if (!(windows ?? Platform.isWindows)) return;
    final state =
        await _channel.invokeMapMethod<String, dynamic>('ensureReady');
    if (state?['ready'] != true) {
      throw PlatformException(
          code: 'webview_runtime',
          message: 'Windows browser runtime is unavailable');
    }
    if (state?['recovered'] == true) recoveries++;
  }
}
