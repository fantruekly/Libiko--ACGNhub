import 'dart:async';

import 'headless_browser.dart';

/// Temporary scaffold: Task 4 replaces this with the flutter_inappwebview
/// implementation.
class AndroidHeadlessBrowser implements HeadlessBrowser {
  @override
  Stream<String> get mediaUrls => const Stream.empty();

  @override
  Future<void> start({String? userAgent}) async =>
      throw UnimplementedError('AndroidHeadlessBrowser');

  @override
  Future<void> load(String url,
          {Duration timeout = const Duration(seconds: 15)}) async =>
      throw UnimplementedError('AndroidHeadlessBrowser');

  @override
  Future<dynamic> eval(String script) async =>
      throw UnimplementedError('AndroidHeadlessBrowser');

  @override
  Future<void> dispose() async {}
}
