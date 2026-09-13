import 'package:flutter_test/flutter_test.dart';
import 'package:acgnhub/core/comic/js_engine.dart';

void main() {
  test('evaluates a trivial script', () async {
    final engine = JsEngine();
    addTearDown(engine.dispose);
    expect(await engine.evaluate('1 + 1'), 2);
    expect(await engine.evaluate('"a" + "b"'), 'ab');
  });
}
