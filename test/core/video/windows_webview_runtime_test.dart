import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/video/windows_webview_runtime.dart';
import 'package:libiko/core/video/headless_browser.dart';
import 'package:libiko/core/video/headless_browser_inappwebview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('libiko/windows_webview_runtime');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test(
      'native navigation reserves its load identity before runtime checks await',
      () async {
    final ready = Completer<Map<String, dynamic>>();
    messenger.setMockMethodCallHandler(channel, (_) => ready.future);
    final browser = InAppWebViewHeadlessBrowser();
    final pending = browser.load('https://test/');
    expect(browser.loadId, 1);
    final failure = expectLater(pending, throwsA(isA<HeadlessLoadException>()));
    ready.complete({'ready': true});
    await failure;
    await browser.dispose();
  });
  test('non-Windows browsers never request COM initialization', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (_) async {
      calls++;
      return {'ready': true};
    });
    await WindowsWebViewRuntime.ensureReady(windows: false);
    expect(calls, 0);
  });
  test('each browser lifecycle checks the native platform thread', () async {
    var calls = 0;
    final before = WindowsWebViewRuntime.recoveries;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'ensureReady');
      return {'ready': true, 'recovered': ++calls == 2};
    });
    await WindowsWebViewRuntime.ensureReady(windows: true);
    await WindowsWebViewRuntime.ensureReady(windows: true);
    expect(calls, 2);
    expect(WindowsWebViewRuntime.recoveries, before + 1);
  });
  test('runtime failure is not mistaken for an empty successful source',
      () async {
    messenger.setMockMethodCallHandler(channel, (_) async => {'ready': false});
    await expectLater(
        WindowsWebViewRuntime.ensureReady(windows: true),
        throwsA(isA<PlatformException>()
            .having((e) => e.code, 'code', 'webview_runtime')));
  });
}
