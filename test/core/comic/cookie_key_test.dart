import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/comic/js_engine.dart';

void main() {
  test('reduces URLs, bare domains and dot-prefixed domains to a host', () {
    expect(JsEngine.normalizeCookieKey('https://a.b/c?x=1'), 'a.b');
    expect(JsEngine.normalizeCookieKey('bzmgcn.com'), 'bzmgcn.com');
    expect(JsEngine.normalizeCookieKey('.a.b'), 'a.b');
    expect(JsEngine.normalizeCookieKey('example.com/foo'), 'example.com');
    expect(JsEngine.normalizeCookieKey('  a.b  '), 'a.b');
    expect(JsEngine.normalizeCookieKey(''), '');
  });
}
